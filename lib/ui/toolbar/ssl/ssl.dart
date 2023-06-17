import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SslWidget extends StatefulWidget {
  const SslWidget({super.key});

  @override
  State<SslWidget> createState() => _SslState();
}

class _SslState extends State<SslWidget> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: "ssl证书",
      icon: const Icon(Icons.https),
      surfaceTintColor: Colors.white70,
      offset: const Offset(10, 30),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            child: SwitchListTile(title: const Text("启用Https代理"), value: true, onChanged: (d) {}),
          ),
          PopupMenuItem(
              child: ListTile(
            title: const Text("ssl证书"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              _downloadCert();
            },
          )),
          const PopupMenuItem<String>(
            child: ListTile(title: Text("安装根证书到IOS"), trailing: Icon(Icons.arrow_right)),
          ),
          const PopupMenuItem<String>(
            child: ListTile(title: Text("安装根证书到Android"), trailing: Icon(Icons.arrow_right)),
          )
        ];
      },
    );
  }

  void _downloadCert() async {
    final String? path = await getSavePath(suggestedName: "ca_root.crt");
    if (path != null) {
      const String fileMimeType = 'application/x-x509-ca-cert';
      var body = await rootBundle.load('assets/certs/ca.crt');
      final XFile xFile = XFile.fromData(
        body.buffer.asUint8List(),
        mimeType: fileMimeType,
      );
      await xFile.saveTo(path);
    }
  }
}
