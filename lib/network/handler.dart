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
import 'dart:io';
import 'dart:typed_data';

import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/components/script_manager.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/websocket.dart';
import 'package:network_proxy/network/proxy_helper.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/network/util/uri.dart';
import 'package:network_proxy/utils/ip.dart';

import 'channel.dart';
import 'http_client.dart';

///请求和响应事件监听
abstract class EventListener {
  void onRequest(Channel channel, HttpRequest request);

  void onResponse(Channel channel, HttpResponse response);

  void onMessage(Channel channel, HttpMessage message, WebSocketFrame frame) {}
}

/// http请求处理器
class HttpProxyChannelHandler extends ChannelHandler<HttpRequest> {
  EventListener? listener;
  RequestRewrites? requestRewrites;

  HttpProxyChannelHandler({this.listener, this.requestRewrites});

  @override
  void channelRead(Channel channel, HttpRequest msg) async {
    channel.putAttribute(AttributeKeys.request, msg);
    //下载证书
    if (msg.uri == 'http://proxy.pin/ssl' || msg.requestUrl == 'http://127.0.0.1:${channel.socket.port}/ssl') {
      ProxyHelper.crtDownload(channel, msg);
      return;
    }
    //请求本服务
    if ((await localIps()).contains(msg.hostAndPort?.host) && msg.hostAndPort?.port == channel.socket.port) {
      ProxyHelper.localRequest(msg, channel);
      return;
    }

    //代理转发请求
    forward(channel, msg).catchError((error, trace) {
      exceptionCaught(channel, error, trace: trace);
    });
  }

  @override
  void exceptionCaught(Channel channel, error, {StackTrace? trace}) {
    super.exceptionCaught(channel, error, trace: trace);
    ProxyHelper.exceptionHandler(channel, listener, channel.getAttribute(AttributeKeys.request), error);
  }

  @override
  void channelInactive(Channel channel) {
    Channel? remoteChannel = channel.getAttribute(channel.id);
    remoteChannel?.close();
    // log.i("[${channel.id}] close  ${channel.error}");
  }

  /// 转发请求
  Future<void> forward(Channel channel, HttpRequest httpRequest) async {
    // log.i("[${channel.id}] ${httpRequest.method.name} ${httpRequest.requestUrl}");
    if (channel.error != null) {
      ProxyHelper.exceptionHandler(channel, listener, httpRequest, channel.error);
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
      // log.i("[${channel.id}] ${httpRequest.method.name} ${httpRequest.requestUrl}");
      if (HostFilter.filter(httpRequest.hostAndPort?.host)) {
        await remoteChannel.write(httpRequest);
        return;
      }

      //脚本替换
      var scriptManager = await ScriptManager.instance;
      HttpRequest? request = await scriptManager.runScript(httpRequest);
      if (request == null) {
        listener?.onRequest(channel, httpRequest);
        return;
      }

      httpRequest = request;
      //重写请求
      await requestRewrites?.requestRewrite(httpRequest);

      listener?.onRequest(channel, httpRequest);

      //重定向
      var uri = '${httpRequest.remoteDomain()}${httpRequest.path()}';
      String? redirectUrl = await requestRewrites?.getRedirectRule(uri);
      if (redirectUrl?.isNotEmpty == true) {
        await redirect(channel, httpRequest, redirectUrl!);
        return;
      }

      await remoteChannel.write(httpRequest);
    }
  }

  //重定向
  Future<void> redirect(Channel channel, HttpRequest httpRequest, String redirectUrl) async {
    var proxyHandler = HttpResponseProxyHandler(channel, listener: listener, requestRewrites: requestRewrites);

    var redirectUri = UriBuild.build(redirectUrl, params: httpRequest.queries);
    httpRequest.uri = redirectUri.toString();
    httpRequest.headers.host = redirectUri.host;
    var redirectChannel = await HttpClients.connect(Uri.parse(redirectUrl), proxyHandler);
    await redirectChannel.write(httpRequest);
  }

  /// 获取远程连接
  Future<Channel> _getRemoteChannel(Channel clientChannel, HttpRequest httpRequest) async {
    String clientId = clientChannel.id;
    //客户端连接 作为缓存
    Channel? remoteChannel = clientChannel.getAttribute(clientId);
    if (remoteChannel != null) {
      return remoteChannel;
    }

    var hostAndPort = httpRequest.hostAndPort ?? getHostAndPort(httpRequest);
    clientChannel.putAttribute(AttributeKeys.host, hostAndPort);

    //远程转发
    HostAndPort? remote = clientChannel.getAttribute(AttributeKeys.remote);
    //外部代理
    ProxyInfo? proxyInfo = clientChannel.getAttribute(AttributeKeys.proxyInfo);

    if (remote != null || proxyInfo != null) {
      HostAndPort connectHost = remote ?? HostAndPort.host(proxyInfo!.host, proxyInfo.port!);
      var proxyChannel = await connectRemote(clientChannel, connectHost);
      if (httpRequest.method == HttpMethod.connect) {
        proxyChannel.write(httpRequest);
      }
      return proxyChannel;
    }

    var proxyChannel = await connectRemote(clientChannel, hostAndPort);
    //https代理新建连接请求
    if (httpRequest.method == HttpMethod.connect) {
      await clientChannel.write(
          HttpResponse(HttpStatus.ok.reason('Connection established'), protocolVersion: httpRequest.protocolVersion));
    }
    return proxyChannel;
  }

  /// 连接远程
  Future<Channel> connectRemote(Channel clientChannel, HostAndPort connectHost) async {
    var proxyHandler = HttpResponseProxyHandler(clientChannel, listener: listener, requestRewrites: requestRewrites);
    var proxyChannel = await HttpClients.startConnect(connectHost, proxyHandler);
    proxyChannel.pipeline.listener = listener;
    String clientId = clientChannel.id;
    clientChannel.putAttribute(clientId, proxyChannel);

    if (clientChannel.isSsl) {
      proxyChannel.secureSocket = await SecureSocket.secure(proxyChannel.socket,
          host: connectHost.host, onBadCertificate: (certificate) => true);
    }
    return proxyChannel;
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
    //域名是否过滤
    if (HostFilter.filter(msg.request?.hostAndPort?.host) || msg.request?.method == HttpMethod.connect) {
      await clientChannel.write(msg);
      return;
    }

    // log.i("[${clientChannel.id}] Response $msg");
    //脚本替换
    var scriptManager = await ScriptManager.instance;
    try {
      HttpResponse? response = await scriptManager.runResponseScript(msg);
      if (response == null) {
        return;
      }
      msg = response;
    } catch (e, t) {
      msg.status = HttpStatus(-1, '执行脚本异常');
      msg.body = "$e\n${msg.bodyAsString}".codeUnits;
      log.e('[${clientChannel.id}] 执行脚本异常 ', error: e, stackTrace: t);
    }

    //重写响应
    await requestRewrites?.responseRewrite(msg.request?.requestUrl, msg);

    listener?.onResponse(clientChannel, msg);
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
  void channelRead(Channel channel, Object msg) async {
    //发送给客户端
    remoteChannel.write(msg);
  }

  @override
  void channelInactive(Channel channel) {
    remoteChannel.close();
  }
}

//
class WebSocketChannelHandler extends ChannelHandler<Uint8List> {
  final WebSocketDecoder decoder = WebSocketDecoder();

  final Channel proxyChannel;
  final HttpMessage message;
  EventListener? listener;

  WebSocketChannelHandler(this.proxyChannel, this.message, {this.listener});

  @override
  void channelRead(Channel channel, Uint8List msg) {
    proxyChannel.write(msg);

    var frame = decoder.decode(msg);
    if (frame == null) {
      return;
    }
    frame.isFromClient = message is HttpRequest;

    message.messages.add(frame);
    listener?.onMessage(channel, message, frame);
    logger.d("socket channelRead ${frame.payloadLength} ${frame.fin} ${frame.payloadDataAsString}");
  }
}
