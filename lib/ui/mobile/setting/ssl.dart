import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/crts.dart';
import 'package:network_proxy/network/util/file_read.dart';
import 'package:network_proxy/utils/lang.dart';
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
        body: Column(children: [
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
          Expanded(child: Platform.isIOS ? ios() : const AndroidCaInstall()),
          // const SizedBox(height: 20)
        ]));
  }

  Widget ios() {
    return ListView(children: [
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

  void _downloadCert() async {
    CertificateManager.cleanCache();
    launchUrl(Uri.parse("http://127.0.0.1:${widget.proxyServer.port}/ssl"), mode: LaunchMode.externalApplication);
  }
}

class AndroidCaInstall extends StatefulWidget {
  const AndroidCaInstall({super.key});

  @override
  State<StatefulWidget> createState() => _AndroidCaInstallState();
}

class _AndroidCaInstallState extends State<AndroidCaInstall> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        endDrawerEnableOpenDragGesture: false,
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(localizations.installRootCa, style: const TextStyle(fontSize: 16)),
            bottom: TabBar(
                controller: _tabController,
                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                tabs: <Widget>[
                  Tab(text: localizations.androidRoot),
                  Tab(text: localizations.androidUserCA),
                ])),
        body: TabBarView(controller: _tabController, children: [rootCA(), userCA()]));
  }

  rootCA() {
    bool isCN = localizations.localeName == 'zh';
    return ListView(padding: const EdgeInsets.all(10), children: [
      Text(localizations.androidRootMagisk),
      TextButton(
          child: Text("https://${isCN ? 'gitee' : 'github'}.com/wanghongenpin/Magisk-ProxyPinCA/releases"),
          onPressed: () {
            launchUrl(Uri.parse("https://${isCN ? 'gitee' : 'github'}.com/wanghongenpin/Magisk-ProxyPinCA/releases"));
          }),
      const SizedBox(height: 15),
      SelectableText(localizations.androidRootRename, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      FilledButton(onPressed: () => _downloadCert('243f0bfb.0'), child: Text(localizations.androidRootCADownload)),
      const SizedBox(height: 10),
      Text(
          "Android 13: ${isCN ? "将证书挂载到" : "Mount the certificate to"} '/system/etc/security/cacerts' ${isCN ? "目录" : "Directory"}"
              .fixAutoLines()),
      const SizedBox(height: 5),
      Text(
          "Android 14: ${isCN ? "将证书挂载到" : "Mount the certificate to"} '/apex/com.android.conscrypt/cacerts' ${isCN ? "目录" : "Directory"}"
              .fixAutoLines()),
      const SizedBox(height: 5),
      ClipRRect(
          child: Align(
              alignment: Alignment.topCenter,
              child: Image.network(
                scale: 0.5,
                "https://foruda.gitee.com/images/1710181660282752846/cb520c0b_1073801.png",
                height: 460,
              )))
    ]);
  }

  userCA() {
    bool isCN = localizations.localeName == 'zh';

    return ListView(padding: const EdgeInsets.all(10), children: [
      Text(localizations.androidUserCATips, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 5),
      TextButton(
        style: const ButtonStyle(alignment: Alignment.centerLeft),
        onPressed: () {},
        child: Text("1. ${localizations.downloadRootCa} ", textAlign: TextAlign.left),
      ),
      FilledButton(onPressed: () => _downloadCert('ProxyPinCA.crt'), child: Text(localizations.downloadRootCa)),
      const SizedBox(height: 5),
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
    ]);
  }

  void _downloadCert(String name) async {
    String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select the path to save:',
        fileName: name,
        bytes: await FileRead.read('assets/certs/ca.crt'));

    if (outputFile != null && mounted) {
      AppLocalizations localizations = AppLocalizations.of(context)!;
      FlutterToastr.show(localizations.success, context);
    }
  }
}
