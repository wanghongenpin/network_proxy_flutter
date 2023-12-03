import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    hostEnableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var title = widget.hostList.runtimeType == Whites ? "白名单" : "黑名单";
    var subtitle = widget.hostList.runtimeType == Whites ? "只代理白名单中的域名, 白名单启用黑名单将会失效" : "黑名单中的域名不会代理";
    return Scaffold(
        appBar: AppBar(title: const Text("域名过滤", style: TextStyle(fontSize: 16))),
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
                  title: const Text('是否启用'),
                  value: widget.hostList.enabled,
                  onChanged: (value) {
                    widget.hostList.enabled = value;
                    changed = true;
                    widget.hostEnableNotifier.value = !widget.hostEnableNotifier.value;
                  });
            }),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FilledButton.icon(
              icon: const Icon(Icons.add),
              onPressed: () {
                add();
              },
              label: const Text("增加")),
          const SizedBox(width: 10),
          TextButton.icon(
              icon: const Icon(Icons.remove),
              label: const Text("删除"),
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
                    child: const Text("添加"),
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
                    child: const Text("关闭"),
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
