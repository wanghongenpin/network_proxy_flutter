import 'dart:convert';
import 'dart:io';

import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/component/split_view.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/domain.dart';
import 'package:network_proxy/ui/desktop/left/request_editor.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';

void main(List<String> args) async {
  //多窗口
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args[2].isEmpty ? const {} : jsonDecode(args[2]) as Map<String, dynamic>;
    runApp(FluentApp(multiWindow(windowId, argument)));
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  var configuration = Configuration.instance;
  if (Platforms.isMobile()) {
    runApp(FluentApp(MobileHomePage(configuration: (await configuration))));
    return;
  }

  await windowManager.ensureInitialized();
  //设置窗口大小
  WindowOptions windowOptions = WindowOptions(
      minimumSize: const Size(980, 600),
      size: Platform.isMacOS ? const Size(1200, 750) : const Size(1080, 650),
      center: true,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(FluentApp(DesktopHomePage(configuration: (await configuration))));
}

///多窗口
Widget multiWindow(int windowId, Map<dynamic, dynamic> argument) {
  if (argument['name'] == 'RequestEditor') {
    return RequestEditor(
        windowController: WindowController.fromWindowId(windowId),
        request: HttpRequest.fromJson(argument['request']),
        proxyPort: argument['proxyPort']);
  }

  if (argument['name'] == 'HttpBodyWidget') {
    return HttpBodyWidget(
        windowController: WindowController.fromWindowId(windowId),
        httpMessage: HttpMessage.fromJson(argument['httpMessage']),
        inNewWindow: true);
  }

  return const SizedBox();
}

/// 主题
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class FluentApp extends StatelessWidget {
  final Widget home;

  const FluentApp(
    this.home, {
    super.key,
  });

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
            home: home,
          );
        });
  }
}

class DesktopHomePage extends StatefulWidget {
  final Configuration configuration;

  const DesktopHomePage({super.key, required this.configuration});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePagePageState();
}

class _DesktopHomePagePageState extends State<DesktopHomePage> implements EventListener {
  final domainStateKey = GlobalKey<DomainWidgetState>();

  late ProxyServer proxyServer;
  late NetworkTabController panel;

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
    proxyServer = ProxyServer(widget.configuration, listener: this);
    panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 18), proxyServer: proxyServer);

    if (widget.configuration.guide) {
      //首次引导
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
                actions: [
                  TextButton(
                      onPressed: () {
                        widget.configuration.guide = false;
                        widget.configuration.flushConfig();
                        Navigator.pop(context);
                      },
                      child: const Text('关闭'))
                ],
                title: const Text('提示', style: TextStyle(fontSize: 18)),
                content: const Text('默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                    '点击的HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。'));
          });

      return;
    }
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
