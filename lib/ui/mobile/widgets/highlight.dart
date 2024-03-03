import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/ui/component/widgets.dart';

class KeywordHighlight extends StatelessWidget {
  static Map<Color, String> keywords = {};
  static bool enabled = true;

  static Color? getHighlightColor(String? key) {
    if (key == null || !enabled) {
      return null;
    }
    for (var entry in keywords.entries) {
      if (key.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  const KeywordHighlight({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    var colors = {
      Colors.red: localizations.red,
      Colors.yellow.shade600: localizations.yellow,
      Colors.blue: localizations.blue,
      Colors.green: localizations.green,
      Colors.grey: localizations.gray,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.keyword + localizations.highlight,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        actions: [
          SwitchWidget(scale: 0.7, value: enabled, onChanged: (val) => enabled = val),
          const SizedBox(width: 10)
        ],
      ),
      body: DefaultTabController(
        length: colors.length,
        child: Scaffold(
          appBar: TabBar(tabs: colors.entries.map((e) => Tab(text: e.value)).toList()),
          body: TabBarView(
              children: colors.entries
                  .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                      child: TextFormField(
                        minLines: 2,
                        maxLines: 2,
                        initialValue: keywords[e.key],
                        onChanged: (value) {
                          if (value.isEmpty) {
                            keywords.remove(e.key);
                          } else {
                            keywords[e.key] = value;
                          }
                        },
                        decoration: decoration(localizations.keyword),
                      )))
                  .toList()),
        ),
      ),
    );
  }

  InputDecoration decoration(String label, {String? hintText}) {
    return InputDecoration(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }
}
