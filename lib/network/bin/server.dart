import 'dart:async';
import 'dart:io';

import 'package:network_proxy/network/bin/configuration.dart';

import '../channel.dart';
import '../handler.dart';
import '../http/codec.dart';
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
  EventListener? listener;

  //配置
  final Configuration configuration;

  ProxyServer(this.configuration, {this.listener});

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

    if (Platform.isMacOS) {
      SystemProxy.setSslProxyEnableMacOS(enableSsl, port);
    }
  }

  /// 启动代理服务
  Future<Server> start() async {
    Server server = Server(configuration);

    server.initChannel((channel) {
      channel.pipeline.handle(HttpRequestCodec(), HttpResponseCodec(),
          HttpChannelHandler(listener: listener, requestRewrites: configuration.requestRewrites));
    });

    return server.bind(port).then((serverSocket) {
      logger.i("listen on $port");
      this.server = server;
      if (configuration.enableDesktop) {
        SystemProxy.setSystemProxy(port, enableSsl);
      }
      return server;
    });
  }

  /// 停止代理服务
  Future<Server?> stop() async {
    logger.i("stop on $port");
    if (configuration.enableDesktop) {
      if (Platform.isMacOS) {
        await SystemProxy.setProxyEnableMacOS(false, enableSsl);
      } else if (Platform.isWindows) {
        await SystemProxy.setProxyEnableWindows(false);
      }
    }
    await server?.stop();
    return server;
  }

  /// 重启代理服务
  restart() {
    stop().then((value) => start());
  }
}
