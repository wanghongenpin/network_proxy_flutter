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
      widget.proxyServer.configuration.flushConfig();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("HTTPS代理", style: TextStyle(fontSize: 16)),
          centerTitle: true,
        ),
        body: ListView(children: [
          SwitchListTile(
              hoverColor: Colors.transparent,
              title: const Text("启用HTTPS代理"),
              value: widget.proxyServer.enableSsl,
              onChanged: (val) {
                widget.proxyServer.enableSsl = val;
                if (widget.onEnableChange != null) widget.onEnableChange!(val);
                changed = true;
                CertificateManager.cleanCache();
                setState(() {});
              }),
          Platform.isIOS ? ios() : Padding(padding: const EdgeInsets.only(left: 15), child: android()),
          const SizedBox(height: 20)
        ]));
  }

  Widget ios() {
    return ExpansionTile(
        title: const Text("安装根证书"),
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.only(left: 20),
        expandedAlignment: Alignment.topLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        children: [
          TextButton(onPressed: () => _downloadCert(), child: const Text("1. 点击下载根证书")),
          TextButton(onPressed: () {}, child: const Text("2. 安装根证书 -> 信任证书")),
          TextButton(onPressed: () {}, child: const Text("2.1 安装根证书 设置 > 已下载描述文件 > 安装")),
          Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Image.network("https://foruda.gitee.com/images/1689346516243774963/c56bc546_1073801.png",
                  height: 400)),
          TextButton(onPressed: () {}, child: const Text("2.2 信任根证书 设置 > 通用 > 关于本机 -> 证书信任设置")),
          Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Image.network("https://foruda.gitee.com/images/1689346614916658100/fd9b9e41_1073801.png",
                  height: 270)),
        ]);
  }

  Widget android() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("安装根证书"),
      ExpansionTile(
          title: const Text("Root用户:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          tilePadding: const EdgeInsets.only(left: 0),
          expandedAlignment: Alignment.topLeft,
          initiallyExpanded: true,
          shape: const Border(),
          children: [
            const Text("针对安卓Root用户做了个Magisk模块ProxyPinCA系统证书，安装完重启手机即可。"),
            TextButton(
                child: const Text("https://gitee.com/wanghongenpin/Magisk-ProxyPinCA/releases"),
                onPressed: () {
                  launchUrl(Uri.parse("https://gitee.com/wanghongenpin/Magisk-ProxyPinCA/releases"));
                }),
            const SelectableText("模块不生效可以根据网上教程安装系统根证书, 根证书命名成 243f0bfb.0"),
          ]),
      const SizedBox(height: 10),
      ExpansionTile(
          title: const Text("非Root用户: (很多软件不会信任用户证书)", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          tilePadding: const EdgeInsets.only(left: 0),
          expandedAlignment: Alignment.topLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          initiallyExpanded: true,
          shape: const Border(),
          children: [
            TextButton(
                onPressed: () => _downloadCert(),
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: "1. 点击下载根证书   "),
                  WidgetSpan(child: SelectableText("http://127.0.0.1:${widget.proxyServer.port}/ssl"))
                ]))),
            TextButton(onPressed: () {}, child: const Text("2. 打开设置 -> 安全 -> 加密和凭据 -> 安装证书 -> CA 证书")),
            ClipRRect(
                child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: .7,
                    child: Image.network(
                      "https://foruda.gitee.com/images/1689352695624941051/74e3bed6_1073801.png",
                      height: 680,
                    )))
          ])
    ]);
  }

  void _downloadCert() async {
    CertificateManager.cleanCache();
    launchUrl(Uri.parse("http://127.0.0.1:${widget.proxyServer.port}/ssl"), mode: LaunchMode.externalApplication);
  }
}
