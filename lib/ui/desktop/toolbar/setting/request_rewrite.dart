import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/ui/component/multi_window.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';

class RequestRewriteWidget extends StatefulWidget {
  final int windowId;
  final RequestRewrites requestRewrites;

  const RequestRewriteWidget({super.key, required this.windowId, required this.requestRewrites});

  @override
  State<StatefulWidget> createState() {
    return RequestRewriteState();
  }
}

class RequestRewriteState extends State<RequestRewriteWidget> {
  late ValueNotifier<bool> enableNotifier;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(onKeyEvent);
    enableNotifier = ValueNotifier(widget.requestRewrites.enabled == true);
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      print("call.method: ${call.method}");
      if (call.method == 'reloadRequestRewrite') {
        await widget.requestRewrites.reloadRequestRewrite();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(onKeyEvent);
    super.dispose();
  }

  void onKeyEvent(RawKeyEvent event) async {
    if (event.isKeyPressed(LogicalKeyboardKey.exit) && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    if ((event.isKeyPressed(LogicalKeyboardKey.metaLeft) || event.isControlPressed) &&
        event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }
      RawKeyboard.instance.removeListener(onKeyEvent);
      WindowController.fromWindowId(widget.windowId).close();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        appBar: AppBar(
            title: const Text("请求重写", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            toolbarHeight: 34,
            centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
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
                                MultiWindow.invokeRefreshRewrite(Operation.refresh);
                              });
                        })),
                Expanded(
                    child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("添加", style: TextStyle(fontSize: 12)),
                      onPressed: add,
                    ),
                    // const SizedBox(width: 20),
                    // FilledButton.icon(
                    //   icon: const Icon(Icons.input_rounded, size: 18),
                    //   style: ElevatedButton.styleFrom(padding: const EdgeInsets.only(left: 20, right: 20)),
                    //   onPressed: add,
                    //   label: const Text("导入"),
                    // )
                  ],
                )),
                const SizedBox(width: 15)
              ]),
              const SizedBox(height: 10),
              RequestRuleList(widget.requestRewrites),
            ])));
  }

  void add([int currentIndex = -1]) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return RuleAddDialog(
              currentIndex: currentIndex, rule: currentIndex >= 0 ? widget.requestRewrites.rules[currentIndex] : null);
        }).then((value) {
      if (value != null) setState(() {});
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
              onPressed: () async {
                if ((formKey.currentState as FormState).validate()) {
                  (formKey.currentState as FormState).save();

                  rule.updatePathReg();
                  rule.enabled = enableNotifier.value;
                  if (widget.currentIndex >= 0) {
                    (await RequestRewrites.instance).rules[widget.currentIndex] = rule;
                    MultiWindow.invokeRefreshRewrite(Operation.update, index: widget.currentIndex, rule: rule);
                  } else {
                    (await RequestRewrites.instance).addRule(rule);
                    MultiWindow.invokeRefreshRewrite(Operation.add, rule: rule);
                  }
                  if (mounted) {
                    Navigator.of(context).pop(rule);
                  }
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
}

class _RequestRuleListState extends State<RequestRuleList> {
  int selected = -1;
  late List<RequestRewriteRule> rules;

  @override
  initState() {
    super.initState();
    rules = widget.requestRewrites.rules;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        constraints: const BoxConstraints(maxHeight: 500, minHeight: 300),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            color: Colors.white,
            backgroundBlendMode: BlendMode.colorBurn),
        child: SingleChildScrollView(
            child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(width: 130, padding: const EdgeInsets.only(left: 10), child: const Text("名称")),
              const SizedBox(width: 50, child: Text("启用", textAlign: TextAlign.center)),
              const VerticalDivider(),
              const Expanded(child: Text("URL")),
              const SizedBox(width: 100, child: Text("行为", textAlign: TextAlign.center)),
            ],
          ),
          const Divider(thickness: 0.5),
          Column(children: rows(widget.requestRewrites.rules))
        ])));
  }

  List<Widget> rows(List<RequestRewriteRule> list) {
    var primaryColor = Theme.of(context).primaryColor;

    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onDoubleTap: () async {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return RuleAddDialog(currentIndex: index, rule: widget.requestRewrites.rules[index]);
                }).then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          },
          onSecondaryTapDown: (details) => showMenus(details, index),
          child: Container(
              color: selected == index
                  ? primaryColor.withOpacity(0.8)
                  : index.isEven
                      ? Colors.grey.withOpacity(0.1)
                      : null,
              height: 30,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  SizedBox(width: 130, child: Text(list[index].name!, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 40,
                      child: Transform.scale(
                          scale: 0.65,
                          child: SwitchWidget(
                              value: list[index].enabled,
                              onChanged: (val) {
                                list[index].enabled = val;
                                MultiWindow.invokeRefreshRewrite(Operation.update, index: index, rule: list[index]);
                              }))),
                  const SizedBox(width: 20),
                  Expanded(
                      child:
                          Text(list[index].url, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 100,
                      child: Text(list[index].type.name,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                ],
              )));
    });
  }

  //点击菜单
  showMenus(TapDownDetails details, int index) {
    setState(() {
      selected = index;
    });
    showContextMenu(context, details.globalPosition, items: [
      PopupMenuItem(
          height: 35,
          child: const Text("编辑"),
          onTap: () async {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return RuleAddDialog(currentIndex: index, rule: widget.requestRewrites.rules[index]);
                }).then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          }),
      // PopupMenuItem(height: 35, child: const Text("导出"), onTap: () => export(widget.scripts[index])),
      PopupMenuItem(
          height: 35,
          child: rules[index].enabled ? const Text("禁用") : const Text("启用"),
          onTap: () {
            rules[index].enabled = !rules[index].enabled;
            MultiWindow.invokeRefreshRewrite(Operation.update, index: index, rule: rules[index]);
          }),
      const PopupMenuDivider(),
      PopupMenuItem(
          height: 35,
          child: const Text("删除"),
          onTap: () async {
            widget.requestRewrites.removeIndex([index]);
            MultiWindow.invokeRefreshRewrite(Operation.delete, index: index);
            if (context.mounted) FlutterToastr.show('删除成功', context);
          }),
    ]).then((value) {
      setState(() {
        selected = -1;
      });
    });
  }
}
