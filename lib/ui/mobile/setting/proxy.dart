import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(localizations.proxySetting, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
      body: ListView(children: [
        PortWidget(proxyServer: widget.proxyServer),
        const Divider(height: 20, thickness: 0.3),
        ListTile(
          title: Text(localizations.externalProxy),
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

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
        title: Text(localizations.externalProxy, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.cancel)),
          TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                submit();
              },
              child: Text(localizations.confirm))
        ],
        content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 2, child: Text("${localizations.enable}：")),
                Expanded(
                    child: Switch(
                  value: externalProxy.enabled,
                  onChanged: (val) {
                    setState(() => externalProxy.enabled = val);
                  },
                ))
              ]),
              Row(children: [
                Expanded(flex: 2, child: Text(localizations.mobileDisplayPacketCapture)),
                Expanded(
                    child: Switch(
                  value: externalProxy.capturePacket,
                  onChanged: (val) {
                    setState(() => externalProxy.capturePacket = val);
                  },
                ))
              ]),
              Row(children: [
                const Text("Host："),
                Expanded(
                    child: TextFormField(
                  initialValue: externalProxy.host,
                  validator: (val) => val == null || val.isEmpty ? localizations.cannotBeEmpty : null,
                  onChanged: (val) => externalProxy.host = val,
                ))
              ]),
              Row(children: [
                const Text("Port："),
                Expanded(
                    child: TextFormField(
                  initialValue: externalProxy.port?.toString() ?? '',
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(5),
                    FilteringTextInputFormatter.allow(RegExp("[0-9]"))
                  ],
                  onChanged: (val) => externalProxy.port = int.parse(val),
                  validator: (val) => val == null || val.isEmpty ? localizations.cannotBeEmpty : null,
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
        if (mounted) {
          await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: Text(localizations.externalProxyConnectFailure),
                    content: Text(localizations.externalProxyFailureConfirm, style: const TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.cancel)),
                      TextButton(
                          onPressed: () {
                            setting = true;
                            Navigator.of(context).pop();
                          },
                          child: Text(localizations.confirm))
                    ],
                  ));
        }
      }
    }

    if (setting) {
      widget.configuration.externalProxy = externalProxy;
      widget.configuration.flushConfig();
    }

    if (mounted) Navigator.of(context).pop();
  }
}
