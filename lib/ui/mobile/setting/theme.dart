import 'package:flutter/material.dart';
import 'package:network_proxy/main.dart';

class MobileThemeSetting extends StatelessWidget {
  const MobileThemeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
        tooltip: themeNotifier.value.mode.name,
        surfaceTintColor: Theme.of(context).colorScheme.onPrimary,
        offset: const Offset(150, 0),
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
                child: Tooltip(
                    preferBelow: false,
                    message: "Material 3是谷歌开源设计系统的最新版本",
                    child: SwitchListTile(
                      value: themeNotifier.value.useMaterial3,
                      onChanged: (bool value) {
                        themeNotifier.value = themeNotifier.value.copy(useMaterial3: value);
                        Navigator.of(context).pop();
                      },
                      dense: true,
                      title: const Text("Material3"),
                    ))),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.cached), dense: true, title: Text("跟随系统")),
                onTap: () {
                  themeNotifier.value = themeNotifier.value.copy(mode: ThemeMode.system);
                }),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.sunny), dense: true, title: Text("浅色")),
                onTap: () {
                  themeNotifier.value = themeNotifier.value.copy(mode: ThemeMode.light);
                }),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.nightlight_outlined), dense: true, title: Text("深色")),
                onTap: () {
                  themeNotifier.value = themeNotifier.value.copy(mode: ThemeMode.dark);
                }),
          ];
        },
        child: ListTile(
          title: const Text("主题"),
          trailing: getIcon(),
        ));
  }

  Icon getIcon() {
    switch (themeNotifier.value.mode) {
      case ThemeMode.system:
        return const Icon(Icons.cached);
      case ThemeMode.dark:
        return const Icon(Icons.nightlight_outlined);
      case ThemeMode.light:
        return const Icon(Icons.sunny);
    }
  }
}
