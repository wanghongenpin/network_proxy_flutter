import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/ui/configuration.dart';

class MobileThemeSetting extends StatelessWidget {
  final AppConfiguration appConfiguration;

  const MobileThemeSetting({super.key, required this.appConfiguration});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return PopupMenuButton(
        tooltip: appConfiguration.themeMode.name,
        surfaceTintColor: Theme.of(context).colorScheme.onPrimary,
        offset: const Offset(150, 0),
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem(
                child: Tooltip(
                    preferBelow: false,
                    message: localizations.material3,
                    child: SwitchListTile(
                      value: appConfiguration.useMaterial3,
                      onChanged: (bool value) {
                        appConfiguration.useMaterial3 = value;
                        Navigator.of(context).pop();
                      },
                      dense: true,
                      title: const Text("Material3"),
                    ))),
            PopupMenuItem(
                child:
                    ListTile(trailing: const Icon(Icons.cached), dense: true, title: Text(localizations.followSystem)),
                onTap: () => appConfiguration.themeMode = ThemeMode.system),
            PopupMenuItem(
                child: ListTile(trailing: const Icon(Icons.sunny), dense: true, title: Text(localizations.themeLight)),
                onTap: () => appConfiguration.themeMode = ThemeMode.light),
            PopupMenuItem(
                child: ListTile(
                    trailing: const Icon(Icons.nightlight_outlined), dense: true, title: Text(localizations.themeDark)),
                onTap: () => appConfiguration.themeMode = ThemeMode.dark),
          ];
        },
        child: ListTile(
          title: Text(localizations.theme),
          trailing: getIcon(),
        ));
  }

  Icon getIcon() {
    switch (appConfiguration.themeMode) {
      case ThemeMode.system:
        return const Icon(Icons.cached);
      case ThemeMode.dark:
        return const Icon(Icons.nightlight_outlined);
      case ThemeMode.light:
        return const Icon(Icons.sunny);
    }
  }
}
