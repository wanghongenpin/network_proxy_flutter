import 'dart:io';

import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/component/split_view.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/domain.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platforms.isDesktop()) {
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
  }

  runApp(const FluentApp());
}

/// 主题
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class FluentApp extends StatelessWidget {
  const FluentApp({super.key});

  @override
  Widget build(BuildContext context) {
    var lightTheme = ThemeData.light(useMaterial3: true);
    var darkTheme = ThemeData.dark(useMaterial3: !Platforms.isDesktop());
    if (Platform.isWindows) {
      lightTheme = lightTheme.useSystemChineseFont();
      darkTheme = darkTheme.useSystemChineseFont();
    }

    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'ProxyPin',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: currentMode,
            home: Platforms.isDesktop() ? const DesktopHomePage() : const MobileHomePage(),
          );
        });
  }
}

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePagePageState();
}

class _DesktopHomePagePageState extends State<DesktopHomePage> implements EventListener {
  final domainStateKey = GlobalKey<DomainWidgetState>();
  final NetworkTabController panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 18));

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
    proxyServer.initializedListener(() {
      if (!proxyServer.guide) {
        return;
      }
      //首次引导
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
                actions: [
                  TextButton(
                      onPressed: () {
                        proxyServer.guide = false;
                        proxyServer.flushConfig();
                        Navigator.pop(context);
                      },
                      child: const Text('关闭'))
                ],
                title: const Text('提示', style: TextStyle(fontSize: 18)),
                content: const Text('默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                    '点击的HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。'));
          });
    });
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
