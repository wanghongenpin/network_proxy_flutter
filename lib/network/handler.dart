import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';

import 'channel.dart';
import 'http/codec.dart';

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

  /// 转发请求
  Future<void> forward(Channel channel, HttpRequest httpRequest) async {
    channel.putAttribute(AttributeKeys.request, httpRequest);

    if (httpRequest.uri == 'http://proxy.pin/ssl') {
      _crtDownload(channel, httpRequest);
      return;
    }

    var remoteChannel = await _getRemoteChannel(channel, httpRequest);

    //实现抓包代理转发
    if (httpRequest.method != HttpMethod.connect) {
      var replaceBody = requestRewrites?.findRequestReplaceWith(httpRequest.path);
      if (replaceBody?.isNotEmpty == true) {
        httpRequest.body = utf8.encode(replaceBody!);
      }

      // log.i("[${channel.id}] ${remoteChannel.getAttribute(AttributeKeys.uri)}");
      listener?.onRequest(channel, httpRequest);
      //实现抓包代理转发
      await remoteChannel.write(httpRequest);
    }
  }

  void _crtDownload(Channel channel, HttpRequest request) async {
    const String fileMimeType = 'application/x-x509-ca-cert';
    var body = await rootBundle.load('assets/certs/ca.crt');
    var response = HttpResponse(request.protocolVersion, HttpStatus.ok);
    response.headers.set(HttpHeaders.CONTENT_TYPE, fileMimeType);
    response.headers.set("Content-Disposition", 'attachment; filename="ProxyPin CA.crt"');
    response.body = body.buffer.asUint8List();
    channel.write(response);
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
    var proxyChannel = await HttpClients.connect(hostAndPort, proxyHandler);
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
    // log.i("[${clientChannel.id}] Response ${msg.bodyAsString}");

    var replaceBody = requestRewrites?.findResponseReplaceWith(msg.request?.path);
    if (replaceBody?.isNotEmpty == true) {
      msg.body = utf8.encode(replaceBody!);
    }

    listener?.onResponse(clientChannel, msg);
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

class HttpClients {
  /// 建立连接
  static Future<Channel> connect(HostAndPort hostAndPort, ChannelHandler<HttpResponse> handler) async {
    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), handler));

    return client.connect(hostAndPort);
  }
}
