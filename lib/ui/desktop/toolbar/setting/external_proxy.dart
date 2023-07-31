import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/configuration.dart';

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
    externalProxy = widget.configuration.externalProxy ?? ProxyInfo();
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
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                widget.configuration.externalProxy = externalProxy;
                widget.configuration.flushConfig();
                if (externalProxy.enable) {

                }
                Navigator.of(context).pop();
              },
              child: const Text("确定"))
        ],
        content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text("是否启用："),
                Expanded(
                    child: Switch(
                  value: externalProxy.enable,
                  onChanged: (val) {
                    setState(() => externalProxy.enable = val);
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
}
