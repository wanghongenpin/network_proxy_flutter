import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/system_proxy.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/request_rewrite.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'filter.dart';

///设置菜单
class Setting extends StatefulWidget {
  final ProxyServer proxyServer;

  const Setting({super.key, required this.proxyServer});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  late ValueNotifier<bool> enableDesktopListenable;

  @override
  void initState() {
    enableDesktopListenable = ValueNotifier<bool>(widget.proxyServer.enableDesktop);
    super.initState();
  }

  @override
  void dispose() {
    enableDesktopListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: "设置",
      icon: const Icon(Icons.settings),
      surfaceTintColor: Colors.white70,
      offset: const Offset(10, 30),
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
              padding: const EdgeInsets.all(0),
              child: PortWidget(proxyServer: widget.proxyServer, textStyle: const TextStyle(fontSize: 13))),
          PopupMenuItem<String>(
              padding: const EdgeInsets.all(0),
              child: ValueListenableBuilder(
                  valueListenable: enableDesktopListenable,
                  builder: (_, val, __) => SwitchListTile(
                      hoverColor: Colors.transparent,
                      title: const Text("抓取电脑请求"),
                      visualDensity: const VisualDensity(horizontal: -4),
                      dense: true,
                      value: widget.proxyServer.enableDesktop,
                      onChanged: (val) {
                        SystemProxy.setSystemProxyEnable(widget.proxyServer.port, val, widget.proxyServer.enableSsl);
                        widget.proxyServer.enableDesktop = val;
                        enableDesktopListenable.value = !enableDesktopListenable.value;
                        widget.proxyServer.flushConfig();
                      }))),
          const PopupMenuItem(padding: EdgeInsets.all(0), child: ThemeSetting(dense: true)),
          menuItem("域名过滤", onTap: () => hostFilter()),
          menuItem("请求重写", onTap: () => requestRewrite()),
          menuItem(
            "Github",
            onTap: () {
              launchUrl(Uri.parse("https://github.com/wanghongenpin/network_proxy_flutter"));
            },
          )
        ];
      },
    );
  }

  PopupMenuItem<String> menuItem(String title, {GestureTapCallback? onTap}) {
    return PopupMenuItem<String>(
        padding: const EdgeInsets.all(0),
        child: ListTile(
          title: Text(title),
          dense: true,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          trailing: const Icon(Icons.arrow_right),
          onTap: onTap,
        ));
  }

  ///请求重写Dialog
  void requestRewrite() {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            scrollable: true,
            title: Row(children: [
              const Text("请求重写"),
              Expanded(
                  child: Align(
                      alignment: Alignment.topRight,
                      child: ElevatedButton.icon(
                          icon: const Icon(Icons.close, size: 15),
                          label: const Text("关闭"),
                          onPressed: () => Navigator.of(context).pop())))
            ]),
            content: RequestRewrite(proxyServer: widget.proxyServer),
          );
        });
  }

  ///show域名过滤Dialog
  void hostFilter() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return FilterDialog(proxyServer: widget.proxyServer);
      },
    );
  }
}

class PortWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final TextStyle? textStyle;

  const PortWidget({super.key, required this.proxyServer, this.textStyle});

  @override
  State<StatefulWidget> createState() {
    return _PortState();
  }
}

class _PortState extends State<PortWidget> {
  final textController = TextEditingController();
  final FocusNode portFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    textController.text = widget.proxyServer.port.toString();
    portFocus.addListener(() async {
      //失去焦点
      if (!portFocus.hasFocus && textController.text != widget.proxyServer.port.toString()) {
        widget.proxyServer.port = int.parse(textController.text);
        if (widget.proxyServer.isRunning) {
          widget.proxyServer.restart();
        }
        widget.proxyServer.flushConfig();
      }
    });
  }

  @override
  void dispose() {
    portFocus.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Padding(padding: EdgeInsets.only(left: 16)),
      Text("端口号：", style: widget.textStyle),
      SizedBox(
          width: 80,
          child: TextFormField(
            focusNode: portFocus,
            controller: textController,
            textAlign: TextAlign.center,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(5),
              FilteringTextInputFormatter.allow(RegExp("[0-9]"))
            ],
            decoration: const InputDecoration(),
          ))
    ]);
  }
}
