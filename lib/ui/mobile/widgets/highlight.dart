import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/ui/component/widgets.dart';

class KeywordHighlight extends StatefulWidget {
  static Map<Color, String> keywords = {};
  static bool enabled = true;
  static ValueNotifier keywordsController = ValueNotifier<Map>(keywords);

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
  State<KeywordHighlight> createState() => _KeywordHighlightState();
}

class _KeywordHighlightState extends State<KeywordHighlight> {
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
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
          SwitchWidget(scale: 0.7, value: KeywordHighlight.enabled, onChanged: (val) => KeywordHighlight.enabled = val),
          const SizedBox(width: 10)
        ],
      ),
      body: DefaultTabController(
        length: colors.length,
        child: Scaffold(
          appBar: TabBar(tabs: colors.entries.map((e) => Tab(text: e.value)).toList()),
          body: TabBarView(
              children: colors.entries
                  .map((e) => KeepAliveWrapper(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                          child: TextFormField(
                            minLines: 2,
                            maxLines: 2,
                            initialValue: KeywordHighlight.keywords[e.key],
                            onChanged: (value) {
                              if (value.isEmpty) {
                                KeywordHighlight.keywords.remove(e.key);
                              } else {
                                KeywordHighlight.keywords[e.key] = value;
                              }
                            },
                            decoration: decoration(localizations.keyword),
                          ))))
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

  @override
  void dispose() {
    if (KeywordHighlight.enabled) {
      KeywordHighlight.keywordsController.value = Map.from(KeywordHighlight.keywords);
    } else {
      KeywordHighlight.keywordsController.value = {};
    }
    super.dispose();
  }
}
