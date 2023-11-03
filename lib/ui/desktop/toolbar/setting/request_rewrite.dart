import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
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
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                add();
              },
              label: const Text("增加", style: TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          OutlinedButton.icon(
              onPressed: () {
                var selectedIndex = requestRuleList.currentSelectedIndex();
                add(selectedIndex);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("编辑", style: TextStyle(fontSize: 12))),
          TextButton.icon(
              icon: const Icon(Icons.remove, size: 18),
              label: const Text("删除", style: TextStyle(fontSize: 12)),
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
                                  widget.configuration.requestRewrites.removeIndex(requestRuleList.removeSelected());
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
        const Text("选择框只是用来操作编辑和删除，规则启用状态在编辑页切换", style: TextStyle(fontSize: 11)),
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

    return AlertDialog(
        title: const Text("添加请求重写规则", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        scrollable: true,
        content: Container(
            constraints: const BoxConstraints(minWidth: 350, minHeight: 460),
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
                                dense: true,
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
                      const SizedBox(height: 5),
                      TextFormField(
                          decoration: decoration('URL', hintText: 'http://www.example.com/api/*'),
                          initialValue: rule.url,
                          validator: (val) => val?.isNotEmpty == true ? null : "URL不能为空",
                          onSaved: (val) => rule.url = val!.trim()),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<RuleType>(
                          value: rule.type,
                          isDense: true,
                          decoration: decoration('行为'),
                          items: RuleType.values
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(fontSize: 14))))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              rule.type = val!;
                            });
                          }),
                      const SizedBox(height: 5),
                      ...rewriteWidgets()
                    ]))),
        actions: [
          FilledButton(
              child: const Text("保存"),
              onPressed: () {
                if ((formKey.currentState as FormState).validate()) {
                  (formKey.currentState as FormState).save();

                  rule.updatePathReg();
                  rule.enabled = enableNotifier.value;
                  if (widget.currentIndex >= 0) {
                    RequestRewrites.instance.rules[widget.currentIndex] = rule;
                  } else {
                    RequestRewrites.instance.addRule(rule);
                  }

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

  InputDecoration decoration(String label, {String? hintText}) {
    Color color = Theme.of(context).colorScheme.primary;
    // Color color = Colors.blueAccent;

    return InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(fontSize: 14),
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
            maxLines: 3,
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
      const SizedBox(height: 5),
      TextFormField(
          initialValue: rule.requestBody,
          decoration: decoration('请求体替换为:'),
          minLines: 1,
          maxLines: 5,
          onSaved: (val) => rule.requestBody = val),
      const SizedBox(height: 5),
      TextFormField(
          initialValue: rule.responseBody,
          minLines: 3,
          maxLines: 10,
          decoration: decoration('响应体替换为:', hintText: '{"code":"200","data":{}}'),
          onSaved: (val) => rule.responseBody = val)
    ];
  }

  Widget textField(String label, TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return Row(children: [
      SizedBox(width: 50, child: Text(label)),
      Expanded(
          child: TextFormField(
        controller: controller,
        validator: (val) => val?.isNotEmpty == true ? null : "",
        keyboardType: keyboardType,
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
            contentPadding: const EdgeInsets.all(10),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            focusedBorder: focusedBorder(),
            isDense: true,
            border: const OutlineInputBorder()),
      ))
    ]);
  }

  InputBorder focusedBorder() {
    return OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2));
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
                      DataCell(
                          Text(widget.requestRewrites.rules[index].name ?? "", style: const TextStyle(fontSize: 14))),
                      DataCell(Text(widget.requestRewrites.rules[index].enabled ? "是" : "否",
                          style: const TextStyle(fontSize: 14))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 60, maxWidth: 280),
                        child: Text(widget.requestRewrites.rules[index].url, style: const TextStyle(fontSize: 14)),
                      )),
                      DataCell(
                          Text(widget.requestRewrites.rules[index].type.name, style: const TextStyle(fontSize: 14))),
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
