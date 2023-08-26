import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/component/encoder.dart';
import 'package:network_proxy/ui/mobile/request/request_editor.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class Toolbox extends StatefulWidget {
  final ProxyServer? proxyServer;

  const Toolbox({Key? key, this.proxyServer}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ToolboxState();
  }
}

class _ToolboxState extends State<Toolbox> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(thickness: 0.3),
          InkWell(
              onTap: httpRequest,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Column(children: [Icon(Icons.http), Text('发起请求')]),
              )),
          const Divider(thickness: 0.3),
          const Text('编码', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Row(
            children: [
              InkWell(
                  onTap: () => encode(EncoderType.url),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Column(children: [Icon(Icons.link), Text(' URL')]),
                  )),
              const SizedBox(width: 10),
              InkWell(
                  onTap: () => encode(EncoderType.base64),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Column(children: [Icon(Icons.currency_bitcoin), Text('Base64')]),
                  )),
              const SizedBox(width: 15),
              InkWell(
                  onTap: () => encode(EncoderType.md5),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Column(children: [Icon(Icons.enhanced_encryption), Text('MD5')]),
                  )),
            ],
          )
        ],
      ),
    );
  }

  encode(EncoderType type) async {
    if (Platforms.isMobile()) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => EncoderWidget(type: type)));
      return;
    }

    var ratio = 1.0;
    if (Platform.isWindows) {
      ratio = WindowManager.instance.getDevicePixelRatio();
    }

    final window = await DesktopMultiWindow.createWindow(jsonEncode(
      {'name': 'EncoderWidget', 'type': type.name},
    ));
    window.setTitle('编码');
    window
      ..setFrame(const Offset(80, 80) & Size(900 * ratio, 600 * ratio))
      ..center()
      ..show();
  }

  httpRequest() async {
    if (Platforms.isMobile()) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => MobileRequestEditor(proxyServer: widget.proxyServer)));
      return;
    }

    var size = MediaQuery.of(context).size;
    var ratio = 1.0;
    if (Platform.isWindows) {
      ratio = WindowManager.instance.getDevicePixelRatio();
    }

    final window = await DesktopMultiWindow.createWindow(jsonEncode(
      {'name': 'RequestEditor'},
    ));
    window.setTitle('请求发送');
    window
      ..setFrame(const Offset(100, 100) & Size(960 * ratio, size.height * ratio))
      ..center()
      ..show();
  }
}
