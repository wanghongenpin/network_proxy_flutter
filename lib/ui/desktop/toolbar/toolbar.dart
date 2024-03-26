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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../left/list.dart';

/// @author wanghongen
/// 2023/10/8
class Toolbar extends StatefulWidget {
  final ProxyServer proxyServer;
  final GlobalKey<DomainWidgetState> domainStateKey;
  final ValueNotifier<int> sideNotifier;

  const Toolbar(this.proxyServer, this.domainStateKey, {super.key, required this.sideNotifier});

  @override
  State<StatefulWidget> createState() {
    return _ToolbarState();
  }
}

class _ToolbarState extends State<Toolbar> {
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(onKeyEvent);
  }

  bool onKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (ModalRoute.of(context)?.isCurrent == false) {
        Navigator.of(context).pop();
        return true;
      }
    }

    if (HardwareKeyboard.instance.isMetaPressed && event.logicalKey == LogicalKeyboardKey.keyW) {
      windowManager.blur();
      return true;
    }

    if (HardwareKeyboard.instance.isMetaPressed && event.logicalKey == LogicalKeyboardKey.keyQ) {
      windowManager.close();
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: Platform.isMacOS ? 80 : 30)),
        SocketLaunch(proxyServer: widget.proxyServer, startup: widget.proxyServer.configuration.startup),
        const Padding(padding: EdgeInsets.only(left: 20)),
        IconButton(
            tooltip: localizations.clear,
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () {
              widget.domainStateKey.currentState?.clean();
            }),
        const Padding(padding: EdgeInsets.only(left: 20)),
        SslWidget(proxyServer: widget.proxyServer), // SSL配置
        const Padding(padding: EdgeInsets.only(left: 20)),
        Setting(proxyServer: widget.proxyServer), // 设置
        const Padding(padding: EdgeInsets.only(left: 20)),
        IconButton(
            tooltip: localizations.mobileConnect,
            icon: const Icon(Icons.phone_iphone),
            onPressed: () async {
              final ips = await localIps();
              phoneConnect(ips, widget.proxyServer.port);
            }),
        const Expanded(child: SizedBox()), //自动扩展挤压
        ValueListenableBuilder(
            valueListenable: widget.sideNotifier,
            builder: (_, sideIndex, __) => IconButton(
                  icon: Icon(Icons.space_dashboard, size: 20, color: sideIndex >= 0 ? Colors.blueGrey : Colors.grey),
                  onPressed: () {
                    if (widget.sideNotifier.value >= 0) {
                      widget.sideNotifier.value = -1;
                    } else {
                      widget.sideNotifier.value = 0;
                    }
                  },
                )), //右对齐
        const Padding(padding: EdgeInsets.only(left: 30)),
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
