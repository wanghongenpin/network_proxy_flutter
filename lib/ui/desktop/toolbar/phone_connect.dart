import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// @author wanghongen
/// 2023/10/8
class PhoneConnect extends StatefulWidget {
  final ProxyServer proxyServer;
  final List<String> hosts;

  const PhoneConnect({super.key, required this.proxyServer, required this.hosts});

  @override
  State<StatefulWidget> createState() {
    return _PhoneConnectState();
  }
}

class _PhoneConnectState extends State<PhoneConnect> {
  late String host;
  late int port;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    host = widget.hosts.first;
    port = widget.proxyServer.port;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        title: Row(children: [
          Text(localizations.mobileConnect, style: const TextStyle(fontSize: 18)),
          const Expanded(child: Align(alignment: Alignment.topRight, child: CloseButton()))
        ]),
        contentPadding: const EdgeInsets.all(10),
        content: SizedBox(
            height: 300,
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  backgroundColor: Colors.white,
                  data: "proxypin://connect?host=$host&port=${widget.proxyServer.port}",
                  version: QrVersions.auto,
                  size: 200.0,
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(localizations.localIP),
                  DropdownButton(
                      value: host,
                      isDense: true,
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.only(right: 10),
                      items: widget.hosts
                          .map((it) => DropdownMenuItem(
                                value: it,
                                child: Text('$it:$port'),
                              ))
                          .toList(),
                      onChanged: (String? value) {
                        setState(() {
                          host = value!;
                        });
                      })
                ]),
                const SizedBox(height: 10),
                Text(localizations.mobileScan, style: const TextStyle(fontSize: 16)),
              ],
            )));
  }
}
