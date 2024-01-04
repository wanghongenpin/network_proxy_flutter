import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// @author wanghongen
/// 2023/10/8
class FilterDialog extends StatefulWidget {
  final Configuration configuration;

  const FilterDialog({super.key, required this.configuration});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final ValueNotifier<bool> hostEnableNotifier = ValueNotifier(false);

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void dispose() {
    hostEnableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        titlePadding: const EdgeInsets.only(left: 20, top: 10, right: 15),
        contentPadding: const EdgeInsets.only(left: 20, right: 20),
        scrollable: true,
        title: Row(children: [
          Text(localizations.domainFilter, style: const TextStyle(fontSize: 18)),
          const Expanded(child: Align(alignment: Alignment.topRight, child: CloseButton()))
        ]),
        content: SizedBox(
          width: 680,
          height: 460,
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                  flex: 1,
                  child: DomainFilter(
                      title: localizations.domainWhitelist,
                      subtitle: localizations.domainWhitelistDescribe,
                      hostList: HostFilter.whitelist,
                      configuration: widget.configuration,
                      hostEnableNotifier: hostEnableNotifier)),
              const SizedBox(width: 10),
              Expanded(
                  flex: 1,
                  child: DomainFilter(
                      title: localizations.domainBlacklist,
                      subtitle: localizations.domainBlacklistDescribe,
                      hostList: HostFilter.blacklist,
                      configuration: widget.configuration,
                      hostEnableNotifier: hostEnableNotifier)),
            ],
          ),
        ));
  }
}

class DomainFilter extends StatefulWidget {
  final String title;
  final String subtitle;
  final HostList hostList;
  final Configuration configuration;
  final ValueNotifier<bool> hostEnableNotifier;

  const DomainFilter(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.hostList,
      required this.hostEnableNotifier,
      required this.configuration});

  @override
  State<StatefulWidget> createState() {
    return _DomainFilterState();
  }
}

class _DomainFilterState extends State<DomainFilter> {
  late DomainList domainList;
  bool changed = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    domainList = DomainList(widget.hostList);

    return Column(
      children: [
        ListTile(
          title: Text(widget.title),
          subtitle: Text(widget.subtitle, style: const TextStyle(fontSize: 12)),
          titleAlignment: ListTileTitleAlignment.center,
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder(
            valueListenable: widget.hostEnableNotifier,
            builder: (_, bool enable, __) {
              return SwitchListTile(
                  title: Text(localizations.enable),
                  dense: true,
                  value: widget.hostList.enabled,
                  onChanged: (value) {
                    widget.hostList.enabled = value;
                    changed = true;
                    widget.hostEnableNotifier.value = !widget.hostEnableNotifier.value;
                  });
            }),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FilledButton.icon(
              icon: const Icon(Icons.add, size: 14),
              onPressed: () {
                add();
              },
              label: Text(localizations.add, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          TextButton.icon(
              icon: const Icon(Icons.remove, size: 14),
              label: Text(localizations.delete, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                if (domainList.selected().isEmpty) {
                  return;
                }
                changed = true;
                setState(() {
                  widget.hostList.removeIndex(domainList.selected());
                });
              })
        ]),
        domainList
      ],
    );
  }

  @override
  void dispose() {
    if (changed) {
      widget.configuration.flushConfig();
    }
    super.dispose();
  }

  void add() {
    GlobalKey formKey = GlobalKey<FormState>();
    String? host;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
              scrollable: true,
              content: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Form(
                      key: formKey,
                      child: Column(children: <Widget>[
                        TextFormField(
                            decoration: const InputDecoration(labelText: 'Host', hintText: '*.example.com'),
                            onSaved: (val) => host = val)
                      ]))),
              actions: [
                FilledButton(
                    child: Text(localizations.add),
                    onPressed: () {
                      (formKey.currentState as FormState).save();
                      if (host != null && host!.isNotEmpty) {
                        try {
                          changed = true;
                          widget.hostList.add(host!.trim());
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                      Navigator.of(context).pop();
                    }),
                ElevatedButton(
                    child:  Text(localizations.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    })
              ]);
        });
  }
}

///域名列表
class DomainList extends StatefulWidget {
  final HostList hostList;

  DomainList(this.hostList) : super(key: GlobalKey<_DomainListState>());

  @override
  State<StatefulWidget> createState() => _DomainListState();

  List<int> selected() {
    var state = (key as GlobalKey<_DomainListState>).currentState;
    List<int> list = [];
    state?.selected.forEach((key, value) {
      if (value == true) {
        list.add(key);
      }
    });
    return list;
  }
}

class _DomainListState extends State<DomainList> {
  late Map<int, bool> selected = {};
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        height: 300,
        child: SingleChildScrollView(
            child: DataTable(
          border: TableBorder.symmetric(outside: BorderSide(width: 1, color: Theme.of(context).highlightColor)),
          columns:  <DataColumn>[
            DataColumn(label: Text(localizations.domain)),
          ],
          rows: List.generate(
              widget.hostList.list.length,
              (index) => DataRow(
                  cells: [DataCell(Text(widget.hostList.list[index].pattern.replaceAll(".*", "*")))],
                  selected: selected[index] == true,
                  onSelectChanged: (value) {
                    setState(() {
                      selected[index] = value!;
                    });
                  })),
        )));
  }
}
