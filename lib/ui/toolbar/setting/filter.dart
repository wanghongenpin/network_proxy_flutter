import 'package:flutter/material.dart';
import 'package:network/network/bin/server.dart';

import '../../../network/util/host_filter.dart';

class DomainFilter extends StatefulWidget {
  final String title;
  final String subtitle;
  final HostList hostList;
  final ProxyServer proxyServer;
  final ValueNotifier<bool> hostEnableNotifier;

  const DomainFilter(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.hostList,
      required this.hostEnableNotifier, required this.proxyServer});

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
                  title: const Text('是否启用'),
                  dense: true,
                  value: widget.hostList.enabled,
                  onChanged: (value) {
                    widget.hostList.enabled = value;
                    changed = true;
                    widget.hostEnableNotifier.value = !widget.hostEnableNotifier.value;
                  });
            }),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FilledButton.tonal(
              onPressed: () {
                add();
              },
              child: const Text("增加")),
          TextButton(
              child: const Text("删除"),
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
    super.dispose();
    if (changed) {
      widget.proxyServer.flushConfig();
    }
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
                ElevatedButton(
                    child: const Text("添加"),
                    onPressed: () {
                      (formKey.currentState as FormState).save();
                      if (host != null && host!.isNotEmpty) {
                        try {
                          changed = true;
                          widget.hostList.add(host!);
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
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
        height: 300,
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
