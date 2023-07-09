import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/theme.dart';
import 'package:network_proxy/ui/mobile/connect_remote.dart';
import 'package:network_proxy/ui/mobile/setting/filter.dart';
import 'package:network_proxy/ui/mobile/setting/request_rewrite.dart';
import 'package:network_proxy/ui/mobile/setting/ssl.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:url_launcher/url_launcher.dart';

class DrawerWidget extends StatelessWidget {
  final ProxyServer proxyServer;

  const DrawerWidget({Key? key, required this.proxyServer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
          child: const Text('设置'),
        ),
        PortWidget(proxyServer: proxyServer),
        ListTile(
            title: const Text("HTTPS抓包"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () => navigator(context, MobileSslWidget(proxyServer: proxyServer))),
        const ThemeSetting(),
        ListTile(
            title: const Text("域名白名单"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () =>
                navigator(context, MobileFilterWidget(proxyServer: proxyServer, hostList: HostFilter.whitelist))),
        ListTile(
            title: const Text("域名黑名单"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () =>
                navigator(context, MobileFilterWidget(proxyServer: proxyServer, hostList: HostFilter.blacklist))),
        ListTile(
            title: const Text("请求重写"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () => navigator(context, MobileRequestRewrite(proxyServer: proxyServer))),
        ListTile(
            title: const Text("Github"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              launchUrl(Uri.parse("https://github.com/wanghongenpin/network_proxy_flutter"),
                  mode: LaunchMode.externalApplication);
            }),
        ListTile(
            title: const Text("下载地址"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              launchUrl(Uri.parse("https://gitee.com/wanghongenpin/network-proxy-flutter/releases/tag/0.0.1"),
                  mode: LaunchMode.externalApplication);
            })
      ],
    ));
  }

  navigator(BuildContext context, Widget widget) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (BuildContext context) {
        return widget;
      }),
    );
  }
}

/// +号菜单
class MoreEnum extends StatelessWidget {
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> desktop;

  const MoreEnum({super.key, required this.proxyServer, required this.desktop});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      offset: const Offset(0, 30),
      child: const Icon(Icons.add_circle_outline, size: 26),
      itemBuilder: (BuildContext context) {
        return <PopupMenuItem>[
          PopupMenuItem(
              padding: const EdgeInsets.only(left: 0),
              child: ListTile(
                  dense: true,
                  title: const Text("HTTPS抓包"),
                  leading: Icon(Icons.https, color: proxyServer.enableSsl ? null : Colors.red),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (BuildContext context) {
                        return MobileSslWidget(proxyServer: proxyServer);
                      }),
                    );
                  })),
          PopupMenuItem(
              padding: const EdgeInsets.only(left: 0),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.qr_code_scanner_outlined),
                title: const Text("连接终端"),
                onTap: () {
                  connectRemote(context);
                },
              )),
          PopupMenuItem(
              padding: const EdgeInsets.only(left: 0),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.phone_iphone),
                title: const Text("我的二维码"),
                onTap: () async {
                  var ip = await localIp();
                  if (context.mounted) {
                    phoneConnect(context, ip, proxyServer.port);
                  }
                },
              )),
        ];
      },
    );
  }

  connectRemote(BuildContext context) async {
    String scanRes;
    if (Platform.isAndroid) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      scanRes = await scanner.scan() ?? "-1";
    } else {
      scanRes = await FlutterBarcodeScanner.scanBarcode("#ff6666", "取消", true, ScanMode.QR);
    }

    print(scanRes);
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
            showSnackBar(context, "连接成功");
            Navigator.pop(context);
          }
        }
      } catch (e) {
        print(e);
        if (context.mounted) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return const AlertDialog(content: Text("连接失败，请检查是否在同一局域网"));
              });
        }
      }
      return;
    }
    if (context.mounted) {
      showSnackBar(context, "无法识别的二维码");
    }
  }

  showSnackBar(BuildContext context, String text) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  phoneConnect(BuildContext context, String host, int port) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.only(top: 5),
            actionsPadding: const EdgeInsets.only(bottom: 5),
            title: const Text("远程连接，将请求转发到其他终端", style: TextStyle(fontSize: 16)),
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
                    const Text("请使用手机扫描二维码"),
                  ],
                )),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("取消")),
            ],
          );
        });
  }
}
