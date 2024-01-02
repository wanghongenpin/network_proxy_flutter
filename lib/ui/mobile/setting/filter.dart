import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/configuration.dart';

import '../../../network/components/host_filter.dart';

class MobileFilterWidget extends StatefulWidget {
  final Configuration configuration;
  final HostList hostList;

  const MobileFilterWidget({super.key, required this.configuration, required this.hostList});

  @override
  State<MobileFilterWidget> createState() => _MobileFilterState();
}

class _MobileFilterState extends State<MobileFilterWidget> {
  final ValueNotifier<bool> hostEnableNotifier = ValueNotifier(false);

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void dispose() {
    hostEnableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var title = widget.hostList.runtimeType == Whites ? localizations.domainWhitelist : localizations.domainBlacklist;
    var subtitle =
        widget.hostList.runtimeType == Whites ? localizations.domainWhitelistDescribe : localizations.domainBlacklist;

    return Scaffold(
        appBar: AppBar(title: Text(localizations.domainFilter, style: const TextStyle(fontSize: 16))),
        body: Container(
          padding: const EdgeInsets.all(10),
          child: DomainFilter(
              title: title,
              subtitle: subtitle,
              hostList: widget.hostList,
              configuration: widget.configuration,
              hostEnableNotifier: hostEnableNotifier),
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

    return ListView(
      children: [
        ListTile(title: Text(widget.title), subtitle: Text(widget.subtitle, style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 10),
        ValueListenableBuilder(
            valueListenable: widget.hostEnableNotifier,
            builder: (_, bool enable, __) {
              return SwitchListTile(
                  title: Text(localizations.enable),
                  value: widget.hostList.enabled,
                  onChanged: (value) {
                    widget.hostList.enabled = value;
                    changed = true;
                    widget.hostEnableNotifier.value = !widget.hostEnableNotifier.value;
                  });
            }),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FilledButton.icon(icon: const Icon(Icons.add), onPressed: add, label: Text(localizations.add)),
          const SizedBox(width: 10),
          TextButton.icon(
              icon: const Icon(Icons.remove),
              label: Text(localizations.delete),
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
                ElevatedButton(child: Text(localizations.close), onPressed: () => Navigator.of(context).pop())
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

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        child: SingleChildScrollView(
            child: DataTable(
          border: TableBorder.symmetric(outside: BorderSide(width: 1, color: Theme.of(context).highlightColor)),
          columns: const <DataColumn>[
            DataColumn(label: Text('域名')),
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
