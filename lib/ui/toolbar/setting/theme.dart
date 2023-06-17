import 'package:flutter/material.dart';
import 'package:network/main.dart';

class ThemeSetting extends StatelessWidget {
  const ThemeSetting({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
        surfaceTintColor: Colors.white70,
        offset: const Offset(150, 0),
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.cached), title: Text("跟随系统")),
                onTap: () {
                  themeNotifier.value = ThemeMode.system;
                }),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.nightlight_outlined), title: Text("深色")),
                onTap: () {
                  themeNotifier.value = ThemeMode.dark;
                }),
            PopupMenuItem(
                child: const ListTile(trailing: Icon(Icons.sunny), title: Text("浅色")),
                onTap: () {
                  themeNotifier.value = ThemeMode.light;
                }),
          ];
        },
        child: const ListTile(title: Text("主题"), trailing: Icon(Icons.arrow_right)));
  }
}
