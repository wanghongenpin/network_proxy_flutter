import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/ui/component/chinese_font.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/ui/desktop/desktop.dart';
import 'package:network_proxy/ui/desktop/left/request_editor.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

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
      minimumSize: const Size(1000, 600),
      size: Platform.isMacOS ? const Size(1230, 750) : const Size(1100, 650),
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
        windowController: WindowController.fromWindowId(windowId), request: HttpRequest.fromJson(argument['request']));
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
    var lightTheme = ThemeData.light(useMaterial3: !Platforms.isDesktop());
    var darkTheme = ThemeData.dark(useMaterial3: !Platforms.isDesktop());

    if (!lightTheme.useMaterial3) {
      lightTheme = lightTheme.copyWith(
          expansionTileTheme: lightTheme.expansionTileTheme.copyWith(
            textColor: lightTheme.textTheme.titleMedium?.color,
          ),
          appBarTheme: lightTheme.appBarTheme.copyWith(
            color: Colors.transparent,
            elevation: 0,
            titleTextStyle: lightTheme.textTheme.titleMedium,
            iconTheme: lightTheme.iconTheme,
          ),
          tabBarTheme: lightTheme.tabBarTheme.copyWith(
            labelColor: lightTheme.indicatorColor,
            unselectedLabelColor: lightTheme.textTheme.titleMedium?.color,
          ));
    }

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
