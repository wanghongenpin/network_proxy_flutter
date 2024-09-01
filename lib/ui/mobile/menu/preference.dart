import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';
import 'package:network_proxy/ui/mobile/setting/proxy.dart';
import 'package:network_proxy/ui/mobile/setting/theme.dart';

///设置
///@author wanghongen
class SettingMenu extends StatelessWidget {
  final ProxyServer proxyServer;
  final AppConfiguration appConfiguration;

  const SettingMenu({super.key, required this.proxyServer, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    bool isEn = appConfiguration.language?.languageCode == 'en';

    return Scaffold(
        appBar: AppBar(title: Text(localizations.setting, style: const TextStyle(fontSize: 16)), centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.all(5),
            child: ListView(children: [
              PortWidget(
                  proxyServer: proxyServer,
                  title: '${localizations.proxy}${isEn ? ' ' : ''}${localizations.port}',
                  textStyle: const TextStyle(fontSize: 16)),
              ListTile(
                  title: Text(localizations.externalProxy),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (_) => ExternalProxyDialog(configuration: proxyServer.configuration));
                  }),
              ListTile(
                title: Text(localizations.language),
                trailing: const Icon(Icons.arrow_right),
                onTap: () => _language(context),
              ),
              MobileThemeSetting(appConfiguration: appConfiguration),
              ListTile(title: Text(localizations.themeColor)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: themeColor(context)),
              ListTile(
                  title: Text(localizations.autoStartup), //默认是否启动
                  subtitle: Text(localizations.autoStartupDescribe, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      value: proxyServer.configuration.startup,
                      scale: 0.8,
                      onChanged: (value) {
                        proxyServer.configuration.startup = value;
                        proxyServer.configuration.flushConfig();
                      })),
              ListTile(
                  title: Text(localizations.windowMode),
                  subtitle: Text(localizations.windowModeSubTitle, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      value: appConfiguration.pipEnabled.value,
                      scale: 0.8,
                      onChanged: (value) {
                        appConfiguration.pipEnabled.value = value;
                        appConfiguration.flushConfig();
                      })),
              if (Platform.isAndroid)
                ListTile(
                    title: Text(localizations.windowIcon),
                    subtitle: Text(localizations.windowIconDescribe, style: const TextStyle(fontSize: 12)),
                    trailing: SwitchWidget(
                        value: appConfiguration.pipIcon.value,
                        scale: 0.8,
                        onChanged: (value) {
                          appConfiguration.pipIcon.value = value;
                          appConfiguration.flushConfig();
                        })),
              ListTile(
                  title: Text(localizations.headerExpanded),
                  subtitle: Text(localizations.headerExpandedSubtitle, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      value: appConfiguration.headerExpanded,
                      scale: 0.8,
                      onChanged: (value) {
                        appConfiguration.headerExpanded = value;
                        appConfiguration.flushConfig();
                      }))
            ])));
  }

  Widget themeColor(BuildContext context) {
    return Wrap(
      children: ThemeModel.colors.entries.map((pair) {
        var dividerColor = Theme.of(context).focusColor;
        var background = appConfiguration.themeColor == pair.value ? dividerColor : Colors.transparent;

        return GestureDetector(
            onTap: () => appConfiguration.setThemeColor = pair.key,
            child: Tooltip(
              message: pair.key,
              child: Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: Colors.transparent, width: 8),
                ),
                child: Dot(color: pair.value, size: 15),
              ),
            ));
      }).toList(),
    );
  }

  //选择语言
  void _language(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.only(left: 5, top: 5),
            actionsPadding: const EdgeInsets.only(bottom: 5, right: 5),
            title: Text(localizations.language, style: const TextStyle(fontSize: 16)),
            content: Wrap(
              children: [
                TextButton(
                    onPressed: () {
                      appConfiguration.language = null;
                      Navigator.of(context).pop();
                    },
                    child: Text(localizations.followSystem)),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'zh');
                      Navigator.of(context).pop();
                    },
                    child: const Text("简体中文")),
                const Divider(thickness: 0.5, height: 0),
                TextButton(
                    child: const Text("English"),
                    onPressed: () {
                      appConfiguration.language = const Locale.fromSubtags(languageCode: 'en');
                      Navigator.of(context).pop();
                    }),
                const Divider(thickness: 0.5),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.cancel)),
            ],
          );
        });
  }
}
