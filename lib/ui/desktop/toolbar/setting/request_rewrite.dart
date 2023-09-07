import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';

class RequestRewrite extends StatefulWidget {
  final Configuration configuration;

  const RequestRewrite({super.key, required this.configuration});

  @override
  State<RequestRewrite> createState() => _RequestRewriteState();
}

class _RequestRewriteState extends State<RequestRewrite> {
  late RequestRuleList requestRuleList;
  late ValueNotifier<bool> enableNotifier;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    requestRuleList = RequestRuleList(widget.configuration.requestRewrites);
    enableNotifier = ValueNotifier(widget.configuration.requestRewrites.enabled == true);
  }

  @override
  void dispose() {
    if (changed || enableNotifier.value != widget.configuration.requestRewrites.enabled) {
      widget.configuration.requestRewrites.enabled = enableNotifier.value;
      widget.configuration.flushRequestRewriteConfig();
    }

    enableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 280,
            child: ValueListenableBuilder(
                valueListenable: enableNotifier,
                builder: (_, bool v, __) {
                  return SwitchListTile(
                      contentPadding: const EdgeInsets.only(left: 2),
                      title: const Text('是否启用请求重写'),
                      dense: true,
                      value: enableNotifier.value,
                      onChanged: (value) {
                        enableNotifier.value = value;
                      });
                })),
        const SizedBox(height: 10),
        Row(children: [
          FilledButton.icon(
              icon: const Icon(Icons.add),
              onPressed: () {
                add();
              },
              label: const Text("增加")),
          const SizedBox(width: 10),
          OutlinedButton.icon(
              onPressed: () {
                var selectedIndex = requestRuleList.currentSelectedIndex();
                add(selectedIndex);
              },
              icon: const Icon(Icons.edit),
              label: const Text("编辑")),
          TextButton.icon(
              icon: const Icon(Icons.remove),
              label: const Text("删除"),
              onPressed: () {
                var removeSelected = requestRuleList.removeSelected();
                if (removeSelected.isEmpty) {
                  return;
                }

                changed = true;
                setState(() {
                  widget.configuration.requestRewrites.removeIndex(removeSelected);
                  requestRuleList.changeState();
                });
              })
        ]),
        const SizedBox(height: 10),
        const Text("选择框只是用来操作编辑和删除，规则启用状态在编辑页切换", style: TextStyle(fontSize: 12)),
        requestRuleList,
      ],
    );
  }

  void add([int currentIndex = -1]) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return RuleAddDialog(
              currentIndex: currentIndex,
              rule: currentIndex >= 0 ? widget.configuration.requestRewrites.rules[currentIndex] : null);
        }).then((value) {
      if (value != null) {
        changed = true;
        requestRuleList.changeState();
      }
    });
  }
}

///请求重写规则添加对话框
class RuleAddDialog extends StatefulWidget {
  final int currentIndex;
  final RequestRewriteRule? rule;

  const RuleAddDialog({super.key, this.currentIndex = -1, this.rule});

  @override
  State<StatefulWidget> createState() {
    return _RuleAddDialogState();
  }
}

class _RuleAddDialogState extends State<RuleAddDialog> {
  late ValueNotifier<bool> enableNotifier;
  late RequestRewriteRule rule;

  @override
  void initState() {
    super.initState();
    rule = widget.rule ?? RequestRewriteRule(true, "", null);
    enableNotifier = ValueNotifier(rule.enabled == true);
  }

  @override
  void dispose() {
    enableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey formKey = GlobalKey<FormState>();

    return AlertDialog(
        title: const Text("添加请求重写规则", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        scrollable: true,
        content: Container(
            constraints: const BoxConstraints(minWidth: 320),
            child: Form(
                key: formKey,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ValueListenableBuilder(
                          valueListenable: enableNotifier,
                          builder: (_, bool enable, __) {
                            return SwitchListTile(
                                contentPadding: const EdgeInsets.only(left: 0),
                                title: const Text('是否启用', textAlign: TextAlign.start),
                                value: enable,
                                onChanged: (value) => enableNotifier.value = value);
                          }),
                      TextFormField(
                        decoration: const InputDecoration(labelText: '名称'),
                        initialValue: rule.name,
                        onSaved: (val) => rule.name = val,
                      ),
                      TextFormField(
                          decoration: const InputDecoration(labelText: '域名(可选)', hintText: 'baidu.com 不需要填写HTTP'),
                          initialValue: rule.domain,
                          onSaved: (val) => rule.domain = val?.trim()),
                      TextFormField(
                          decoration: const InputDecoration(labelText: 'Path', hintText: '/api/v1/*'),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Path不能为空';
                            }
                            return null;
                          },
                          initialValue: rule.path,
                          onSaved: (val) => rule.path = val!.trim()),
                      DropdownButtonFormField<RuleType>(
                          decoration: const InputDecoration(labelText: '行为'),
                          value: rule.type,
                          items: RuleType.values
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(fontSize: 14))))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              rule.type = val!;
                            });
                          }),
                      ...rewriteWidgets()
                    ]))),
        actions: [
          FilledButton(
              child: const Text("保存"),
              onPressed: () {
                if ((formKey.currentState as FormState).validate()) {
                  (formKey.currentState as FormState).save();

                  rule.updatePathReg();
                  if (widget.currentIndex >= 0) {
                    RequestRewrites.instance.rules[widget.currentIndex] = rule;
                  } else {
                    RequestRewrites.instance.addRule(rule);
                  }

                  enableNotifier.dispose();
                  Navigator.of(context).pop(rule);
                }
              }),
          ElevatedButton(
              child: const Text("关闭"),
              onPressed: () {
                Navigator.of(context).pop();
              })
        ]);
  }

  List<Widget> rewriteWidgets() {
    if (rule.type == RuleType.redirect) {
      return [
        TextFormField(
            decoration: const InputDecoration(labelText: '重定向到:', hintText: 'http://www.example.com/api'),
            initialValue: rule.redirectUrl,
            onSaved: (val) => rule.redirectUrl = val,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return '重定向URL不能为空';
              }
              return null;
            }),
      ];
    }

    return [
      TextFormField(
          initialValue: rule.queryParam,
          decoration: const InputDecoration(labelText: 'URL参数替换为:'),
          maxLines: 1,
          onSaved: (val) => rule.queryParam = val),
      TextFormField(
          initialValue: rule.requestBody,
          decoration: const InputDecoration(labelText: '请求体替换为:'),
          minLines: 1,
          maxLines: 5,
          onSaved: (val) => rule.requestBody = val),
      TextFormField(
          initialValue: rule.responseBody,
          minLines: 3,
          maxLines: 15,
          decoration: const InputDecoration(labelText: '响应体替换为:', hintText: '{"code":"200","data":{}}'),
          onSaved: (val) => rule.responseBody = val)
    ];
  }
}

class RequestRuleList extends StatefulWidget {
  final RequestRewrites requestRewrites;

  RequestRuleList(this.requestRewrites) : super(key: GlobalKey<_RequestRuleListState>());

  @override
  State<RequestRuleList> createState() => _RequestRuleListState();

  List<int> removeSelected() {
    var index = currentSelectedIndex();
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    state?.currentSelectedIndex = -1;
    return index >= 0 ? [index] : [];
  }

  int currentSelectedIndex() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    return state?.currentSelectedIndex ?? -1;
  }

  changeState() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    state?.changeState();
  }
}

class _RequestRuleListState extends State<RequestRuleList> {
  int currentSelectedIndex = -1;

  changeState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        constraints: const BoxConstraints(minWidth: 500, minHeight: 300),
        child: SingleChildScrollView(
            child: DataTable(
          columnSpacing: 36,
          dataRowMaxHeight: 100,
          border: TableBorder.symmetric(outside: BorderSide(width: 1, color: Theme.of(context).highlightColor)),
          columns: const <DataColumn>[
            DataColumn(label: Text('名称')),
            DataColumn(label: Text('启用')),
            DataColumn(label: Text('URL')),
            DataColumn(label: Text('行为')),
          ],
          rows: List.generate(
              widget.requestRewrites.rules.length,
              (index) => DataRow(
                    cells: [
                      DataCell(Text(widget.requestRewrites.rules[index].name ?? "")),
                      DataCell(Text(widget.requestRewrites.rules[index].enabled ? "是" : "否")),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 60, maxWidth: 280),
                        child: Text(
                            '${widget.requestRewrites.rules[index].domain ?? ''}${widget.requestRewrites.rules[index].path}'),
                      )),
                      DataCell(Text(widget.requestRewrites.rules[index].type.name)),
                    ],
                    selected: currentSelectedIndex == index,
                    onSelectChanged: (value) {
                      setState(() {
                        currentSelectedIndex = value == true ? index : -1;
                      });
                    },
                  )),
        )));
  }
}
