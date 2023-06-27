import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/component/split_view.dart';
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
    ThemeData(brightness: Brightness.dark, useMaterial3: false);
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'ProxyPin',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: false),
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
  final domainStateKey = GlobalKey<DomainWidgetState>();
  final NetworkTabController panel = NetworkTabController();

  late ProxyServer proxyServer;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    domainStateKey.currentState!.addResponse(channel, response);
  }

  @override
  void initState() {
    super.initState();
    proxyServer = ProxyServer(listener: this);
  }

  @override
  Widget build(BuildContext context) {
    final domainWidget = DomainWidget(key: domainStateKey, proxyServer: proxyServer, panel: panel);

    return Scaffold(
        appBar: Tab(
          child: Toolbar(proxyServer, domainStateKey),
        ),
        body: VerticalSplitView(ratio: 0.3, minRatio: 0.15, maxRatio: 0.9, left: domainWidget, right: panel));
  }
}
