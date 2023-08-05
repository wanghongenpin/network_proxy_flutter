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
      appBar: AppBar(title: search(), actions: [
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
          onPressed: () {},
          child: SocketLaunch(
              proxyServer: proxyServer,
              startup: false,
              size: 38,
              onStart: () => Vpn.startVpn("127.0.0.1", proxyServer.port),
              onStop: () => Vpn.stopVpn())),
      body: ValueListenableBuilder(
          valueListenable: desktop,
          builder: (context, value, _) {
            return Column(children: [
              value.connect == false
                  ? const SizedBox()
                  : Container(
                      margin: const EdgeInsets.only(top: 5, bottom: 5),
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
                          return ConnectRemote(desktop: desktop, proxyServer: proxyServer);
                        })),
                        child: Text("已连接${value.os?.toUpperCase()}，手机抓包已关闭",
                            style: Theme.of(context).textTheme.titleMedium),
                      )),
               Expanded(child: RequestListWidget(key: requestStateKey, proxyServer: proxyServer))
            ]);
          }),
    );
  }

  showUpgradeNotice() {
    String content = '1. 手机版启动默认不再自动开启抓包，请手动点击启动按钮。\n'
        '2. 搜索功能增强，可直接搜索响应类型和请求方法。\n'
        '3. 支持brotli编码，br响应类型编码不会再显示乱码';
    showAlertDialog('更新内容', content, () {
      widget.configuration.upgradeNotice = false;
      widget.configuration.flushConfig();
    });
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

  /// 搜索框
  Widget search() {
    return Padding(
        padding: const EdgeInsets.only(left: 20),
        child: TextField(
            cursorHeight: 20,
            keyboardType: TextInputType.url,
            onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (val) {
              requestStateKey.currentState?.search(val);
            },
            decoration:
                const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.search), hintText: 'Search')));
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
