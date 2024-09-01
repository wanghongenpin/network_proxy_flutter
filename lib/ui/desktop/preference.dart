/*
 * Copyright 2023 WangHongEn
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
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
                  child: Row(
                    children: [
                      Text("Material3: ", style: titleMedium),
                      Expanded(
                          child: Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: appConfiguration.useMaterial3,
                                onChanged: (bool value) => appConfiguration.useMaterial3 = value,
                              )))
                    ],
                  )),
              //主题颜色
              Row(children: [
                SizedBox(
                    width: 120,
                    child: Text("${localizations.themeColor}: ", style: titleMedium, textAlign: TextAlign.start)),
              ]),
              themeColor(context),
              const Divider(),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizations.autoStartup),
                  //默认是否启动
                  subtitle: Text(localizations.autoStartupDescribe, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      scale: 0.8,
                      value: configuration.startup,
                      onChanged: (value) {
                        configuration.startup = value;
                        configuration.flushConfig();
                      })),
              const Divider(),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizations.autoStartup), //默认是否启动
                  subtitle: Text(localizations.autoStartupDescribe, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      scale: 0.8,
                      value: configuration.startup,
                      onChanged: (value) {
                        configuration.startup = value;
                        configuration.flushConfig();
                      })),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizations.headerExpanded),
                  subtitle: Text(localizations.headerExpandedSubtitle, style: const TextStyle(fontSize: 12)),
                  trailing: SwitchWidget(
                      scale: 0.8,
                      value: appConfiguration.headerExpanded,
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
}
