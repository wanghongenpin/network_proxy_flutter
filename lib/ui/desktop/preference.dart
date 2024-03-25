import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/configuration.dart';

/// @author wanghongen
/// 2024/1/2
class Preference extends StatelessWidget {
  final Configuration configuration;
  final AppConfiguration appConfiguration;

  const Preference(this.appConfiguration, this.configuration, {super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    var titleMedium = Theme.of(context).textTheme.titleMedium;
    return AlertDialog(
        scrollable: true,
        title: Row(children: [
          const Icon(Icons.settings, size: 20),
          const SizedBox(width: 10),
          Text(localizations.preference, style: Theme.of(context).textTheme.titleMedium),
          const Expanded(child: Align(alignment: Alignment.topRight, child: CloseButton()))
        ]),
        content: SizedBox(
            width: 300,
            child: Column(children: [
              Row(children: [
                SizedBox(width: 100, child: Text("${localizations.language}: ", style: titleMedium)),
                DropdownButton<Locale>(
                    value: appConfiguration.language,
                    onChanged: (Locale? value) => appConfiguration.language = value,
                    focusColor: Colors.transparent,
                    items: [
                      DropdownMenuItem(value: null, child: Text(localizations.followSystem)),
                      const DropdownMenuItem(value: Locale.fromSubtags(languageCode: "zh"), child: Text("中文")),
                      const DropdownMenuItem(value: Locale.fromSubtags(languageCode: "en"), child: Text("English")),
                    ]),
              ]),
              //主题
              Row(children: [
                SizedBox(width: 100, child: Text("${localizations.theme}: ", style: titleMedium)),
                DropdownButton<ThemeMode>(
                    value: appConfiguration.themeMode,
                    onChanged: (ThemeMode? value) => appConfiguration.themeMode = value!,
                    focusColor: Colors.transparent,
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(localizations.followSystem)),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(localizations.themeLight)),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(localizations.themeDark)),
                    ]),
              ]),
              Tooltip(
                  message: localizations.material3,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.only(left: 0, right: 5),
                    value: appConfiguration.useMaterial3,
                    onChanged: (bool value) => appConfiguration.useMaterial3 = value,
                    title: const Text("Material3: "),
                  )),
              const Divider(),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizations.autoStartup), //默认是否启动
                  subtitle: Text(localizations.autoStartupDescribe, style: const TextStyle(fontSize: 14)),
                  trailing: SwitchWidget(
                      value: configuration.startup,
                      onChanged: (value) {
                        configuration.startup = value;
                        configuration.flushConfig();
                      })),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizations.headerExpanded),
                  subtitle: Text(localizations.headerExpandedSubtitle, style: const TextStyle(fontSize: 14)),
                  trailing: SwitchWidget(
                      value: appConfiguration.headerExpanded,
                      onChanged: (value) {
                        appConfiguration.headerExpanded = value;
                        appConfiguration.flushConfig();
                      }))
            ])));
  }
}
