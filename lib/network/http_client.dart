import 'dart:async';
import 'dart:io';

import 'package:network_proxy/network/http/http.dart';

import 'channel.dart';
import 'http/codec.dart';

class HttpClients {
  /// 建立连接
  static Future<Channel> rawConnect(HostAndPort hostAndPort, ChannelHandler handler) async {
    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), handler));

    return client.connect(hostAndPort);
  }

  /// 建立连接
  static Future<Channel> connect(Uri uri, ChannelHandler handler) async {
    Client client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), handler));
    if (uri.scheme == "https" || uri.scheme == "wss") {
      return client.secureConnect(HostAndPort.of(uri.toString()));
    }

    return client.connect(HostAndPort.of(uri.toString()));
  }

  /// 发送get请求
  static Future<HttpResponse> get(String url, {Duration duration = const Duration(seconds: 3)}) async {
    HttpRequest msg = HttpRequest(HttpMethod.get, url);
    return request(HostAndPort.of(url), msg);
  }

  /// 发送请求
  static Future<HttpResponse> request(HostAndPort hostAndPort, HttpRequest request,
      {Duration duration = const Duration(seconds: 3)}) async {
    var httpResponseHandler = HttpResponseHandler();

    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), httpResponseHandler));

    Channel channel = await client.connect(hostAndPort);
    await channel.write(request);

    return httpResponseHandler.getResponse(duration).whenComplete(() => channel.close());
  }

  /// 发送代理请求
  static Future<HttpResponse> proxyRequest(String proxyHost, int port, HttpRequest request,
      {Duration timeout = const Duration(seconds: 3)}) async {
    var httpResponseHandler = HttpResponseHandler();

    bool isHttps = request.uri.startsWith("https://");
    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), httpResponseHandler));

    Channel channel = await client.connect(HostAndPort.host(proxyHost, port));

    if (isHttps) {
      HttpRequest proxyRequest = HttpRequest(HttpMethod.connect, request.uri);
      await channel.write(proxyRequest);
      await httpResponseHandler.getResponse(timeout);
      channel.secureSocket = await SecureSocket.secure(channel.socket, onBadCertificate: (certificate) => true);
    }

    httpResponseHandler.resetResponse();
    await channel.write(request);
    return httpResponseHandler.getResponse(timeout).whenComplete(() => channel.close());
  }
}

class HttpResponseHandler extends ChannelHandler<HttpResponse> {
  Completer<HttpResponse> _completer = Completer<HttpResponse>();

  @override
  void channelRead(Channel channel, HttpResponse msg) {
    // log.i("[${channel.id}] Response ${msg.bodyAsString}");
    _completer.complete(msg);
  }

  Future<HttpResponse> getResponse(Duration duration) {
    return _completer.future.timeout(duration);
  }

  void resetResponse() {
    _completer = Completer<HttpResponse>();
  }

  @override
  void channelInactive(Channel channel) {
    // log.i("[${channel.id}] channelInactive");
  }
}
