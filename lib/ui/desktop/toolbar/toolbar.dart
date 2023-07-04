import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';
import 'package:network_proxy/ui/desktop/toolbar/ssl/ssl.dart';
import 'package:window_manager/window_manager.dart';

import '../left/domain.dart';
import 'launch/launch.dart';

class Toolbar extends StatefulWidget {
  final ProxyServer proxyServer;
  final GlobalKey<DomainWidgetState> domainStateKey;

  const Toolbar(this.proxyServer, this.domainStateKey, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _ToolbarState();
  }
}

class _ToolbarState extends State<Toolbar> {
  final ValueNotifier<bool> sllEnableListenable = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(onKeyEvent);
    widget.proxyServer.initialize().then((value) => sllEnableListenable.value = widget.proxyServer.enableSsl);
  }

  void onKeyEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
      if (ModalRoute.of(context)?.isCurrent == false) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (event.isKeyPressed(LogicalKeyboardKey.metaLeft) && event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      windowManager.blur();
      return;
    }

    if (event.isKeyPressed(LogicalKeyboardKey.metaLeft) && event.isKeyPressed(LogicalKeyboardKey.keyQ)) {
      print("windowManager.close()");
      windowManager.close();
      return;
    }
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: Platform.isMacOS ? 80 : 30)),
        SocketLaunch(proxyServer: widget.proxyServer),
        const Padding(padding: EdgeInsets.only(left: 30)),
        IconButton(
            tooltip: "清理",
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () {
              widget.domainStateKey.currentState?.clean();
            }),
        const Padding(padding: EdgeInsets.only(left: 30)),
        ValueListenableBuilder(
            valueListenable: sllEnableListenable,
            builder: (_, value, __) => SslWidget(proxyServer: widget.proxyServer)),
        const Padding(padding: EdgeInsets.only(left: 30)),
        Setting(proxyServer: widget.proxyServer),
      ],
    );
  }
}
