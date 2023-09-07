import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';

class MobileRequestRewrite extends StatefulWidget {
  final Configuration configuration;

  const MobileRequestRewrite({super.key, required this.configuration});

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
    requestRuleList = RequestRuleList(widget.configuration.requestRewrites);
    enableNotifier = ValueNotifier(widget.configuration.requestRewrites.enabled);
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
    return Scaffold(
        appBar: AppBar(title: const Text("请求重写")),
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
                Expanded(child: requestRuleList),
              ],
            )));
  }

  void add([int currentIndex = -1]) {
    var rewriteRule =
        RewriteRule(rule: currentIndex == -1 ? null : widget.configuration.requestRewrites.rules[currentIndex]);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text("请求重写规则", style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
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

                  FlutterToastr.show("添加请求重写规则成功", context);
                  Navigator.of(context).pop(rule);
                }
              })
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(10),
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
    );
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
          maxLines: 10,
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
                          cell(Text(widget.requestRewrites.rules[index].name ?? "")),
                          cell(Text(widget.requestRewrites.rules[index].enabled ? "是" : "否")),
                          cell(ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 60, maxWidth: 150),
                              child: Text(
                                  '${widget.requestRewrites.rules[index].domain ?? ''}${widget.requestRewrites.rules[index].path}'))),
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
