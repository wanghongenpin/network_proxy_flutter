import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/launch/launch.dart';
import 'package:network_proxy/ui/mobile/connect_remote.dart';
import 'package:network_proxy/ui/mobile/menu.dart';
import 'package:network_proxy/ui/mobile/request/list.dart';
import 'package:network_proxy/ui/mobile/request/search.dart';

class MobileHomePage extends StatefulWidget {
  final Configuration configuration;

  const MobileHomePage({super.key, required this.configuration});

  @override
  State<StatefulWidget> createState() {
    return MobileHomeState();
  }
}

class MobileHomeState extends State<MobileHomePage> implements EventListener {
  final requestStateKey = GlobalKey<RequestListState>();

  late ProxyServer proxyServer;
  ValueNotifier<RemoteModel> desktop = ValueNotifier(RemoteModel(connect: false));

  @override
  void onRequest(Channel channel, HttpRequest request) {
    requestStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    requestStateKey.currentState!.addResponse(channel, response);
  }

  @override
  void initState() {
    proxyServer = ProxyServer(widget.configuration, listener: this);
    desktop.addListener(() {
      if (desktop.value.connect) {
        proxyServer.configuration.remoteHost = "http://${desktop.value.host}:${desktop.value.port}";
        checkConnectTask(context);
      } else {
        proxyServer.configuration.remoteHost = null;
      }
    });

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.configuration.upgradeNotice) {
        showUpgradeNotice();
      }
    });
  }

  @override
  void dispose() {
    desktop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: MobileSearch(onSearch: (val) {
            requestStateKey.currentState?.search(val);
          }),
          actions: [
            IconButton(
                tooltip: "清理",
                icon: const Icon(Icons.cleaning_services_outlined),
                onPressed: () => requestStateKey.currentState?.clean()),
            const SizedBox(width: 2),
            MoreEnum(proxyServer: proxyServer, desktop: desktop),
            const SizedBox(width: 10)
          ]),
      drawer: DrawerWidget(proxyServer: proxyServer),
      floatingActionButton: FloatingActionButton(
          onPressed: null,
          child: Center(
              child: SocketLaunch(
                  proxyServer: proxyServer,
                  size: 36,
                  startup: false,
                  onStart: () => Vpn.startVpn("127.0.0.1", proxyServer.port, proxyServer.configuration.appWhitelist),
                  onStop: () => Vpn.stopVpn()))),
      body: ValueListenableBuilder(
          valueListenable: desktop,
          builder: (context, value, _) {
            return Column(children: [
              value.connect ? remoteConnect(value) : const SizedBox(),
              Expanded(child: RequestListWidget(key: requestStateKey, proxyServer: proxyServer))
            ]);
          }),
    );
  }

  showUpgradeNotice() {
    String content = '1. 增加高级搜索，点击搜索icon触发。\n'
        '2. 显示SSL握手异常、建立连接异常、未知异常等请求。\n'
        '3.响应体大时异步加载json，请求重写增加域名，修复手机扫码连接未开启代理时不转发问题';
    showAlertDialog('更新内容', content, () {
      widget.configuration.upgradeNotice = false;
      widget.configuration.flushConfig();
    });
  }

  /// 远程连接
  Widget remoteConnect(RemoteModel value) {
    return Container(
        margin: const EdgeInsets.only(top: 5, bottom: 5),
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
            return ConnectRemote(desktop: desktop, proxyServer: proxyServer);
          })),
          child: Text("已连接${value.os?.toUpperCase()}，手机抓包已关闭", style: Theme.of(context).textTheme.titleMedium),
        ));
  }

  showAlertDialog(String title, String content, Function onClose) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(actions: [
            TextButton(
                onPressed: () {
                  onClose.call();
                  Navigator.pop(context);
                },
                child: const Text('关闭'))
          ], title: Text(title, style: const TextStyle(fontSize: 18)), content: Text(content));
        });
  }

  /// 检查远程连接
  checkConnectTask(BuildContext context) async {
    int retry = 0;
    Timer.periodic(const Duration(milliseconds: 3000), (timer) async {
      if (desktop.value.connect == false) {
        timer.cancel();
        return;
      }

      try {
        var response = await HttpClients.get("http://${desktop.value.host}:${desktop.value.port}/ping")
            .timeout(const Duration(seconds: 1));
        if (response.bodyAsString == "pong") {
          retry = 0;
          return;
        }
      } catch (e) {
        retry++;
      }

      if (retry > 3) {
        timer.cancel();
        desktop.value = RemoteModel(connect: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("检查远程连接失败，已断开")));
        }
      }
    });
  }
}
