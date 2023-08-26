import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/ui/component/chinese_font.dart';
import 'package:network_proxy/ui/component/encoder.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/ui/desktop/desktop.dart';
import 'package:network_proxy/ui/desktop/left/request_editor.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/ui/ui_configuration.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

import 'network/http/http.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  var instance = UIConfiguration.instance;
  //多窗口
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args[2].isEmpty ? const {} : jsonDecode(args[2]) as Map<String, dynamic>;
    runApp(FluentApp(multiWindow(windowId, argument), uiConfiguration: (await instance)));
    return;
  }

  var configuration = Configuration.instance;
  if (Platforms.isMobile()) {
    var uiConfiguration = await instance;
    runApp(FluentApp(MobileHomePage(configuration: (await configuration)), uiConfiguration: uiConfiguration));
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

  var uiConfiguration = await instance;
  runApp(FluentApp(DesktopHomePage(configuration: await configuration), uiConfiguration: uiConfiguration));
}

///多窗口
Widget multiWindow(int windowId, Map<dynamic, dynamic> argument) {
  if (argument['name'] == 'RequestEditor') {
    return RequestEditor(
        windowController: WindowController.fromWindowId(windowId),
        request: argument['request'] == null ? null : HttpRequest.fromJson(argument['request']));
  }

  if (argument['name'] == 'HttpBodyWidget') {
    return HttpBodyWidget(
        windowController: WindowController.fromWindowId(windowId),
        httpMessage: HttpMessage.fromJson(argument['httpMessage']),
        inNewWindow: true);
  }

  if (argument['name'] == 'EncoderWidget') {
    return EncoderWidget(
        type: EncoderType.nameOf(argument['type']), windowController: WindowController.fromWindowId(windowId));
  }

  return const SizedBox();
}

class ThemeModel {
  ThemeMode mode;
  bool useMaterial3;

  ThemeModel({this.mode = ThemeMode.system, this.useMaterial3 = true});

  ThemeModel copy({ThemeMode? mode, bool? useMaterial3}) => ThemeModel(
        mode: mode ?? this.mode,
        useMaterial3: useMaterial3 ?? this.useMaterial3,
      );
}

/// 主题
late ValueNotifier<ThemeModel> themeNotifier;

class FluentApp extends StatelessWidget {
  final Widget home;
  final UIConfiguration uiConfiguration;

  const FluentApp(
    this.home, {
    super.key,
    required this.uiConfiguration,
  });

  @override
  Widget build(BuildContext context) {
    themeNotifier = ValueNotifier(uiConfiguration.theme);

    var light = lightTheme();
    var darkTheme = ThemeData.dark(useMaterial3: false);

    var material3Light = ThemeData.light(useMaterial3: true);
    var material3Dark = ThemeData.dark(useMaterial3: true);

    if (Platform.isWindows) {
      material3Light = material3Light.useSystemChineseFont();
      material3Dark = material3Dark.useSystemChineseFont();
      light = light.useSystemChineseFont();
      darkTheme = darkTheme.useSystemChineseFont();
    }

    return ValueListenableBuilder<ThemeModel>(
        valueListenable: themeNotifier,
        builder: (_, current, __) {
          uiConfiguration.theme = current;
          uiConfiguration.flushConfig();

          return MaterialApp(
            title: 'ProxyPin',
            debugShowCheckedModeBanner: false,
            theme: current.useMaterial3 ? material3Light : light,
            darkTheme: current.useMaterial3 ? material3Dark : darkTheme,
            themeMode: current.mode,
            home: home,
          );
        });
  }

  ThemeData lightTheme() {
    var theme = ThemeData.light(useMaterial3: false);
    theme = theme.copyWith(
        expansionTileTheme: theme.expansionTileTheme.copyWith(
          textColor: theme.textTheme.titleMedium?.color,
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          color: Colors.transparent,
          elevation: 0,
          titleTextStyle: theme.textTheme.titleMedium,
          iconTheme: theme.iconTheme,
        ),
        tabBarTheme: theme.tabBarTheme.copyWith(
          labelColor: theme.indicatorColor,
          unselectedLabelColor: theme.textTheme.titleMedium?.color,
        ));

    return theme;
  }
}
