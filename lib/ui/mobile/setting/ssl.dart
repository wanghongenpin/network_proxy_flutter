import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/crts.dart';
import 'package:url_launcher/url_launcher.dart';

class MobileSslWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final Function(bool val)? onEnableChange;

  const MobileSslWidget({super.key, required this.proxyServer, this.onEnableChange});

  @override
  State<MobileSslWidget> createState() => _MobileSslState();
}

class _MobileSslState extends State<MobileSslWidget> {
  bool changed = false;

  @override
  void dispose() {
    if (changed) {
      widget.proxyServer.flushConfig();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("HTTPS代理"),
          centerTitle: true,
        ),
        body: ListView(children: [
          SwitchListTile(
              hoverColor: Colors.transparent,
              title: const Text("启用HTTPS代理", style: TextStyle(fontSize: 16)),
              value: widget.proxyServer.enableSsl,
              onChanged: (val) {
                widget.proxyServer.enableSsl = val;
                if (widget.onEnableChange != null) widget.onEnableChange!(val);
                changed = true;
                CertificateManager.cleanCache();
                setState(() {});
              }),
          ExpansionTile(
              title: const Text("安装根证书"),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.only(left: 20),
              expandedAlignment: Alignment.topLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              shape: const Border(),
              children: [
                TextButton(onPressed: () => _downloadCert(), child: const Text("1. 点击下载根证书")),
                ...(Platform.isIOS ? ios() : android()),
                const SizedBox(height: 20)
              ])
        ]));
  }

  List<Widget> ios() {
    return [
      TextButton(onPressed: () {}, child: const Text("2. 安装根证书 -> 信任证书")),
      TextButton(onPressed: () {}, child: const Text("2.1 安装根证书 设置 > 已下载描述文件 > 安装")),
      Padding(
          padding: const EdgeInsets.only(left: 15),
          child:
              Image.network("https://foruda.gitee.com/images/1689346516243774963/c56bc546_1073801.png", height: 400)),
      TextButton(onPressed: () {}, child: const Text("2.2 信任根证书 设置 > 通用 > 关于本机 -> 证书信任设置")),
      Padding(
          padding: const EdgeInsets.only(left: 15),
          child:
              Image.network("https://foruda.gitee.com/images/1689346614916658100/fd9b9e41_1073801.png", height: 270)),
    ];
  }

  List<Widget> android() {
    return [
      TextButton(onPressed: () {}, child: const Text("2. 打开设置 -> 安全 -> 加密和凭据 -> 安装证书 -> CA 证书")),
      ClipRRect(
          child: Align(
              alignment: Alignment.topCenter,
              heightFactor: .7,
              child: Image.network(
                "https://foruda.gitee.com/images/1689352695624941051/74e3bed6_1073801.png",
                height: 680,
              )))
    ];
  }

  void _downloadCert() async {
    if (!widget.proxyServer.isRunning) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("提示"),
              content: const Text("请先启动代理服务"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("确定"))
              ],
            );
          });
      return;
    }
    launchUrl(Uri.parse("http://127.0.0.1:${widget.proxyServer.port}/ssl"), mode: LaunchMode.externalApplication);
    CertificateManager.cleanCache();
  }
}
