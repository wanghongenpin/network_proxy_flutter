import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/desktop/toolbar/phone_connect.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';
import 'package:network_proxy/ui/desktop/toolbar/ssl/ssl.dart';
import 'package:network_proxy/ui/launch/launch.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:window_manager/window_manager.dart';

import '../left/domain.dart';

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
  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(onKeyEvent);
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
        const Padding(padding: EdgeInsets.only(left: 20)),
        IconButton(
            tooltip: "清理",
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () {
              widget.domainStateKey.currentState?.clean();
            }),
        const Padding(padding: EdgeInsets.only(left: 20)),
        SslWidget(proxyServer: widget.proxyServer),
        const Padding(padding: EdgeInsets.only(left: 20)),
        Setting(proxyServer: widget.proxyServer),
        const Padding(padding: EdgeInsets.only(left: 20)),
        IconButton(
            tooltip: "手机连接",
            icon: const Icon(Icons.phone_iphone),
            onPressed: () async {
              final ips = await localIps();
              phoneConnect(ips, widget.proxyServer.port);
            }),
      ],
    );
  }

  phoneConnect(List<String> hosts, int port) {
    showDialog(
        context: context,
        builder: (context) {
          return PhoneConnect(proxyServer: widget.proxyServer, hosts: hosts);
        });
  }
}
