import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/toolbar/setting/request_rewrite.dart';
import 'package:network_proxy/ui/toolbar/setting/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'filter.dart';

class Setting extends StatefulWidget {
  final ProxyServer proxyServer;

  const Setting({super.key, required this.proxyServer});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: "设置",
      icon: const Icon(Icons.settings),
      surfaceTintColor: Colors.white70,
      offset: const Offset(10, 30),
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(child: PortWidget(proxyServer: widget.proxyServer)),
          const PopupMenuItem(
            child: ThemeSetting(),
          ),
          PopupMenuItem<String>(
              child: ListTile(
                  title: const Text("域名过滤"),
                  dense: true,
                  trailing: const Icon(Icons.arrow_right),
                  onTap: () => _filter())),
          PopupMenuItem<String>(
              child: ListTile(
                  title: const Text("请求重写"),
                  dense: true,
                  trailing: const Icon(Icons.arrow_right),
                  onTap: () => _reqeustRewrite())),
          PopupMenuItem<String>(
            child: const ListTile(title: Text("Github"), dense: true, trailing: Icon(Icons.arrow_right)),
            onTap: () {
              launchUrl(Uri.parse("https://github.com/wanghongenpin/network-proxy-flutter"));
            },
          )
        ];
      },
    );
  }

  void _reqeustRewrite() {
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

  void _filter() {
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

  const PortWidget({super.key, required this.proxyServer});

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
        widget.proxyServer.restart();
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
      const Text("端口号：", style: TextStyle(fontSize: 13)),
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
