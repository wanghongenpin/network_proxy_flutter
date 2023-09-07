/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/file_read.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/utils/ip.dart';

import 'channel.dart';
import 'http/codec.dart';
import 'http_client.dart';

///请求和响应事件监听
abstract class EventListener {
  void onRequest(Channel channel, HttpRequest request);

  void onResponse(Channel channel, HttpResponse response);
}

/// http请求处理器
class HttpChannelHandler extends ChannelHandler<HttpRequest> {
  EventListener? listener;
  RequestRewrites? requestRewrites;

  HttpChannelHandler({this.listener, this.requestRewrites});

  @override
  void channelRead(Channel channel, HttpRequest msg) async {
    channel.putAttribute(AttributeKeys.request, msg);

    if (msg.uri == 'http://proxy.pin/ssl' || msg.requestUrl == 'http://127.0.0.1:${channel.socket.port}/ssl') {
      _crtDownload(channel, msg);
      return;
    }

    //请求本服务
    if ((await localIps()).contains(msg.hostAndPort?.host) && msg.hostAndPort?.port == channel.socket.port) {
      localRequest(msg, channel);
      return;
    }

    //转发请求
    forward(channel, msg).catchError((error, trace) {
      exceptionCaught(channel, error, trace: trace);
    });
  }

  @override
  void exceptionCaught(Channel channel, error, {StackTrace? trace}) {
    super.exceptionCaught(channel, error, trace: trace);
    _exceptionHandler(channel, channel.getAttribute(AttributeKeys.request), error);
  }

  @override
  void channelInactive(Channel channel) {
    Channel? remoteChannel = channel.getAttribute(channel.id);
    remoteChannel?.close();
    // log.i("[${channel.id}] close  ${channel.error}");
  }

  //请求本服务
  localRequest(HttpRequest msg, Channel channel) async {
    //获取配置
    if (msg.path() == '/config') {
      var response = HttpResponse(HttpStatus.ok, protocolVersion: msg.protocolVersion);
      var body = {
        "requestRewrites": requestRewrites?.toJson(),
        'whitelist': HostFilter.whitelist.toJson(),
        'blacklist': HostFilter.blacklist.toJson(),
      };
      response.body = utf8.encode(json.encode(body));
      channel.writeAndClose(response);
      return;
    }

    var response = HttpResponse(HttpStatus.ok, protocolVersion: msg.protocolVersion);
    response.body = utf8.encode('pong');
    response.headers.set("os", Platform.operatingSystem);
    response.headers.set("hostname", Platform.isAndroid ? Platform.operatingSystem : Platform.localHostname);
    channel.writeAndClose(response);
  }

  /// 转发请求
  Future<void> forward(Channel channel, HttpRequest httpRequest) async {
    log.i("[${channel.id}] ${httpRequest.method.name} ${httpRequest.requestUrl}");
    if (channel.error != null) {
      _exceptionHandler(channel, httpRequest, channel.error);
      return;
    }

    //获取远程连接
    Channel remoteChannel;
    try {
      remoteChannel = await _getRemoteChannel(channel, httpRequest);
      remoteChannel.putAttribute(remoteChannel.id, channel);
    } catch (error) {
      channel.error = error; //记录异常
      //https代理新建连接请求
      if (httpRequest.method == HttpMethod.connect) {
        await channel.write(
            HttpResponse(HttpStatus.ok.reason('Connection established'), protocolVersion: httpRequest.protocolVersion));
      }
      return;
    }

    //实现抓包代理转发
    if (httpRequest.method != HttpMethod.connect) {
      log.i("[${channel.id}] ${httpRequest.method.name} ${httpRequest.requestUrl}");

      //替换请求体
      _rewriteBody(httpRequest);

      if (!HostFilter.filter(httpRequest.hostAndPort?.host)) {
        listener?.onRequest(channel, httpRequest);
      }

      //重定向
      var redirectRewrite =
          requestRewrites?.findRequestRewrite(httpRequest.hostAndPort?.host, httpRequest.path(), RuleType.redirect);
      if (redirectRewrite?.redirectUrl?.isNotEmpty == true) {
        var proxyHandler = HttpResponseProxyHandler(channel, listener: listener, requestRewrites: requestRewrites);
        httpRequest.uri = redirectRewrite!.redirectUrl!;
        httpRequest.headers.host = Uri.parse(redirectRewrite.redirectUrl!).host;
        var redirectChannel = await HttpClients.connect(Uri.parse(redirectRewrite.redirectUrl!), proxyHandler);
        await redirectChannel.write(httpRequest);
        return;
      }

      await remoteChannel.write(httpRequest);
    }
  }

  //替换请求体
  _rewriteBody(HttpRequest httpRequest) {
    var rewrite = requestRewrites?.findRequestRewrite(httpRequest.hostAndPort?.host, httpRequest.path(), RuleType.body);

    if (rewrite?.requestBody?.isNotEmpty == true) {
      httpRequest.body = utf8.encode(rewrite!.requestBody!);
    }
    if (rewrite?.queryParam?.isNotEmpty == true) {
      httpRequest.uri = httpRequest.requestUri?.replace(query: rewrite!.queryParam!).toString() ?? httpRequest.uri;
    }
  }

  /// 下载证书
  void _crtDownload(Channel channel, HttpRequest request) async {
    const String fileMimeType = 'application/x-x509-ca-cert';
    var response = HttpResponse(HttpStatus.ok);
    response.headers.set(HttpHeaders.CONTENT_TYPE, fileMimeType);
    response.headers.set("Content-Disposition", 'inline;filename=ProxyPinCA.crt');
    response.headers.set("Connection", 'close');

    var body = await FileRead.read('assets/certs/ca.crt');
    response.headers.set("Content-Length", body.lengthInBytes.toString());

    if (request.method == HttpMethod.head) {
      channel.writeAndClose(response);
      return;
    }
    response.body = body.buffer.asUint8List();
    channel.writeAndClose(response);
  }

  /// 获取远程连接
  Future<Channel> _getRemoteChannel(Channel clientChannel, HttpRequest httpRequest) async {
    String clientId = clientChannel.id;
    //客户端连接 作为缓存
    Channel? remoteChannel = clientChannel.getAttribute(clientId);
    if (remoteChannel != null) {
      return remoteChannel;
    }

    var hostAndPort = getHostAndPort(httpRequest);
    clientChannel.putAttribute(AttributeKeys.host, hostAndPort);

    var proxyHandler = HttpResponseProxyHandler(clientChannel, listener: listener, requestRewrites: requestRewrites);

    //远程转发
    HostAndPort? remote = clientChannel.getAttribute(AttributeKeys.remote);
    //外部代理
    ProxyInfo? proxyInfo = clientChannel.getAttribute(AttributeKeys.proxyInfo);

    if (remote != null || proxyInfo != null) {
      HostAndPort connectHost = remote ?? HostAndPort.host(proxyInfo!.host, proxyInfo.port!);
      var proxyChannel = await HttpClients.startConnect(connectHost, proxyHandler);
      clientChannel.putAttribute(clientId, proxyChannel);
      proxyChannel.write(httpRequest);
      return proxyChannel;
    }

    var proxyChannel = await HttpClients.startConnect(hostAndPort, proxyHandler);
    clientChannel.putAttribute(clientId, proxyChannel);
    //https代理新建连接请求
    if (httpRequest.method == HttpMethod.connect) {
      await clientChannel.write(
          HttpResponse(HttpStatus.ok.reason('Connection established'), protocolVersion: httpRequest.protocolVersion));
    }
    return proxyChannel;
  }

  /// 异常处理
  _exceptionHandler(Channel channel, HttpRequest? request, error) {
    HostAndPort? hostAndPort = channel.getAttribute(AttributeKeys.host);
    hostAndPort ??= HostAndPort.host(channel.remoteAddress.host, channel.remotePort);
    String message = error.toString();
    HttpStatus status = HttpStatus(-1, message);
    if (error is HandshakeException) {
      status = HttpStatus(-2, 'SSL握手失败');
    } else if (error is ParserException) {
      status = HttpStatus(-3, error.message);
    } else if (error is SocketException) {
      status = HttpStatus(-4, error.message);
    }
    request ??= HttpRequest(HttpMethod.connect, hostAndPort.domain)
      ..body = message.codeUnits
      ..hostAndPort = hostAndPort;

    request.response = HttpResponse(status)..body = message.codeUnits;
    listener?.onRequest(channel, request);
    listener?.onResponse(channel, request.response!);
  }
}

/// http响应代理
class HttpResponseProxyHandler extends ChannelHandler<HttpResponse> {
  //客户端的连接
  final Channel clientChannel;

  EventListener? listener;
  RequestRewrites? requestRewrites;

  HttpResponseProxyHandler(this.clientChannel, {this.listener, this.requestRewrites});

  @override
  void channelRead(Channel channel, HttpResponse msg) async {
    msg.request = clientChannel.getAttribute(AttributeKeys.request);
    msg.request?.response = msg;
    // log.i("[${clientChannel.id}] Response ${msg}");

    var replaceBody = requestRewrites?.findResponseReplaceWith(msg.request?.hostAndPort?.host, msg.request?.path());
    if (replaceBody?.isNotEmpty == true) {
      msg.body = utf8.encode(replaceBody!);
    }

    if (!HostFilter.filter(msg.request?.hostAndPort?.host)) {
      listener?.onResponse(clientChannel, msg);
    }

    //发送给客户端
    await clientChannel.write(msg);
  }

  @override
  void channelInactive(Channel channel) {
    clientChannel.close();
  }
}

class RelayHandler extends ChannelHandler<Object> {
  final Channel remoteChannel;

  RelayHandler(this.remoteChannel);

  @override
  void channelRead(Channel channel, Object msg) {
    //发送给客户端
    remoteChannel.write(msg);
  }

  @override
  void channelInactive(Channel channel) {
    remoteChannel.close();
  }
}
