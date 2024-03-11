import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
          title: Text(localizations.httpsProxy, style: const TextStyle(fontSize: 16)),
          centerTitle: true,
        ),
        body: ListView(children: [
          SwitchListTile(
              hoverColor: Colors.transparent,
              title: Text(localizations.enabledHttps),
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
    return Column(children: [
      // if (localizations.localeName != 'zh')
      //   ExpansionTile(
      //     title: Text(localizations.useGuide),
      //     shape: const Border(),
      //     maintainState: true,
      //     children: [
      //       Container(
      //           height: 350, padding: const EdgeInsets.only(left: 15, right: 15), child: const VideoPlayerScreen())
      //     ],
      //   ),
      ExpansionTile(
          title: Text(localizations.installRootCa),
          initiallyExpanded: true,
          childrenPadding: const EdgeInsets.only(left: 20),
          expandedAlignment: Alignment.topLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          shape: const Border(),
          children: [
            TextButton(onPressed: () => _downloadCert(), child: Text("1. ${localizations.downloadRootCa}")),
            TextButton(onPressed: () {}, child: Text("2. ${localizations.installRootCa} -> ${localizations.trustCa}")),
            TextButton(onPressed: () {}, child: Text("2.1 ${localizations.installCaDescribe}")),
            Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Image.network("https://foruda.gitee.com/images/1689346516243774963/c56bc546_1073801.png",
                    height: 400)),
            TextButton(onPressed: () {}, child: Text("2.2 ${localizations.trustCaDescribe}")),
            Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Image.network("https://foruda.gitee.com/images/1689346614916658100/fd9b9e41_1073801.png",
                    height: 270)),
          ])
    ]);
  }

  Widget android() {
    bool isCN = localizations.localeName == 'zh';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(localizations.installRootCa),
      ExpansionTile(
          title: Text(localizations.androidRoot, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          tilePadding: const EdgeInsets.only(left: 0),
          expandedAlignment: Alignment.topLeft,
          initiallyExpanded: true,
          shape: const Border(),
          children: [
            Text(localizations.androidRootMagisk),
            TextButton(
                child: Text("https://${isCN ? 'gitee' : 'github'}.com/wanghongenpin/Magisk-ProxyPinCA/releases"),
                onPressed: () {
                  launchUrl(
                      Uri.parse("https://${isCN ? 'gitee' : 'github'}.com/wanghongenpin/Magisk-ProxyPinCA/releases"));
                }),
            SelectableText(localizations.androidRootRename),
          ]),
      const SizedBox(height: 20),
      ExpansionTile(
          title: Text(localizations.androidUserCA, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          tilePadding: const EdgeInsets.only(left: 0),
          expandedAlignment: Alignment.topLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          initiallyExpanded: true,
          shape: const Border(),
          children: [
            TextButton(
                onPressed: () => _downloadCert(),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: "1. ${localizations.downloadRootCa}   "),
                  WidgetSpan(child: SelectableText("http://127.0.0.1:${widget.proxyServer.port}/ssl"))
                ]))),
            TextButton(onPressed: () {}, child: Text("2. ${localizations.androidUserCAInstall}")),
            TextButton(
                onPressed: () {
                  launchUrl(Uri.parse(isCN
                      ? "https://gitee.com/wanghongenpin/network-proxy-flutter/wikis/%E5%AE%89%E5%8D%93%E6%97%A0ROOT%E4%BD%BF%E7%94%A8Xposed%E6%A8%A1%E5%9D%97%E6%8A%93%E5%8C%85"
                      : "https://github.com/wanghongenpin/network_proxy_flutter/wiki/Android-without-ROOT-uses-Xposed-module-to-capture-packets"));
                },
                child: Text(localizations.androidUserXposed)),
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
