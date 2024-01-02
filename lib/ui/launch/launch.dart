import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/native/app_lifecycle.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class SocketLaunch extends StatefulWidget {
  static bool started = false;

  final ProxyServer proxyServer;
  final int size;
  final bool startup; //默认是否启动
  final Function? onStart;
  final Function? onStop;

  final bool serverLaunch; //是否启动代理服务器

  const SocketLaunch(
      {super.key,
      required this.proxyServer,
      this.size = 25,
      this.onStart,
      this.onStop,
      this.startup = true,
      this.serverLaunch = true});

  @override
  State<StatefulWidget> createState() {
    return _SocketLaunchState();
  }
}

class _SocketLaunchState extends State<SocketLaunch> with WindowListener, WidgetsBindingObserver {
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    AppLifecycleBinding.ensureInitialized();
    //启动代理服务器
    if (widget.startup) {
      start();
    }
    if (Platforms.isDesktop()) {
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    print("onWindowClose");
    await appExit();
  }

  Future<void> appExit() async {
    await widget.proxyServer.stop();
    SocketLaunch.started = false;
    await windowManager.destroy();
    exit(0);
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await appExit();
    return super.didRequestAppExit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      print('AppLifecycleState.detached');
      widget.onStop?.call();
      widget.proxyServer.stop();
      SocketLaunch.started = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        tooltip: SocketLaunch.started ? localizations.stop : localizations.start,
        icon: Icon(SocketLaunch.started ? Icons.stop : Icons.play_arrow_sharp,
            color: SocketLaunch.started ? Colors.red : Colors.green, size: widget.size.toDouble()),
        onPressed: () async {
          if (SocketLaunch.started) {
            if (!widget.serverLaunch) {
              setState(() {
                widget.onStop?.call();
                SocketLaunch.started = !SocketLaunch.started;
              });
              return;
            }

            widget.proxyServer.stop().then((value) {
              widget.onStop?.call();
              setState(() {
                SocketLaunch.started = !SocketLaunch.started;
              });
            });
          } else {
            start();
          }
        });
  }

  ///启动代理服务器
  start() {
    if (!widget.serverLaunch) {
      setState(() {
        widget.onStart?.call();
        SocketLaunch.started = true;
      });
      return;
    }

    widget.proxyServer.start().then((value) {
      setState(() {
        SocketLaunch.started = true;
      });
      widget.onStart?.call();
    }).catchError((e) {
      String message = localizations.proxyPortRepeat(widget.proxyServer.port);
      FlutterToastr.show(message, context, duration: 3);
    });
  }
}
