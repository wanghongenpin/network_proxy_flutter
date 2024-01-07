import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/configuration.dart';

//应用白名单 目前只支持安卓 ios没办法获取安装的列表
class AppWhitelist extends StatefulWidget {
  final ProxyServer proxyServer;

  const AppWhitelist({super.key, required this.proxyServer});

  @override
  State<AppWhitelist> createState() => _AppWhitelistState();
}

class _AppWhitelistState extends State<AppWhitelist> {
  late Configuration configuration;

  bool changed = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;
  }

  @override
  void dispose() {
    if (changed && widget.proxyServer.isRunning) {
      Vpn.restartVpn("127.0.0.1", widget.proxyServer.port,
          appList: configuration.appWhitelist,
          backgroundAudioEnable: AppConfiguration.current?.iosVpnBackgroundAudioEnable);
      configuration.flushConfig();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    var appWhitelist = <Future<AppInfo>>[];
    for (var element in configuration.appWhitelist) {
      appWhitelist.add(InstalledApps.getAppInfo(element).catchError((e) {
        return AppInfo.create({"name": isCN ? "未知应用" : "Unknown app", "package_name": element});
      }));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appWhitelist, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              //添加
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => const InstalledAppsWidget()))
                  .then((value) {
                if (value != null) {
                  if (configuration.appWhitelist.contains(value)) {
                    return;
                  }
                  setState(() {
                    configuration.appWhitelist.add(value);
                    changed = true;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: FutureBuilder(
          future: Future.wait(appWhitelist),
          builder: (BuildContext context, AsyncSnapshot<List<AppInfo>> snapshot) {
            print(snapshot.data);
            if (snapshot.hasData) {
              if (snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                      isCN
                          ? "未设置白名单应用时会对所有应用抓包"
                          : "When no whitelist application is set, all applications will be captured",
                      style: const TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (BuildContext context, int index) {
                    AppInfo appInfo = snapshot.data![index];
                    return ListTile(
                      leading: appInfo.icon == null ? const Icon(Icons.question_mark) : Image.memory(appInfo.icon!),
                      title: Text(appInfo.name ?? ""),
                      subtitle: Text(appInfo.packageName ?? ""),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          //删除
                          setState(() {
                            configuration.appWhitelist.remove(appInfo.packageName);
                            changed = true;
                          });
                        },
                      ),
                    );
                  });
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          }),
    );
  }
}

///已安装的app列表
class InstalledAppsWidget extends StatefulWidget {
  const InstalledAppsWidget({super.key});

  @override
  State<InstalledAppsWidget> createState() => _InstalledAppsWidgetState();
}

class _InstalledAppsWidgetState extends State<InstalledAppsWidget> {
  static Future<List<AppInfo>> apps = InstalledApps.getInstalledApps(true, true);

  String? keyword;

  @override
  Widget build(BuildContext context) {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: isCN ? "请输入应用名或包名" : "Please enter the application or package name",
            border: InputBorder.none,
          ),
          onChanged: (String value) {
            keyword = value;
            setState(() {});
          },
        ),
      ),
      body: FutureBuilder(
        future: apps,
        builder: (BuildContext context, AsyncSnapshot<List<AppInfo>> snapshot) {
          if (snapshot.hasData) {
            List<AppInfo> appInfoList = snapshot.data!;
            if (keyword != null && keyword!.isNotEmpty) {
              appInfoList = appInfoList
                  .where((element) => element.name!.contains(keyword!) || element.packageName!.contains(keyword!))
                  .toList();
            }

            return ListView.builder(
                itemCount: appInfoList.length,
                itemBuilder: (BuildContext context, int index) {
                  AppInfo appInfo = appInfoList[index];
                  return ListTile(
                    leading: Image.memory(appInfo.icon ?? Uint8List(0)),
                    title: Text(appInfo.name ?? ""),
                    subtitle: Text(appInfo.packageName ?? ""),
                    onTap: () async {
                      Navigator.of(context).pop(appInfo.packageName);
                    },
                  );
                });
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
