import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/components/script_manager.dart';
import 'package:network_proxy/network/http_client.dart';

class RemoteModel {
  final bool connect;
  final String? host;
  final int? port;
  final String? os;
  final String? hostname;

  RemoteModel({
    required this.connect,
    this.host,
    this.port,
    this.os,
    this.hostname,
  });
}

class ConnectRemote extends StatefulWidget {
  final ProxyServer proxyServer;
  final ValueNotifier<RemoteModel> desktop;

  const ConnectRemote({super.key, required this.desktop, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return ConnectRemoteState();
  }
}

class ConnectRemoteState extends State<ConnectRemote> {
  bool syncConfig = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(localizations.connectedRemote, style: const TextStyle(fontSize: 16))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${localizations.connected}：${widget.desktop.value.hostname}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            OutlinedButton(
                child: Text(localizations.disconnect),
                onPressed: () {
                  widget.desktop.value = RemoteModel(connect: false);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 10),
            OutlinedButton(
              child: Text(localizations.syncConfig),
              onPressed: () {
                pullConfig();
              },
            ),
          ],
        ),
      ),
    );
  }

  //拉取桌面配置
  pullConfig() {
    var desktopModel = widget.desktop.value;
    HttpClients.get('http://${desktopModel.host}:${desktopModel.port}/config').then((response) {
      if (response.status.isSuccessful()) {
        var config = jsonDecode(response.bodyAsString);
        syncConfig = true;
        showDialog(
            context: context,
            builder: (context) {
              return ConfigSyncWidget(configuration: widget.proxyServer.configuration, config: config);
            });
      }
    }).onError((error, stackTrace) {
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.pullConfigFail)));
    });
  }
}

class ConfigSyncWidget extends StatefulWidget {
  final Configuration configuration;
  final Map<String, dynamic> config;

  const ConfigSyncWidget({super.key, required this.configuration, required this.config});

  @override
  State<StatefulWidget> createState() {
    return ConfigSyncState();
  }
}

class ConfigSyncState extends State<ConfigSyncWidget> {
  bool syncWhiteList = true;
  bool syncBlackList = true;
  bool syncRewrite = true;
  bool syncScript = true;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(localizations.syncConfig, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
          height: 260,
          child: Column(
            children: [
              SwitchListTile(
                  dense: true,
                  subtitle: Text("${localizations.sync}${localizations.domainWhitelist}"),
                  value: syncWhiteList,
                  onChanged: (val) {
                    setState(() {
                      syncWhiteList = val;
                    });
                  }),
              SwitchListTile(
                  dense: true,
                  subtitle: Text("${localizations.sync}${localizations.domainBlacklist}"),
                  value: syncBlackList,
                  onChanged: (val) {
                    setState(() {
                      syncBlackList = val;
                    });
                  }),
              SwitchListTile(
                  dense: true,
                  subtitle: Text("${localizations.sync}${localizations.requestRewrite}"),
                  value: syncRewrite,
                  onChanged: (val) {
                    setState(() {
                      syncRewrite = val;
                    });
                  }),
              SwitchListTile(
                  dense: true,
                  subtitle: Text("${localizations.sync}${localizations.script}"),
                  value: syncScript,
                  onChanged: (val) {
                    setState(() {
                      syncScript = val;
                    });
                  }),
            ],
          )),
      actions: [
        TextButton(
            child: Text(localizations.cancel),
            onPressed: () {
              Navigator.pop(context);
            }),
        TextButton(
            child: Text('${localizations.start}${localizations.sync}'),
            onPressed: () async {
              if (syncWhiteList) {
                HostFilter.whitelist.load(widget.config['whitelist']);
              }
              if (syncBlackList) {
                HostFilter.blacklist.load(widget.config['blacklist']);
              }
              widget.configuration.flushConfig();

              if (syncRewrite) {
                var requestRewrites = await RequestRewrites.instance;
                await requestRewrites.syncConfig(widget.config['requestRewrites']);
              }

              if (syncScript) {
                var scriptManager = await ScriptManager.instance;
                await scriptManager.clean();
                scriptManager.list.clear();
                for (var item in widget.config['scripts']) {
                  await scriptManager.addScript(ScriptItem.fromJson(item), item['script']);
                }
                await scriptManager.flushConfig();
              }

              if (mounted) {
                Navigator.pop(this.context);
                ScaffoldMessenger.of(this.context)
                    .showSnackBar(SnackBar(content: Text('${localizations.sync}${localizations.success}')));
              }
            }),
      ],
    );
  }
}
