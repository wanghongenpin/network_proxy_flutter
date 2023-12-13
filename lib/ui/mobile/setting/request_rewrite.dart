import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/ui/component/widgets.dart';

import 'rewrite/rewrite_replace.dart';

class MobileRequestRewrite extends StatefulWidget {
  final RequestRewrites requestRewrites;

  const MobileRequestRewrite({super.key, required this.requestRewrites});

  @override
  State<MobileRequestRewrite> createState() => _MobileRequestRewriteState();
}

class _MobileRequestRewriteState extends State<MobileRequestRewrite> {
  bool enabled = false;

  @override
  void initState() {
    super.initState();
    enabled = widget.requestRewrites.enabled;
  }

  @override
  void dispose() {
    if (enabled != widget.requestRewrites.enabled) {
      widget.requestRewrites.enabled = enabled;
      widget.requestRewrites.flushRequestRewriteConfig();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text("请求重写列表", style: TextStyle(fontSize: 16))),
        body: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text("是否启用请求重写"),
                  SwitchWidget(value: enabled, scale: 0.8, onChanged: (val) => enabled = val),
                  const Expanded(child: SizedBox()),
                  FilledButton.icon(icon: const Icon(Icons.add, size: 18), onPressed: add, label: const Text("添加")),
                  const SizedBox(width: 10),
                ]),
                const SizedBox(height: 10),
                Expanded(child: RequestRuleList(widget.requestRewrites)),
              ],
            )));
  }

  void add([int currentIndex = -1]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RewriteRule())).then((rule) {
      if (rule != null) {
        setState(() {});
      }
    });
  }
}

///请求重写规则列表
class RequestRuleList extends StatefulWidget {
  final RequestRewrites requestRewrites;

  RequestRuleList(this.requestRewrites) : super(key: GlobalKey<_RequestRuleListState>());

  @override
  State<RequestRuleList> createState() => _RequestRuleListState();
}

class _RequestRuleListState extends State<RequestRuleList> {
  int selected = -1;
  late List<RequestRewriteRule> rules;
  bool changed = false;

  @override
  initState() {
    super.initState();
    rules = widget.requestRewrites.rules;
  }

  @override
  void dispose() {
    if (changed) {
      widget.requestRewrites.flushRequestRewriteConfig();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10, bottom: 30),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            color: Colors.white,
            backgroundBlendMode: BlendMode.colorBurn),
        child: Scrollbar(
            child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(width: 80, padding: const EdgeInsets.only(left: 10), child: const Text("名称")),
                const SizedBox(width: 30, child: Text("启用", textAlign: TextAlign.center)),
                const VerticalDivider(),
                const Expanded(child: Text("URL")),
                const SizedBox(width: 60, child: Text("行为", textAlign: TextAlign.center)),
              ],
            ),
            const Divider(thickness: 0.5),
            Column(children: rows(widget.requestRewrites.rules))
          ],
        )));
  }

  List<Widget> rows(List<RequestRewriteRule> list) {
    var primaryColor = Theme.of(context).primaryColor;

    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onLongPress: () => showMenus(index),
          onTap: () async {
            var rule = widget.requestRewrites.rules[index];
            var rewriteItems = await widget.requestRewrites.getRewriteItems(rule);
            if (!mounted) return;
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => RewriteRule(rule: rule, items: rewriteItems)))
                .then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          },
          child: Container(
              color: selected == index
                  ? primaryColor.withOpacity(0.8)
                  : index.isEven
                      ? Colors.grey.withOpacity(0.1)
                      : null,
              height: 45,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  SizedBox(
                      width: 80,
                      child: Text(list[index].name ?? "",
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 20,
                      child: SwitchWidget(
                          scale: 0.65,
                          value: list[index].enabled,
                          onChanged: (val) {
                            list[index].enabled = val;
                            changed = true;
                          })),
                  const SizedBox(width: 20),
                  Expanded(child: Text(list[index].url, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 60,
                      child: Text(list[index].type.label,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                ],
              )));
    });
  }

  //点击菜单
  showMenus(int index) {
    setState(() {
      selected = index;
    });
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        context: context,
        enableDrag: true,
        builder: (ctx) {
          return Wrap(alignment: WrapAlignment.center, children: [
            BottomSheetItem(
                text: "编辑",
                onPressed: () async {
                  var rule = widget.requestRewrites.rules[index];
                  var rewriteItems = await widget.requestRewrites.getRewriteItems(rule);
                  if (!mounted) return;

                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) => RewriteRule(rule: rule, items: rewriteItems)))
                      .then((value) {
                    if (value != null) {
                      setState(() {});
                    }
                  });
                }),
            const Divider(thickness: 0.5, height: 1),
            BottomSheetItem(
                text: rules[index].enabled ? "禁用" : "启用",
                onPressed: () {
                  rules[index].enabled = !rules[index].enabled;
                  changed = true;
                }),
            const Divider(thickness: 0.5, height: 1),
            BottomSheetItem(
                text: "删除",
                onPressed: () async {
                  widget.requestRewrites.removeIndex([index]);
                  if (mounted) FlutterToastr.show('删除成功', context);
                }),
            Container(color: Theme.of(context).hoverColor, height: 8),
            TextButton(
              child: Container(
                  height: 42,
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 10),
                  child: const Text("取消", textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ]);
        }).then((value) => setState(() {
          selected = -1;
    }));
  }

  DataCell cell(Widget child) {
    return DataCell(child);
  }
}

///请求重写规则添加
class RewriteRule extends StatefulWidget {
  final RequestRewriteRule? rule;
  final List<RewriteItem>? items;

  const RewriteRule({super.key, this.rule, this.items});

  @override
  State<StatefulWidget> createState() {
    return _RewriteRuleState();
  }
}

class _RewriteRuleState extends State<RewriteRule> {
  late ValueNotifier<bool> enableNotifier;
  late RequestRewriteRule rule;
  List<RewriteItem>? items;
  late RuleType ruleType;
  late TextEditingController nameInput;
  late TextEditingController urlInput;

  @override
  void initState() {
    super.initState();
    rule = widget.rule ?? RequestRewriteRule(url: '', type: RuleType.responseReplace);
    enableNotifier = ValueNotifier(rule.enabled == true);
    items = widget.items;
    ruleType = rule.type;

    nameInput = TextEditingController(text: rule.name);
    urlInput = TextEditingController(text: rule.url);
  }

  @override
  void dispose() {
    enableNotifier.dispose();
    urlInput.dispose();
    nameInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("请求重写规则", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
              child: const Text("保存"),
              onPressed: () async {
                if (!(formKey.currentState as FormState).validate()) {
                  FlutterToastr.show("缺少配置", context, position: FlutterToastr.center);
                  return;
                }

                (formKey.currentState as FormState).save();
                rule.enabled = enableNotifier.value;
                rule.name = nameInput.text;
                rule.url = urlInput.text;

                var requestRewrites = await RequestRewrites.instance;
                var index = requestRewrites.rules.indexOf(rule);

                if (index >= 0) {
                  await requestRewrites.updateRule(index, rule, items);
                } else {
                  await requestRewrites.addRule(rule, items!);
                }
                requestRewrites.flushRequestRewriteConfig();
                if (mounted) {
                  FlutterToastr.show("保存请求重写规则成功", context);
                  Navigator.of(context).pop(rule);
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
                          title: const Text('是否启用',
                              style: TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.start),
                          value: enable,
                          onChanged: (value) => enableNotifier.value = value);
                    }),
                textField('名称:', nameInput, '请输入名称'),
                textField('URL:', urlInput, 'http://www.example.com/api/*',
                    required: true, keyboardType: TextInputType.url),
                Row(children: [
                  const SizedBox(
                      width: 50, child: Text('行为:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  SizedBox(
                      width: 110,
                      height: 50,
                      child: DropdownButtonFormField<RuleType>(
                        onSaved: (val) => rule.type = val!,
                        validator: (val) => items == null || items!.isEmpty ? "" : null,
                        value: ruleType,
                        decoration: const InputDecoration(
                          errorStyle: TextStyle(height: 0, fontSize: 0),
                          contentPadding: EdgeInsets.only(left: 7, right: 7),
                        ),
                        items: RuleType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                        onChanged: (val) => ruleType = val!,
                      )),
                  const SizedBox(width: 10),
                  TextButton(
                      onPressed: () => showEdit(rule), child: const Text("点击编辑", style: TextStyle(fontSize: 16))),
                ]),
                const SizedBox(height: 10),
                if (items?.isNotEmpty == true && ruleType != RuleType.redirect)
                  Padding(
                      padding: const EdgeInsets.only(left: 50),
                      child: Text("替换: ${items?.where((it) => it.enabled).map((e) => e.type.label).join(" ")}",
                          style: const TextStyle(color: Colors.grey))),
              ]))),
    );
  }

  void showEdit(RequestRewriteRule rule) async {
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (context) => RewriteReplaceWidget(subtitle: urlInput.text, items: items, ruleType: ruleType)))
        .then((value) {
      if (value is List<RewriteItem>) {
        setState(() {
          items = value;
        });
      }
    });
  }

  Widget textField(String label, TextEditingController controller, String hint,
      {bool required = false, TextInputType? keyboardType, FormFieldSetter<String>? onSaved}) {
    return Row(children: [
      SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
      Expanded(
          child: TextFormField(
        controller: controller,
        validator: (val) => val?.isNotEmpty == true || !required ? null : "",
        onSaved: onSaved,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.all(10),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ))
    ]);
  }
}
