import 'package:flutter/material.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ThemeSetting extends StatelessWidget {
  final AppConfiguration appConfiguration;

  const ThemeSetting({super.key, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    var surfaceTintColor =
        Brightness.dark == Theme.of(context).brightness ? null : Theme.of(context).colorScheme.background;

    AppLocalizations localizations = AppLocalizations.of(context)!;

    return SubmenuButton(
      menuStyle: MenuStyle(
        surfaceTintColor: MaterialStatePropertyAll(surfaceTintColor),
        padding: const MaterialStatePropertyAll(EdgeInsets.only(top: 10, bottom: 10)),
      ),
      menuChildren: [
        SizedBox(
            width: 180,
            height: 38,
            child: Tooltip(
                preferBelow: false,
                message: "Material 3是谷歌开源设计系统的最新版本",
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 5),
                  value: appConfiguration.useMaterial3,
                  onChanged: (bool value) => appConfiguration.useMaterial3 = value,
                  dense: true,
                  title: const Text("Material3"),
                ))),
        MenuItemButton(
            leadingIcon: appConfiguration.themeMode == ThemeMode.system
                ? const Icon(Icons.check, size: 15)
                : const SizedBox(width: 18),
            trailingIcon: const Icon(Icons.cached),
            child: Text(localizations.followSystem),
            onPressed: () => appConfiguration.themeMode = ThemeMode.system),
        MenuItemButton(
            leadingIcon: appConfiguration.themeMode == ThemeMode.dark
                ? const Icon(Icons.check, size: 15)
                : const SizedBox(width: 15),
            trailingIcon: const Icon(Icons.nightlight_outlined),
            child: Text(localizations.themeDark),
            onPressed: () => appConfiguration.themeMode = ThemeMode.dark),
        MenuItemButton(
            leadingIcon: appConfiguration.themeMode == ThemeMode.light
                ? const Icon(Icons.check, size: 15)
                : const SizedBox(width: 15),
            trailingIcon: const Icon(Icons.sunny),
            child: Text(localizations.themeLight),
            onPressed: () => appConfiguration.themeMode = ThemeMode.light),
      ],
      child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(localizations.theme, style: const TextStyle(fontSize: 14))),
    );
  }
}
