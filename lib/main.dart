import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/left/domain.dart';
import 'package:network_proxy/ui/panel.dart';
import 'package:network_proxy/ui/toolbar/toolbar.dart';
import 'package:window_manager/window_manager.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //设置窗口大小
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
      minimumSize: const Size(980, 600),
      size: Platform.isMacOS ? const Size(1200, 750) : const Size(1080, 650),
      center: true,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const FluentApp());
}

/// 主题
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class FluentApp extends StatelessWidget {
  const FluentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'ProxyPin',
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: false),
            themeMode: currentMode,
            home: const NetworkHomePage(),
          );
        });
  }
}

class NetworkHomePage extends StatefulWidget {
  const NetworkHomePage({super.key});

  @override
  State<NetworkHomePage> createState() => _NetworkHomePagePageState();
}

class _NetworkHomePagePageState extends State<NetworkHomePage> implements EventListener {
  final NetworkTabController panel = NetworkTabController();
  late DomainWidget domainWidget;
  late ProxyServer proxyServer;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainWidget.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    domainWidget.addResponse(channel, response);
  }

  @override
  void initState() {
    super.initState();
    domainWidget = DomainWidget(panel: panel);
    proxyServer = ProxyServer(listener: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: Tab(
          child: Toolbar(proxyServer, domainWidget),
        ),
        body: Row(children: [
          SizedBox(width: 400, child: domainWidget),
          const VerticalDivider(),
          Expanded(flex: 100, child: domainWidget.panel),
        ]));
  }
}
