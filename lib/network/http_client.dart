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

import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/network.dart';
import 'package:network_proxy/network/util/system_proxy.dart';
import 'package:proxy_manager/proxy_manager.dart';

import 'channel.dart';
import 'http/codec.dart';

class HttpClients {
  /// 建立连接
  static Future<Channel> startConnect(HostAndPort hostAndPort, ChannelHandler handler) async {
    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), handler));

    return client.connect(hostAndPort);
  }

  ///代理建立连接
  static Future<Channel> proxyConnect(HostAndPort hostAndPort, ChannelHandler handler, {ProxyInfo? proxyInfo}) async {
    var client = Client()
      ..initChannel((channel) => channel.pipeline.handle(HttpResponseCodec(), HttpRequestCodec(), handler));

    if (proxyInfo == null) {
      var proxyTypes = hostAndPort.isSsl() ? ProxyTypes.https : ProxyTypes.http;
      proxyInfo = await SystemProxy.getSystemProxy(proxyTypes);
    }

    HostAndPort connectHost = proxyInfo == null ? hostAndPort : HostAndPort.host(proxyInfo.host, proxyInfo.port!);
    var channel = await client.connect(connectHost);

    if (proxyInfo == null || !hostAndPort.isSsl()) {
      return channel;
    }

    //代理 发送connect请求
    var httpResponseHandler = HttpResponseHandler();
    channel.pipeline.handler = httpResponseHandler;

    HttpRequest proxyRequest = HttpRequest(HttpMethod.connect, '${hostAndPort.host}:${hostAndPort.port}');
    proxyRequest.headers.set(HttpHeaders.hostHeader, '${hostAndPort.host}:${hostAndPort.port}');

    await channel.write(proxyRequest);
    var response = await httpResponseHandler.getResponse(const Duration(seconds: 3));

    channel.pipeline.handler = handler;

    if (!response.status.isSuccessful()) {
      final error = "$hostAndPort Proxy failed to establish tunnel "
          "(${response.status.code} ${response..status.reasonPhrase})";
      throw Exception(error);
    }

    return channel;
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
  static Future<HttpResponse> proxyRequest(HttpRequest request,
      {ProxyInfo? proxyInfo, Duration timeout = const Duration(seconds: 3)}) async {
    if (request.headers.host == null || request.headers.host?.trim().isEmpty == true) {
      try {
        request.headers.host = Uri.parse(request.uri).host;
      } catch (_) {}
    }

    var httpResponseHandler = HttpResponseHandler();

    HostAndPort hostPort = HostAndPort.of(request.uri);

    Channel channel = await proxyConnect(proxyInfo: proxyInfo, hostPort, httpResponseHandler);

    if (hostPort.isSsl()) {
      channel.secureSocket = await SecureSocket.secure(channel.socket, onBadCertificate: (certificate) => true);
    }

    await channel.write(request);
    return httpResponseHandler.getResponse(timeout).whenComplete(() => channel.close());
  }
}

class HttpResponseHandler extends ChannelHandler<HttpResponse> {
  Completer<HttpResponse> _completer = Completer<HttpResponse>();

  @override
  void channelRead(Channel channel, HttpResponse msg) {
    // log.i("[${channel.id}] Response $msg");
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
