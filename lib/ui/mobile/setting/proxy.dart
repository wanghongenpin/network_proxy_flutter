import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';

class ProxySetting extends StatefulWidget {
  final ProxyServer proxyServer;

  const ProxySetting({super.key, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _ProxySettingState();
  }
}

class _ProxySettingState extends State<ProxySetting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('代理设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
      body: ListView(children: [
        PortWidget(proxyServer: widget.proxyServer),
        const Divider(height: 20, thickness: 0.3),
        ListTile(
          title: const Text('外部代理'),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () {
            showDialog(
                context: context, builder: (_) => ExternalProxyDialog(configuration: widget.proxyServer.configuration));
          },
        ),
      ]),
    );
  }
}

class ExternalProxyDialog extends StatefulWidget {
  final Configuration configuration;

  const ExternalProxyDialog({super.key, required this.configuration});

  @override
  State<StatefulWidget> createState() {
    return _ExternalProxyDialogState();
  }
}

class _ExternalProxyDialogState extends State<ExternalProxyDialog> {
  final formKey = GlobalKey<FormState>();
  late ProxyInfo externalProxy;

  @override
  void initState() {
    super.initState();
    externalProxy = ProxyInfo();
    if (widget.configuration.externalProxy != null) {
      externalProxy = ProxyInfo.fromJson(widget.configuration.externalProxy!.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        scrollable: true,
        title: const Text("外部代理设置", style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("取消")),
          TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                submit();
              },
              child: const Text("确定"))
        ],
        content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(flex: 2, child: Text("是否启用：")),
                Expanded(
                    child: Switch(
                  value: externalProxy.enabled,
                  onChanged: (val) {
                    setState(() => externalProxy.enabled = val);
                  },
                ))
              ]),
              Row(children: [
                const Expanded(flex: 2, child: Text("手机端是否展示抓包：")),
                Expanded(
                    child: Switch(
                  value: externalProxy.capturePacket,
                  onChanged: (val) {
                    setState(() => externalProxy.capturePacket = val);
                  },
                ))
              ]),
              Row(children: [
                const Text("地址："),
                Expanded(
                    child: TextFormField(
                  initialValue: externalProxy.host,
                  validator: (val) => val == null || val.isEmpty ? "地址不能为空" : null,
                  onChanged: (val) => externalProxy.host = val,
                ))
              ]),
              Row(children: [
                const Text("端口："),
                Expanded(
                    child: TextFormField(
                  initialValue: externalProxy.port?.toString() ?? '',
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(5),
                    FilteringTextInputFormatter.allow(RegExp("[0-9]"))
                  ],
                  onChanged: (val) => externalProxy.port = int.parse(val),
                  validator: (val) => val == null || val.isEmpty ? "端口不能为空" : null,
                  decoration: const InputDecoration(),
                ))
              ]),
            ])));
  }

  submit() async {
    bool setting = true;
    if (externalProxy.enabled) {
      try {
        var socket = await Socket.connect(externalProxy.host, externalProxy.port!, timeout: const Duration(seconds: 1));
        socket.destroy();
      } on SocketException catch (_) {
        setting = false;
        if (context.mounted) {
          await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: const Text("外部代理连接失败"),
                    content: const Text('网络不通所有接口将会访问失败，是否继续设置外部代理。', style: TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("取消")),
                      TextButton(
                          onPressed: () {
                            setting = true;
                            Navigator.of(context).pop();
                          },
                          child: const Text("确定"))
                    ],
                  ));
        }
      }
    }

    if (setting) {
      widget.configuration.externalProxy = externalProxy;
      widget.configuration.flushConfig();
    }

    if (context.mounted) Navigator.of(context).pop();
  }
}
