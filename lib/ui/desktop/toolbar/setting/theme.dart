import 'package:flutter/material.dart';
import 'package:network_proxy/main.dart';

class ThemeSetting extends StatelessWidget {
  const ThemeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    var surfaceTintColor =
        Brightness.dark == Theme.of(context).brightness ? null : Theme.of(context).colorScheme.background;

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
                  value: themeNotifier.value.useMaterial3,
                  onChanged: (bool value) {
                    themeNotifier.value = themeNotifier.value.copy(useMaterial3: value);
                  },
                  dense: true,
                  title: const Text("Material3"),
                ))),
        MenuItemButton(
            leadingIcon: themeNotifier.value.mode == ThemeMode.system
                ? const Icon(Icons.check, size: 15)
                : const SizedBox(width: 18),
            trailingIcon: const Icon(Icons.cached),
            child: const Text("跟随系统"),
            onPressed: () {
              themeNotifier.value = themeNotifier.value.copy(mode: ThemeMode.system);
            }),
        MenuItemButton(
            leadingIcon: themeNotifier.value.mode == ThemeMode.dark
                ? const Icon(Icons.check, size: 15)
                : const SizedBox(width: 15),
            trailingIcon: const Icon(Icons.nightlight_outlined),
            child: const Text("深色"),
            onPressed: () {
              themeNotifier.value = themeNotifier.value.copy(mode: ThemeMode.dark);
            }),
        MenuItemButton(
            leadingIcon: themeNotifier.value.mode == ThemeMode.light
                ? const Icon(Icons.check, size: 15)
                : const SizedBox(width: 15),
            trailingIcon: const Icon(Icons.sunny),
            child: const Text("浅色"),
            onPressed: () {
              themeNotifier.value = themeNotifier.value.copy(mode: ThemeMode.light);
            }),
      ],
      child: const Padding(padding: EdgeInsets.only(left: 10), child: Text("主题",style: TextStyle(fontSize: 14))),
    );
  }
}
