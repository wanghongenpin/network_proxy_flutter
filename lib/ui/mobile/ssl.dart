import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:url_launcher/url_launcher.dart';

class MobileSslWidget extends StatefulWidget {
  final ProxyServer proxyServer;

  const MobileSslWidget({super.key, required this.proxyServer});

  @override
  State<MobileSslWidget> createState() => _MobileSslState();
}

class _MobileSslState extends State<MobileSslWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Https代理"),
          centerTitle: true,
        ),
        body: Column(children: [
          _Switch(proxyServer: widget.proxyServer),
          ExpansionTile(
              title: const Text("安装根证书"),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.only(left: 20),
              expandedAlignment: Alignment.topLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              shape: const Border(),
              children: [
                TextButton(onPressed: () => _downloadCert(), child: const Text("1. 下载根证书安装到本系统")),
                TextButton(onPressed: () {}, child: const Text("2. 去系统设置信任根证书")),
              ])
        ]));
  }

  void _downloadCert() async {
    launchUrl(Uri.parse("http://127.0.0.1:${widget.proxyServer.port}/ssl"), mode: LaunchMode.externalApplication);
  }
}

class _Switch extends StatefulWidget {
  final ProxyServer proxyServer;

  const _Switch({Key? key, required this.proxyServer}) : super(key: key);

  @override
  State<_Switch> createState() => _SwitchState();
}

class _SwitchState extends State<_Switch> {
  bool changed = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
        hoverColor: Colors.transparent,
        title: const Text("启用Https代理", style: TextStyle(fontSize: 16)),
        value: widget.proxyServer.enableSsl,
        onChanged: (val) {
          widget.proxyServer.enableSsl = val;
          changed = true;
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
