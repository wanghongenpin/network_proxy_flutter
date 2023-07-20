import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_proxy/native/vpn.dart';
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
  const MobileHomePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return MobileHomeState();
  }
}

class MobileHomeState extends State<MobileHomePage> implements EventListener {
  final requestStateKey = GlobalKey<RequestListState>();

  late ProxyServer proxyServer;
  ValueNotifier<RemoteModel> desktop = ValueNotifier(RemoteModel(connect: false));

  Timer? _connectCheckTimer;

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
    proxyServer = ProxyServer(listener: this);
    desktop.addListener(() {
      if (desktop.value.connect) {
        proxyServer.server?.remoteHost = "http://${desktop.value.host}:${desktop.value.port}";
        checkConnectTask(context);
      } else {
        proxyServer.server?.remoteHost = null;
        _connectCheckTimer?.cancel();
      }
    });
    super.initState();
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
    _connectCheckTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
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
        _connectCheckTimer?.cancel();
        _connectCheckTimer = null;
        desktop.value = RemoteModel(connect: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("检查远程连接失败，已断开")));
        }
      }
    });
  }
}
