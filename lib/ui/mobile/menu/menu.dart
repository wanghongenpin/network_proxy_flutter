import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:easy_permission/easy_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/ui/mobile/setting/ssl.dart';
import 'package:network_proxy/ui/mobile/widgets/connect_remote.dart';
import 'package:network_proxy/ui/mobile/widgets/highlight.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:url_launcher/url_launcher.dart';

/// +号菜单
class MoreMenu extends StatelessWidget {
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> desktop;

  const MoreMenu({super.key, required this.proxyServer, required this.desktop});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return PopupMenuButton(
      offset: const Offset(0, 30),
      child: const SizedBox(height: 38, width: 38, child: Icon(Icons.more_vert, size: 26)),
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry>[
          PopupMenuItem(
              height: 32,
              child: ListTile(
                  dense: true,
                  title: Text(localizations.httpsProxy),
                  leading: Icon(Icons.https_outlined, color: proxyServer.enableSsl ? null : Colors.red),
                  onTap: () {
                    navigator(context, MobileSslWidget(proxyServer: proxyServer));
                  })),
          PopupMenuItem(
              height: 32,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.qr_code_scanner_outlined),
                title: Text(localizations.connectRemote),
                onTap: () {
                  Navigator.maybePop(context);
                  connectRemote(context);
                },
              )),
          PopupMenuItem(
              height: 32,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.phone_iphone_outlined),
                title: Text(localizations.myQRCode),
                onTap: () async {
                  Navigator.maybePop(context);
                  var ip = await localIp();
                  if (context.mounted) {
                    connectQrCode(context, ip, proxyServer.port);
                  }
                },
              )),
          const PopupMenuDivider(height: 0),
          PopupMenuItem(
              height: 32,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.highlight_outlined),
                title: Text(localizations.highlight),
                onTap: () {
                  navigator(context, const KeywordHighlight());
                },
              )),
          PopupMenuItem(
              height: 32,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.share_outlined),
                title: Text(localizations.viewExport),
                onTap: () async {
                  Navigator.maybePop(context);
                  var name = formatDate(DateTime.now(), [m, '-', d, ' ', HH, ':', nn, ':', ss]);
                  MobileHomeState.requestStateKey.currentState?.export('ProxyPin$name');
                },
              )),
        ];
      },
    );
  }

  void navigator(BuildContext context, Widget widget) async {
    await Navigator.maybePop(context);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (BuildContext context) => widget),
      );
    }
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
