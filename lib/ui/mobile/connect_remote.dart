import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/components/script_manager.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('已连接远程', style: TextStyle(fontSize: 16))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('已连接：${widget.desktop.value.hostname}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            OutlinedButton(
                child: const Text('断开连接'),
                onPressed: () {
                  widget.desktop.value = RemoteModel(connect: false);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 10),
            OutlinedButton(
              child: const Text('同步配置'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取配置失败, 请检查网络连接')));
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('同步配置', style: TextStyle(fontSize: 16)),
      content: SizedBox(
          height: 260,
          child: Column(
            children: [
              SwitchListTile(
                  dense: true,
                  subtitle: const Text("同步白名单过滤"),
                  value: syncWhiteList,
                  onChanged: (val) {
                    setState(() {
                      syncWhiteList = val;
                    });
                  }),
              SwitchListTile(
                  dense: true,
                  subtitle: const Text("同步黑名单过滤"),
                  value: syncBlackList,
                  onChanged: (val) {
                    setState(() {
                      syncBlackList = val;
                    });
                  }),
              SwitchListTile(
                  dense: true,
                  subtitle: const Text("同步请求重写"),
                  value: syncRewrite,
                  onChanged: (val) {
                    setState(() {
                      syncRewrite = val;
                    });
                  }),
              SwitchListTile(
                  dense: true,
                  subtitle: const Text("同步脚本"),
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
            child: const Text('取消'),
            onPressed: () {
              Navigator.pop(context);
            }),
        TextButton(
            child: const Text('开始同步'),
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('同步成功')));
              }
            }),
      ],
    );
  }
}
