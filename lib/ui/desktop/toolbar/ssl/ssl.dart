import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/crts.dart';
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
                title: const Text("安装根证书到本机"),
                trailing: const Icon(Icons.arrow_right),
                onTap: () {
                  pcCer();
                },
              )),
          PopupMenuItem<String>(
            padding: const EdgeInsets.all(0),
            child: ListTile(
                title: const Text("安装根证书到 iOS"),
                dense: true,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                trailing: const Icon(Icons.arrow_right),
                onTap: () async {
                  iosCer(await localIp());
                }),
          ),
          PopupMenuItem<String>(
            padding: const EdgeInsets.all(0),
            child: ListTile(
                title: const Text("安装根证书到 Android"),
                dense: true,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                trailing: const Icon(Icons.arrow_right),
                onTap: () async {
                  androidCer(await localIp());
                }),
          ),
          PopupMenuItem<String>(
            padding: const EdgeInsets.all(0),
            child: ListTile(
                title: const Text("下载根证书"),
                dense: true,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                trailing: const Icon(Icons.arrow_right),
                onTap: () async {
                  if (!widget.proxyServer.isRunning) {
                    FlutterToastr.show("请先启动抓包", context);
                    return;
                  }
                  launchUrl(Uri.parse("http://127.0.0.1:${widget.proxyServer.port}/ssl"));
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
              title: Row(children: [
                const Text("电脑HTTPS抓包配置", style: TextStyle(fontSize: 18)),
                Expanded(
                    child: Align(
                        alignment: Alignment.topRight,
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.close, size: 15),
                            label: const Text("关闭"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            })))
              ]),
              alignment: Alignment.center,
              children: [
                Text(" 安装证书到本系统，${Platform.isMacOS ? "“安装完选择“始终信任此证书”" : "选择“受信任的根证书颁发机构”"}"),
                const SizedBox(height: 10),
                FilledButton(onPressed: _installCert, child: const Text("安装证书")),
                const SizedBox(height: 10),
                Platform.isMacOS
                    ? Image.network("https://foruda.gitee.com/images/1689323260158189316/c2d881a4_1073801.png",
                        width: 800, height: 500)
                    : Row(children: [
                        Image.network("https://foruda.gitee.com/images/1689335589122168223/c904a543_1073801.png",
                            width: 400, height: 400),
                        const SizedBox(width: 10),
                        Image.network("https://foruda.gitee.com/images/1689335334688878324/f6aa3a3a_1073801.png",
                            width: 400, height: 400)
                      ])
              ]);
        });
  }

  void iosCer(String host) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
              contentPadding: const EdgeInsets.all(16),
              title: Row(children: [
                const Text("iOS根证书安装指南", style: TextStyle(fontSize: 18)),
                Expanded(
                    child: Align(
                        alignment: Alignment.topRight,
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.close, size: 15),
                            label: const Text("关闭"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            })))
              ]),
              alignment: Alignment.center,
              children: [
                SelectableText.rich(TextSpan(text: "1. 配置手机Wi-Fi代理 Host：$host  Port：${widget.proxyServer.port}")),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text("2. 在 iOS 设备上打开 Safari访问：\t"),
                    SelectableText.rich(
                        TextSpan(text: "http://proxy.pin/ssl", style: TextStyle(decoration: TextDecoration.underline)))
                  ],
                ),
                const SizedBox(height: 10),
                const Text("3. 安装根证书并信任证书"),
                const SizedBox(height: 10),
                Row(children: [
                  Column(children: [
                    const Text("3.1 安装证书 设置 > 已下载描述文件 > 安装", style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                    Image.network("https://foruda.gitee.com/images/1689346516243774963/c56bc546_1073801.png",
                        height: 270, width: 300)
                  ]),
                  const SizedBox(width: 10),
                  Column(children: [
                    const Text("3.2 信任证书 设置 > 通用 > 关于本机 > 证书信任设置", style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                    Image.network("https://foruda.gitee.com/images/1689346614916658100/fd9b9e41_1073801.png",
                        height: 270, width: 300)
                  ])
                ])
              ]);
        });
  }

  void androidCer(String host) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
              contentPadding: const EdgeInsets.all(16),
              title: Row(children: [
                const Text("Android根证书安装指南", style: TextStyle(fontSize: 18)),
                Expanded(
                    child: Align(
                        alignment: Alignment.topRight,
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.close, size: 15),
                            label: const Text("关闭"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            })))
              ]),
              alignment: Alignment.center,
              children: [
                SelectableText.rich(TextSpan(text: "1. 配置手机Wi-Fi代理 Host：$host  Port：${widget.proxyServer.port}")),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text("2. 在 Android 设备上打开浏览器访问：\t"),
                    SelectableText.rich(
                        TextSpan(text: "http://proxy.pin/ssl", style: TextStyle(decoration: TextDecoration.underline)))
                  ],
                ),
                const SizedBox(height: 10),
                const Text("2. 打开设置 -> 安全 -> 加密和凭据 -> 安装证书 -> CA 证书"),
                const SizedBox(height: 10),
                ClipRRect(
                    child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: .7,
                        child: Image.network(
                          "https://foruda.gitee.com/images/1689352695624941051/74e3bed6_1073801.png",
                          height: 550,
                        )))
              ]);
        });
  }

  void _installCert() async {
    final String appPath = await getApplicationSupportDirectory().then((value) => value.path);
    var caFile = File("$appPath${Platform.pathSeparator}ProxyPinCA.crt");
    if (!(await caFile.exists())) {
      var body = await rootBundle.load('assets/certs/ca.crt');
      await caFile.writeAsBytes(body.buffer.asUint8List());
    }
    launchUrl(Uri.file(caFile.path)).then((value) => CertificateManager.cleanCache());
  }
}

class _Switch extends StatefulWidget {
  final ProxyServer proxyServer;
  final Function(bool val) onEnableChange;

  const _Switch({Key? key, required this.proxyServer, required this.onEnableChange}) : super(key: key);

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
          CertificateManager.cleanCache();
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
