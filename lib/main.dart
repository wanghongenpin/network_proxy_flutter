import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/ui/component/chinese_font.dart';
import 'package:network_proxy/ui/component/multi_window.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/ui/desktop/desktop.dart';
import 'package:network_proxy/ui/desktop/window_listener.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/utils/navigator.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  var instance = AppConfiguration.instance;
  //多窗口
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args[2].isEmpty ? const {} : jsonDecode(args[2]) as Map<String, dynamic>;
    runApp(FluentApp(multiWindow(windowId, argument), (await instance)));
    return;
  }

  var configuration = Configuration.instance;
  //移动端
  if (Platforms.isMobile()) {
    var appConfiguration = await instance;
    runApp(FluentApp(MobileHomePage((await configuration), appConfiguration), appConfiguration));
    return;
  }

  await windowManager.ensureInitialized();
  var appConfiguration = await instance;

  //设置窗口大小
  Size windowSize = appConfiguration.windowSize ?? (Platform.isMacOS ? const Size(1230, 750) : const Size(1100, 650));
  WindowOptions windowOptions = WindowOptions(
      minimumSize: const Size(1000, 600),
      size: windowSize,
      center: true,
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal);

  Offset? windowPosition = appConfiguration.windowPosition;
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (windowPosition != null) {
      await windowManager.setPosition(windowPosition);
    }

    await windowManager.show();
    await windowManager.focus();
  });

  registerMethodHandler();
  windowManager.addListener(WindowChangeListener(appConfiguration));

  runApp(FluentApp(DesktopHomePage(await configuration, appConfiguration), appConfiguration));
}

class FluentApp extends StatelessWidget {
  final Widget home;
  final AppConfiguration appConfiguration;

  const FluentApp(this.home, this.appConfiguration, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: appConfiguration.globalChange,
        builder: (_, current, __) {
          return MaterialApp(
            title: 'ProxyPin',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorHelper.navigatorKey,
            theme: theme(Brightness.light),
            darkTheme: theme(Brightness.dark),
            themeMode: appConfiguration.themeMode,
            locale: appConfiguration.language,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          );
        });
  }

  ThemeData theme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    Color? themeColor = isDark ? appConfiguration.themeColor : appConfiguration.themeColor;
    Color? cardColor = isDark ? Colors.grey[850]! : Colors.white;
    Color? surfaceContainer = isDark ? Colors.grey[800] : Colors.white;

    var colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: themeColor,
      primary: themeColor,
      surface: cardColor,
      onPrimary: isDark ? Colors.white : null,
      surfaceContainer: surfaceContainer,
    );
    var themeData =
        ThemeData(brightness: brightness, useMaterial3: appConfiguration.useMaterial3, colorScheme: colorScheme);

    if (!appConfiguration.useMaterial3) {
      themeData = themeData.copyWith(
        appBarTheme: themeData.appBarTheme.copyWith(
          iconTheme: themeData.iconTheme.copyWith(size: 20),
          color: themeData.canvasColor,
          elevation: 0,
          titleTextStyle: themeData.textTheme.titleMedium,
        ),
        tabBarTheme: themeData.tabBarTheme.copyWith(
          labelColor: themeData.colorScheme.primary,
          indicatorColor: themeColor,
          unselectedLabelColor: themeData.textTheme.titleMedium?.color,
        ),
      );
    }

    if (Platform.isWindows) {
      themeData = themeData.useSystemChineseFont();
    }

    return themeData.copyWith(
        dialogTheme:
            themeData.dialogTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
}
