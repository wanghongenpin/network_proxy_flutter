import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/file_read.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/utils/ip.dart';

import 'channel.dart';
import 'http_client.dart';

/// 获取主机和端口
HostAndPort getHostAndPort(HttpRequest request) {
  String requestUri = request.uri;
  //有些请求直接是路径 /xxx, 从header取host
  if (request.uri.startsWith("/")) {
    requestUri = request.headers.get(HttpHeaders.HOST)!;
  }
  return HostAndPort.of(requestUri);
}

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
    if ((await localIps()).contains(msg.hostAndPort?.host)) {
      localRequest(msg, channel);
      return;
    }

    //转发请求
    forward(channel, msg).catchError((error, trace) {
      channel.close();
      if (error is SocketException &&
          (error.message.contains("Failed host lookup") || error.message.contains("Connection timed out"))) {
        log.e("连接失败 ${error.message}");
        return;
      }
      log.e("转发请求失败", error, trace);
    });
  }

  @override
  void channelInactive(Channel channel) {
    Channel? remoteChannel = channel.getAttribute(channel.id);
    remoteChannel?.close();
  }

  //请求本服务
  localRequest(HttpRequest msg, Channel channel) async {
    //获取配置
    if (msg.path() == '/config') {
      var response = HttpResponse(msg.protocolVersion, HttpStatus.ok);
      var body = {
        "requestRewrites": requestRewrites?.toJson(),
        'whitelist': HostFilter.whitelist.toJson(),
        'blacklist': HostFilter.blacklist.toJson(),
      };
      response.body = utf8.encode(json.encode(body));
      channel.writeAndClose(response);
      return;
    }

    var response = HttpResponse(msg.protocolVersion, HttpStatus.ok);
    response.body = utf8.encode('pong');
    response.headers.set("os", Platform.operatingSystem);
    response.headers.set("hostname", Platform.isAndroid ? Platform.operatingSystem : Platform.localHostname);
    channel.writeAndClose(response);
  }

  /// 转发请求
  Future<void> forward(Channel channel, HttpRequest httpRequest) async {
    var remoteChannel = await _getRemoteChannel(channel, httpRequest);

    //实现抓包代理转发
    if (httpRequest.method != HttpMethod.connect) {
      // log.i("[${channel.id}] ${httpRequest.requestUrl}");

      var replaceBody = requestRewrites?.findRequestReplaceWith(httpRequest.path());
      if (replaceBody?.isNotEmpty == true) {
        httpRequest.body = utf8.encode(replaceBody!);
      }

      if (!HostFilter.filter(httpRequest.hostAndPort?.host)) {
        listener?.onRequest(channel, httpRequest);
      }
      //实现抓包代理转发
      await remoteChannel.write(httpRequest);
    }
  }

  void _crtDownload(Channel channel, HttpRequest request) async {
    const String fileMimeType = 'application/x-x509-ca-cert';
    var response = HttpResponse(request.protocolVersion, HttpStatus.ok);
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

    //远程代理
    HostAndPort? remote = clientChannel.getAttribute(AttributeKeys.remote);
    if (remote != null) {
      var proxyChannel = await HttpClients.rawConnect(remote, proxyHandler);
      clientChannel.putAttribute(clientId, proxyChannel);
      proxyChannel.write(httpRequest);
      return proxyChannel;
    }

    var proxyChannel = await HttpClients.rawConnect(hostAndPort, proxyHandler);
    clientChannel.putAttribute(clientId, proxyChannel);

    //https代理新建连接请求
    if (httpRequest.method == HttpMethod.connect) {
      await clientChannel.write(HttpResponse(httpRequest.protocolVersion, HttpStatus.ok));
    }

    return proxyChannel;
  }
}

/// http响应代理
class HttpResponseProxyHandler extends ChannelHandler<HttpResponse> {
  final Channel clientChannel;

  EventListener? listener;
  RequestRewrites? requestRewrites;

  HttpResponseProxyHandler(this.clientChannel, {this.listener, this.requestRewrites});

  @override
  void channelRead(Channel channel, HttpResponse msg) {
    msg.request = clientChannel.getAttribute(AttributeKeys.request);
    msg.request?.response = msg;
    // log.i("[${clientChannel.id}] Response ${msg.bodyAsString}");

    var replaceBody = requestRewrites?.findResponseReplaceWith(msg.request?.path());
    if (replaceBody?.isNotEmpty == true) {
      msg.body = utf8.encode(replaceBody!);
    }

    if (!HostFilter.filter(msg.request?.hostAndPort?.host)) {
      listener?.onResponse(clientChannel, msg);
    }
    //发送给客户端
    clientChannel.write(msg);
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
