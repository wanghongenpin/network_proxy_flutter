import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PhoneConnect extends StatefulWidget {
  final ProxyServer proxyServer;
  final List<String> hosts;

  const PhoneConnect({Key? key, required this.proxyServer, required this.hosts}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PhoneConnectState();
  }
}

class _PhoneConnectState extends State<PhoneConnect> {
  late String host;
  late int port;

  @override
  void initState() {
    super.initState();
    host = widget.hosts.first;
    port = widget.proxyServer.port;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Row(children: [
          const Text("手机连接", style: TextStyle(fontSize: 18)),
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
                  const Text("本机IP "),
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
                const Text("请使用手机版扫描二维码"),
              ],
            )));
  }
}
