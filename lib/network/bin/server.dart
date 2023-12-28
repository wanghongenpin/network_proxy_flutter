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

import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/http/websocket.dart';
import 'package:network_proxy/utils/platform.dart';

import '../handler.dart';
import '../http/codec.dart';
import '../network.dart';
import '../util/logger.dart';
import '../util/system_proxy.dart';

Future<void> main() async {
  var configuration = await Configuration.instance;
  ProxyServer(configuration).start();
}

/// 代理服务器
class ProxyServer {
  //socket服务
  Server? server;

  //请求事件监听
  List<EventListener> listeners = [];

  //配置
  final Configuration configuration;

  ProxyServer(this.configuration);

  //是否启动
  bool get isRunning => server?.isRunning ?? false;

  ///是否启用https抓包
  bool get enableSsl => configuration.enableSsl;

  int get port => configuration.port;

  set enableSsl(bool enableSsl) {
    configuration.enableSsl = enableSsl;
    if (server == null || server?.isRunning == false) {
      return;
    }

    SystemProxy.setSslProxyEnable(enableSsl, port);
  }

  /// 启动代理服务
  Future<Server> start() async {
    Server server = Server(configuration, listener: CombinedEventListener(listeners));
    var requestRewrites = await RequestRewrites.instance;

    server.initChannel((channel) {
      channel.pipeline.handle(HttpRequestCodec(), HttpResponseCodec(),
          HttpProxyChannelHandler(listener: CombinedEventListener(listeners), requestRewrites: requestRewrites));
    });

    return server.bind(port).then((serverSocket) {
      logger.i("listen on $port");
      this.server = server;
      if (configuration.enableSystemProxy) {
        setSystemProxyEnable(true);
      }
      return server;
    });
  }

  /// 停止代理服务
  Future<Server?> stop() async {
    if (!isRunning) {
      return server;
    }

    if (configuration.enableSystemProxy) {
      await setSystemProxyEnable(false);
    }
    logger.i("stop on $port");
    await server?.stop();
    return server;
  }

  /// 设置系统代理
  setSystemProxyEnable(bool enable) async {
    if (!Platforms.isDesktop()) {
      return;
    }

    //关闭系统代理 恢复成外部代理地址
    if (!enable && configuration.externalProxy?.enabled == true) {
      await SystemProxy.setSystemProxy(configuration.externalProxy!.port!, enableSsl, configuration.proxyPassDomains);
      return;
    }

    await SystemProxy.setSystemProxyEnable(port, enable, enableSsl, passDomains: configuration.proxyPassDomains);
  }

  /// 重启代理服务
  Future<void> restart() async {
    await stop().then((value) => start());
  }

  ///添加监听器
  addListener(EventListener listener) {
    listeners.add(listener);
  }
}

class CombinedEventListener extends EventListener {
  final List<EventListener> listeners;

  CombinedEventListener(this.listeners);

  @override
  void onRequest(Channel channel, HttpRequest request) {
    for (var element in listeners) {
      element.onRequest(channel, request);
    }
  }

  @override
  void onResponse(ChannelContext channelContext, HttpResponse response) {
    for (var element in listeners) {
      element.onResponse(channelContext, response);
    }
  }

  @override
  void onMessage(Channel channel, HttpMessage message, WebSocketFrame frame) {
    for (var element in listeners) {
      element.onMessage(channel, message, frame);
    }
  }
}
