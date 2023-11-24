import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';

class MobileRequestRewrite extends StatefulWidget {
  final RequestRewrites requestRewrites;

  const MobileRequestRewrite({super.key, required this.requestRewrites});

  @override
  State<MobileRequestRewrite> createState() => _MobileRequestRewriteState();
}

class _MobileRequestRewriteState extends State<MobileRequestRewrite> {
  late RequestRuleList requestRuleList;
  late ValueNotifier<bool> enableNotifier;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    requestRuleList = RequestRuleList(widget.requestRewrites);
    enableNotifier = ValueNotifier(widget.requestRewrites.enabled);
  }

  @override
  void dispose() {
    if (changed || enableNotifier.value != widget.requestRewrites.enabled) {
      widget.requestRewrites.enabled = enableNotifier.value;
      widget.requestRewrites.flushRequestRewriteConfig();
    }

    enableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("请求重写", style: TextStyle(fontSize: 16))),
        body: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    child: ValueListenableBuilder(
                        valueListenable: enableNotifier,
                        builder: (_, bool v, __) {
                          return SwitchListTile(
                              contentPadding: const EdgeInsets.only(left: 2),
                              title: const Text('是否启用请求重写'),
                              value: enableNotifier.value,
                              onChanged: (value) {
                                enableNotifier.value = value;
                              });
                        })),
                const SizedBox(height: 10),
                Row(children: [
                  FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () {
                        add();
                      },
                      label: const Text("增加", style: TextStyle(fontSize: 14))),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                      onPressed: () {
                        var selectedIndex = requestRuleList.currentSelectedIndex();
                        add(selectedIndex);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("编辑", style: TextStyle(fontSize: 14))),
                  TextButton.icon(
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text("删除", style: TextStyle(fontSize: 14)),
                      onPressed: () {
                        var selected = requestRuleList.currentSelectedIndex();
                        if (selected < 0) {
                          return;
                        }

                        showDialog(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title: const Text("是否删除该请求重写？", style: TextStyle(fontSize: 18)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
                                  TextButton(
                                      onPressed: () {
                                        changed = true;
                                        setState(() {
                                          widget.requestRewrites
                                              .removeIndex(requestRuleList.removeSelected());
                                          requestRuleList.changeState();
                                        });
                                        FlutterToastr.show('删除成功', context);
                                        Navigator.pop(context);
                                      },
                                      child: const Text("删除")),
                                ],
                              );
                            });
                      })
                ]),
                const SizedBox(height: 10),
                const Text("选择框只是用来操作编辑和删除，规则启用状态在编辑页切换", style: TextStyle(fontSize: 12)),
                Expanded(child: requestRuleList),
              ],
            )));
  }

  void add([int currentIndex = -1]) {
    var rewriteRule =
        RewriteRule(rule: currentIndex == -1 ? null : widget.requestRewrites.rules[currentIndex]);

    Navigator.push(context, MaterialPageRoute(builder: (_) => rewriteRule)).then((rule) {
      if (rule != null) {
        changed = true;
        setState(() {
          requestRuleList.changeState();
        });
      }
    });
  }
}

///请求重写规则添加对话框
class RewriteRule extends StatefulWidget {
  final int currentIndex;
  final RequestRewriteRule? rule;

  const RewriteRule({super.key, required this.rule, this.currentIndex = -1});

  @override
  State<StatefulWidget> createState() {
    return _RewriteRuleState();
  }
}

class _RewriteRuleState extends State<RewriteRule> {
  late ValueNotifier<bool> enableNotifier;
  late RequestRewriteRule rule;

  @override
  void initState() {
    super.initState();
    rule = widget.rule ?? RequestRewriteRule(true, url: '');
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("请求重写规则", style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
              child: const Text("保存"),
              onPressed: () async {
                if ((formKey.currentState as FormState).validate()) {
                  (formKey.currentState as FormState).save();
                  rule.updatePathReg();
                  rule.enabled = enableNotifier.value;
                  if (widget.currentIndex >= 0) {
                    (await RequestRewrites.instance).rules[widget.currentIndex] = rule;
                  } else {
                    (await RequestRewrites.instance).addRule(rule);
                  }

                  if (mounted) {
                    FlutterToastr.show("保存请求重写规则成功", context);
                    Navigator.of(context).pop(rule);
                  }
                }
              })
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(15),
          child: Form(
              key: formKey,
              child: ListView(children: <Widget>[
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
                  decoration: decoration('名称'),
                  initialValue: rule.name,
                  onSaved: (val) => rule.name = val,
                ),
                TextFormField(
                    decoration: decoration('URL', hintText: 'http://www.example.com/api/*'),
                    initialValue: rule.url,
                    onSaved: (val) => rule.url = val!.trim()),
                DropdownButtonFormField<RuleType>(
                    decoration: decoration('行为'),
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
    );
  }

  InputDecoration decoration(String label, {String? hintText}) {
    Color color = Theme.of(context).colorScheme.primary;
    // Color color = Colors.blueAccent;

    return InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
        border: UnderlineInputBorder(borderSide: BorderSide(width: 0.3, color: color)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(width: 0.3, color: color)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(width: 1.5, color: color)));
  }

  List<Widget> rewriteWidgets() {
    if (rule.type == RuleType.redirect) {
      return [
        TextFormField(
            decoration: decoration('重定向到:', hintText: 'http://www.example.com/api'),
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
          decoration: decoration('URL参数替换为:'),
          maxLines: 1,
          onSaved: (val) => rule.queryParam = val),
      TextFormField(
          initialValue: rule.requestBody,
          decoration: decoration('请求体替换为:'),
          minLines: 1,
          maxLines: 10,
          onSaved: (val) => rule.requestBody = val),
      TextFormField(
          initialValue: rule.responseBody,
          minLines: 3,
          maxLines: 15,
          decoration: decoration('响应体替换为:', hintText: '{"code":"200","data":{}}'),
          onSaved: (val) => rule.responseBody = val)
    ];
  }
}

///请求重写规则列表
class RequestRuleList extends StatefulWidget {
  final RequestRewrites requestRewrites;

  RequestRuleList(this.requestRewrites) : super(key: GlobalKey<_RequestRuleListState>());

  @override
  State<RequestRuleList> createState() => _RequestRuleListState();

  List<int> removeSelected() {
    var index = currentSelectedIndex();
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    state?.selected = -1;
    return index == -1 ? [] : [index];
  }

  int currentSelectedIndex() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    return state?.selected ?? -1;
  }

  changeState() {
    var state = (key as GlobalKey<_RequestRuleListState>).currentState;
    state?.changeState();
  }
}

class _RequestRuleListState extends State<RequestRuleList> {
  int selected = -1;

  changeState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 30,
              dataRowMaxHeight: 60,
              columnSpacing: 10,
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
                          cell(Text(widget.requestRewrites.rules[index].name ?? "")),
                          cell(Text(widget.requestRewrites.rules[index].enabled ? "是" : "否")),
                          cell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 60, maxWidth: 150),
                              child: Text(widget.requestRewrites.rules[index].url))),
                          cell(Text(widget.requestRewrites.rules[index].type.name)),
                        ],
                        selected: selected == index,
                        onSelectChanged: (value) {
                          setState(() {
                            selected = value == true ? index : -1;
                          });
                        },
                      )),
            )));
  }

  DataCell cell(Widget child) {
    return DataCell(child);
  }
}
