import 'dart:io';

import 'package:network/network/http/http.dart';
import 'package:network/network/http/http_headers.dart';
import 'package:network/network/util/attribute_keys.dart';
import 'package:network/network/util/logger.dart';

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

///
class HttpChannelHandler extends ChannelHandler<HttpRequest> {
  EventListener? listener;

  HttpChannelHandler({this.listener});

  @override
  void channelRead(Channel channel, HttpRequest msg) async {
    forward(channel, msg).catchError((error, trace) {
      if (error is SocketException &&
          (error.message.contains("Failed host lookup") || error.message.contains(" Operation timed out"))) {
        log.e("连接失败 ${error.message}");
        channel.close();
        return;
      }
      log.e("转发请求失败", error, trace);
    });
  }

  @override
  void channelInactive(Channel channel) {
    super.channelInactive(channel);
    Channel? remoteChannel = channel.getAttribute(channel.id);
    remoteChannel?.close();
  }

  /// 转发请求
  Future<void> forward(Channel channel, HttpRequest httpRequest) async {
    channel.putAttribute(AttributeKeys.request, httpRequest);

    var remoteChannel = await _getRemoteChannel(channel, httpRequest);
    //实现抓包代理转发
    if (httpRequest.method != HttpMethod.connect) {
      if (channel.getAttribute(AttributeKeys.host) == null) {
        remoteChannel.putAttribute(AttributeKeys.uri, httpRequest.uri);
      } else {
        remoteChannel.putAttribute(AttributeKeys.uri, '${channel.getAttribute(AttributeKeys.host)}${httpRequest.uri}');
      }
      // log.i("[${channel.id}] ${remoteChannel.getAttribute(AttributeKeys.uri)}");
      listener?.onRequest(channel, httpRequest);
      //实现抓包代理转发
      await remoteChannel.write(httpRequest);
    }
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

    var proxyHandler = HttpResponseProxyHandler(clientChannel, listener: listener);
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

  HttpResponseProxyHandler(this.clientChannel, {this.listener});

  @override
  void channelRead(Channel channel, HttpResponse msg) {
    msg.request = clientChannel.getAttribute(AttributeKeys.request);
    // log.i("[${clientChannel.id}] Response ${msg.bodyAsString}");
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
}

class HttpClients {
  /// 建立连接
  static Future<Channel> connect(HostAndPort hostAndPort, ChannelHandler<HttpResponse> handler) async {
    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), handler));

    return client.connect(hostAndPort);
  }
}
