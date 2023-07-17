import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SslWidget extends StatefulWidget {
  final ProxyServer proxyServer;

  const SslWidget({super.key, required this.proxyServer});

  @override
  State<SslWidget> createState() => _SslState();
}

class _SslState extends State<SslWidget> {
  bool _enableSsl = true;

  @override
  void initState() {
    super.initState();

    widget.proxyServer.initializedListener(() {
      _enableSsl = widget.proxyServer.enableSsl;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.https, color: _enableSsl ? null : Colors.red),
      surfaceTintColor: Colors.white70,
      tooltip: "HTTPS代理",
      offset: const Offset(10, 30),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
              padding: const EdgeInsets.all(0),
              child: _Switch(
                  proxyServer: widget.proxyServer,
                  onEnableChange: (val) => setState(() {
                        _enableSsl = val;
                      }))),
          PopupMenuItem(
              padding: const EdgeInsets.all(0),
              child: ListTile(
                dense: true,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                title: const Text("安装根证书到系统"),
                trailing: const Icon(Icons.arrow_right),
                onTap: () {
                  pcCer();
                },
              )),
          PopupMenuItem<String>(
            padding: const EdgeInsets.all(0),
            child: ListTile(
                title: const Text("安装根证书到手机"),
                dense: true,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                trailing: const Icon(Icons.arrow_right),
                onTap: () async {
                  mobileCer(await localIp());
                }),
          )
        ];
      },
    );
  }

  void pcCer() async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
              contentPadding: const EdgeInsets.all(16),
              title: const Text("电脑HTTPS抓包配置", style: TextStyle(fontSize: 16)),
              alignment: Alignment.center,
              children: [
                Text(
                    " 安装证书到本系统，${Platform.isMacOS ? "“安装完选择“始终信任此证书”" : "选择“受信任的根证书颁发机构”"}"),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: _installCert, child: const Text("安装证书")),
                const SizedBox(height: 10),
                Platform.isMacOS
                    ? Image.network(
                        "https://foruda.gitee.com/images/1689323260158189316/c2d881a4_1073801.png",
                        width: 800,
                        height: 500)
                    : Row(children: [
                        Image.network(
                            "https://foruda.gitee.com/images/1689335589122168223/c904a543_1073801.png",
                            width: 400,
                            height: 400),
                        const SizedBox(width: 10),
                        Image.network(
                            "https://foruda.gitee.com/images/1689335334688878324/f6aa3a3a_1073801.png",
                            width: 400,
                            height: 400)
                      ])
              ]);
        });
  }

  void mobileCer(String host) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
              contentPadding: const EdgeInsets.all(16),
              title: const Text("手机HTTPS抓包配置", style: TextStyle(fontSize: 16)),
              alignment: Alignment.center,
              children: [
                const Text("1. 根证书安装到本系统（已完成忽略）"),
                const SizedBox(height: 10),
                SelectableText.rich(TextSpan(
                    text:
                        "2. 配置手机Wifi代理 Host：$host  Port：${widget.proxyServer.port}")),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text("3. 打开手机系统自带浏览器访问：\t"),
                    SelectableText.rich(TextSpan(
                        text: "http://proxy.pin/ssl",
                        style: TextStyle(decoration: TextDecoration.underline)))
                  ],
                ),
                const SizedBox(height: 10),
                const Text("4. 打开手机设置下载安装证书信任证书\n\t  设置 > 通用 > 关于本机 > 证书信任设置"),
                const SizedBox(height: 20),
                const Text("  抓微信小程序ios需要开启本地网络权限",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ]);
        });
  }

  void _installCert() async {
    final String appPath =
        await getApplicationSupportDirectory().then((value) => value.path);
    var caFile = File("$appPath${Platform.pathSeparator}ProxyPinCA.crt");
    if (!(await caFile.exists())) {
      var body = await rootBundle.load('assets/certs/ca.crt');
      await caFile.writeAsBytes(body.buffer.asUint8List());
    }
    launchUrl(Uri.file(caFile.path));
  }
}

class _Switch extends StatefulWidget {
  final ProxyServer proxyServer;
  final Function(bool val) onEnableChange;

  const _Switch(
      {Key? key, required this.proxyServer, required this.onEnableChange})
      : super(key: key);

  @override
  State<_Switch> createState() => _SwitchState();
}

class _SwitchState extends State<_Switch> {
  bool changed = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
        hoverColor: Colors.transparent,
        title: const Text("启用HTTPS代理", style: TextStyle(fontSize: 12)),
        visualDensity: const VisualDensity(horizontal: -4),
        dense: true,
        value: widget.proxyServer.enableSsl,
        onChanged: (val) {
          widget.proxyServer.enableSsl = val;
          changed = true;
          widget.onEnableChange(val);
          setState(() {});
        });
  }

  @override
  void dispose() {
    super.dispose();
    if (changed) {
      widget.proxyServer.flushConfig();
    }
  }
}
