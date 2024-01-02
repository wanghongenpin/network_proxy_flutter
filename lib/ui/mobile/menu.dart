import 'dart:io';

import 'package:easy_permission/easy_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/component/toolbox.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/ui/mobile/about.dart';
import 'package:network_proxy/ui/mobile/connect_remote.dart';
import 'package:network_proxy/ui/mobile/request/favorite.dart';
import 'package:network_proxy/ui/mobile/request/history.dart';
import 'package:network_proxy/ui/mobile/setting/app_whitelist.dart';
import 'package:network_proxy/ui/mobile/setting/filter.dart';
import 'package:network_proxy/ui/mobile/setting/proxy.dart';
import 'package:network_proxy/ui/mobile/setting/request_rewrite.dart';
import 'package:network_proxy/ui/mobile/setting/script.dart';
import 'package:network_proxy/ui/mobile/setting/ssl.dart';
import 'package:network_proxy/ui/mobile/setting/theme.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:url_launcher/url_launcher.dart';

///左侧抽屉
class DrawerWidget extends StatelessWidget {
  final ProxyServer proxyServer;

  const DrawerWidget({super.key, required this.proxyServer});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
          child: const Text(''),
        ),
        ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(localizations.favorites),
            onTap: () => navigator(context, MobileFavorites(proxyServer: proxyServer))),
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(localizations.history),
          onTap: () => navigator(context, MobileHistory(proxyServer: proxyServer)),
        ),
        const Divider(thickness: 0.3),
        ListTile(
            title: Text(localizations.httpsProxy),
            leading: const Icon(Icons.https),
            onTap: () => navigator(context, MobileSslWidget(proxyServer: proxyServer))),
        ListTile(
            title: Text(localizations.filter),
            leading: const Icon(Icons.filter_alt_outlined),
            onTap: () => navigator(context, FilterMenu(proxyServer: proxyServer))),
        ListTile(
            title: Text(localizations.requestRewrite),
            leading: const Icon(Icons.replay_outlined),
            onTap: () async =>
                navigator(context, MobileRequestRewrite(requestRewrites: (await RequestRewrites.instance)))),
        ListTile(
            title: Text(localizations.script),
            leading: const Icon(Icons.code),
            onTap: () => navigator(context, const MobileScript())),
        ListTile(
            title: Text(localizations.setting),
            leading: const Icon(Icons.settings),
            onTap: () => navigator(
                context,
                futureWidget(AppConfiguration.instance,
                    (appConfiguration) => SettingMenu(proxyServer: proxyServer, appConfiguration: appConfiguration)))),
        ListTile(
            title: Text(localizations.about),
            leading: const Icon(Icons.info_outline),
            onTap: () => navigator(context, const About())),
      ],
    ));
  }
}

///跳转页面
navigator(BuildContext context, Widget widget) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (BuildContext context) {
      return widget;
    }),
  );
}

///设置
class SettingMenu extends StatelessWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const SettingMenu({super.key, required this.proxyServer, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: AppBar(title: Text(localizations.setting, style: const TextStyle(fontSize: 16)), centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.all(5),
            child: ListView(children: [
              ListTile(
                  title: Text(localizations.proxy),
                  trailing: const Icon(Icons.arrow_right),
                  onTap: () => navigator(context, ProxySetting(proxyServer: proxyServer))),
              ListTile(
                title: Text(localizations.language),
                trailing: const Icon(Icons.arrow_right),
                onTap: () => _language(context),
              ),
              MobileThemeSetting(appConfiguration: appConfiguration),
              Platform.isIOS
                  ? const SizedBox()
                  : ListTile(
                      title: Text(localizations.windowMode),
                      subtitle: Text(localizations.windowModeSubTitle, style: const TextStyle(fontSize: 12)),
                      trailing: SwitchWidget(
                          value: appConfiguration.smallWindow,
                          onChanged: (value) {
                            appConfiguration.smallWindow = value;
                            appConfiguration.flushConfig();
                          })),
              ListTile(
                  title: Text(localizations.headerExpanded),
                  subtitle: Text(localizations.headerExpandedSubtitle, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      value: appConfiguration.headerExpanded,
                      onChanged: (value) {
                        appConfiguration.headerExpanded = value;
                        appConfiguration.flushConfig();
                      }))
            ])));
  }

  //选择语言
  void _language(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.only(left: 5, top: 5),
            actionsPadding: const EdgeInsets.only(bottom: 5, right: 5),
            title: Text(localizations.language, style: const TextStyle(fontSize: 16)),
            content: Wrap(
              children: [
                TextButton(
                    onPressed: () {
                      appConfiguration.language = null;
                      Navigator.of(context).pop();
                    },
                    child: Text(localizations.followSystem)),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'zh');
                      Navigator.of(context).pop();
                    },
                    child: const Text("简体中文")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    child: const Text("English"),
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'en');
                      Navigator.of(context).pop();
                    }),
                const Divider(thickness: 0.5),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.cancel)),
            ],
          );
        });
  }
}

///抓包过滤菜单
class FilterMenu extends StatelessWidget {
  final ProxyServer proxyServer;

  const FilterMenu({super.key, required this.proxyServer});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: AppBar(title: Text(localizations.filter, style: const TextStyle(fontSize: 16)), centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.all(5),
            child: ListView(children: [
              ListTile(
                  title: Text(localizations.domainWhitelist),
                  trailing: const Icon(Icons.arrow_right),
                  onTap: () => navigator(context,
                      MobileFilterWidget(configuration: proxyServer.configuration, hostList: HostFilter.whitelist))),
              ListTile(
                  title: Text(localizations.domainBlacklist),
                  trailing: const Icon(Icons.arrow_right),
                  onTap: () => navigator(context,
                      MobileFilterWidget(configuration: proxyServer.configuration, hostList: HostFilter.blacklist))),
              Platform.isIOS
                  ? const SizedBox()
                  : ListTile(
                      title: Text(localizations.appWhitelist),
                      trailing: const Icon(Icons.arrow_right),
                      onTap: () => navigator(context, AppWhitelist(proxyServer: proxyServer))),
            ])));
  }
}

/// +号菜单
class MoreMenu extends StatelessWidget {
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> desktop;

  const MoreMenu({super.key, required this.proxyServer, required this.desktop});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return PopupMenuButton(
      tooltip: localizations.scanCode,
      offset: const Offset(0, 30),
      child: const SizedBox(height: 38, width: 38, child: Icon(Icons.add_circle_outline, size: 26)),
      itemBuilder: (BuildContext context) {
        return <PopupMenuItem>[
          PopupMenuItem(
              child: ListTile(
                  dense: true,
                  title: Text(localizations.httpsProxy),
                  leading: Icon(Icons.https, color: proxyServer.enableSsl ? null : Colors.red),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (BuildContext context) {
                        return MobileSslWidget(proxyServer: proxyServer);
                      }),
                    );
                  })),
          PopupMenuItem(
              child: ListTile(
            dense: true,
            leading: const Icon(Icons.qr_code_scanner_outlined),
            title: Text(localizations.connectRemote),
            onTap: () {
              connectRemote(context);
            },
          )),
          PopupMenuItem(
              child: ListTile(
            dense: true,
            leading: const Icon(Icons.phone_iphone),
            title: Text(localizations.myQRCode),
            onTap: () async {
              var ip = await localIp();
              if (context.mounted) {
                connectQrCode(context, ip, proxyServer.port);
              }
            },
          )),
          PopupMenuItem(
              child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.construction),
                  title: Text(localizations.toolbox),
                  onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (BuildContext context) {
                          return Scaffold(
                              appBar: AppBar(
                                  title: Text(localizations.toolbox, style: const TextStyle(fontSize: 16)),
                                  centerTitle: true),
                              body: Toolbox(proxyServer: proxyServer));
                        }),
                      ))),
        ];
      },
    );
  }

  ///扫码连接
  connectRemote(BuildContext context) async {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    String scanRes;
    if (Platform.isAndroid) {
      await EasyPermission.requestPermissions([PermissionType.CAMERA]);
      scanRes = await scanner.scan() ?? "-1";
    } else {
      scanRes = await FlutterBarcodeScanner.scanBarcode("#ff6666", localizations.cancel, true, ScanMode.QR);
    }
    if (scanRes == "-1") return;
    if (scanRes.startsWith("http")) {
      launchUrl(Uri.parse(scanRes), mode: LaunchMode.externalApplication);
      return;
    }

    if (scanRes.startsWith("proxypin://connect")) {
      Uri uri = Uri.parse(scanRes);
      var host = uri.queryParameters['host'];
      var port = uri.queryParameters['port'];

      try {
        var response = await HttpClients.get("http://$host:$port/ping").timeout(const Duration(seconds: 1));
        if (response.bodyAsString == "pong") {
          desktop.value = RemoteModel(
              connect: true,
              host: host,
              port: int.parse(port!),
              os: response.headers.get("os"),
              hostname: response.headers.get("hostname"));

          if (context.mounted && Navigator.canPop(context)) {
            FlutterToastr.show(
                "${localizations.connectSuccess}${Vpn.isVpnStarted ? '' : ', ${localizations.remoteConnectSuccessTips}'}",
                context,
                duration: 3);
            Navigator.pop(context);
          }
        }
      } catch (e) {
        print(e);
        if (context.mounted) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(content: Text(localizations.remoteConnectFail));
              });
        }
      }
      return;
    }
    if (context.mounted) {
      FlutterToastr.show(localizations.invalidQRCode, context);
    }
  }

  ///连接二维码
  connectQrCode(BuildContext context, String host, int port) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.only(top: 5),
            actionsPadding: const EdgeInsets.only(bottom: 5),
            title: Text(localizations.remoteConnectForward, style: const TextStyle(fontSize: 16)),
            content: SizedBox(
                height: 240,
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      backgroundColor: Colors.white,
                      data: "proxypin://connect?host=$host&port=${proxyServer.port}",
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 20),
                    Text(localizations.mobileScan),
                  ],
                )),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.cancel)),
            ],
          );
        });
  }
}
