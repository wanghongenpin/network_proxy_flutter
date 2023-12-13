import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';

class RewriteUpdateDialog extends StatefulWidget {
  final String subtitle;
  final RuleType ruleType;
  final List<RewriteItem>? items;

  const RewriteUpdateDialog({super.key, required this.subtitle, required this.ruleType, this.items});

  @override
  State<RewriteUpdateDialog> createState() => _RewriteUpdateState();
}

class _RewriteUpdateState extends State<RewriteUpdateDialog> {
  List<RewriteItem> items = [];

  @override
  void initState() {
    super.initState();
    if (widget.items?.isNotEmpty == true) {
      items.addAll(widget.items!);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      add();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        actionsPadding: const EdgeInsets.only(right: 10, bottom: 10),
        contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 5),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("关闭")),
          TextButton(
              onPressed: () {
                Navigator.of(context).pop(items);
              },
              child: const Text("完成")),
        ],
        title: ListTile(title: Text(widget.ruleType.label, textAlign: TextAlign.center)),
        content: SizedBox(
            height: 380,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(widget.subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    Expanded(
                        child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [IconButton(onPressed: add, icon: const Icon(Icons.add)), const SizedBox(width: 10)],
                    ))
                  ],
                ),
                UpdateList(items: items, ruleType: widget.ruleType),
              ],
            )));
  }

  add() {
    showDialog(context: context, builder: (context) => RewriteUpdateAddDialog(ruleType: widget.ruleType)).then((value) {
      if (value != null) {
        setState(() {
          items.add(value);
        });
      }
    });
  }
}

class RewriteUpdateAddDialog extends StatefulWidget {
  final RewriteItem? item;
  final RuleType ruleType;

  const RewriteUpdateAddDialog({super.key, this.item, required this.ruleType});

  @override
  State<RewriteUpdateAddDialog> createState() => _RewriteUpdateAddState();
}

class _RewriteUpdateAddState extends State<RewriteUpdateAddDialog> {
  late RewriteType rewriteType;
  GlobalKey formKey = GlobalKey<FormState>();
  late RewriteItem rewriteItem;

  @override
  void initState() {
    super.initState();
    rewriteType = widget.item?.type ?? RewriteType.updateBody;
    rewriteItem = widget.item ?? RewriteItem(rewriteType, true);
  }

  @override
  Widget build(BuildContext context) {
    bool isDelete = rewriteType == RewriteType.removeQueryParam || rewriteType == RewriteType.removeHeader;
    bool isUpdate =
        [RewriteType.updateBody, RewriteType.updateHeader, RewriteType.updateQueryParam].contains(rewriteType);

    String keyTips = "";
    String valueTips = "";
    if (isDelete) {
      keyTips = "匹配规则";
      valueTips = "为空表示匹配全部";
    } else if (rewriteType == RewriteType.updateQueryParam || rewriteType == RewriteType.updateHeader) {
      keyTips = rewriteType == RewriteType.updateQueryParam ? "name=123" : "Content-Type: application/json";
      valueTips = rewriteType == RewriteType.updateQueryParam ? "name=456" : "Content-Type: application/xml";
    }

    var typeList = widget.ruleType == RuleType.requestUpdate ? RewriteType.updateRequest : RewriteType.updateResponse;

    return AlertDialog(
        title: const Text("添加修改",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("取消")),
          TextButton(
              onPressed: () {
                if (!(formKey.currentState as FormState).validate()) {
                  FlutterToastr.show("缺少配置", context, position: FlutterToastr.center);
                  return;
                }
                (formKey.currentState as FormState).save();
                rewriteItem.type = rewriteType;
                Navigator.of(context).pop(rewriteItem);
              },
              child: const Text("确定")),
        ],
        content: SizedBox(
            width: 320,
            height: 150,
            child: Form(
                key: formKey,
                child: Column(children: [
                  Row(
                    children: [
                      const Text('类型'),
                      const SizedBox(width: 15),
                      SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<RewriteType>(
                              value: rewriteType,
                              focusColor: Colors.transparent,
                              itemHeight: 48,
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.all(10), isDense: true, border: InputBorder.none),
                              items: typeList
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.label,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  rewriteType = val!;
                                });
                              })),
                    ],
                  ),
                  const SizedBox(height: 15),
                  textField(isUpdate ? "匹配" : "名称", rewriteItem.key, keyTips,
                      required: !isDelete, onSaved: (val) => rewriteItem.key = val),
                  const SizedBox(height: 15),
                  textField(isUpdate ? "替换" : "值", rewriteItem.value, valueTips,
                      onSaved: (val) => rewriteItem.value = val),
                ]))));
  }

  Widget textField(String label, String? val, String hint, {bool required = false, FormFieldSetter<String>? onSaved}) {
    return Row(children: [
      SizedBox(width: 50, child: Text(label)),
      Expanded(
          child: TextFormField(
        initialValue: val,
        style: const TextStyle(fontSize: 14),
        validator: (val) => val?.isNotEmpty == true || !required ? null : "",
        onSaved: onSaved,
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
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

class UpdateList extends StatefulWidget {
  final List<RewriteItem> items;
  final RuleType ruleType;

  const UpdateList({super.key, required this.items, required this.ruleType});

  @override
  State<UpdateList> createState() => _UpdateListState();
}

class _UpdateListState extends State<UpdateList> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        height: 320,
        width: 550,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            color: Colors.white,
            backgroundBlendMode: BlendMode.colorBurn),
        child: SingleChildScrollView(
            child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(width: 130, padding: const EdgeInsets.only(left: 10), child: const Text("类型")),
              const SizedBox(width: 50, child: Text("启用", textAlign: TextAlign.center)),
              const VerticalDivider(),
              const Expanded(child: Text("修改")),
            ],
          ),
          const Divider(thickness: 0.5),
          Column(children: rows(widget.items))
        ])));
  }

  int selected = -1;

  List<Widget> rows(List<RewriteItem> list) {
    var primaryColor = Theme.of(context).primaryColor;

    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onDoubleTap: () => showDialog(
                      context: context,
                      builder: (context) => RewriteUpdateAddDialog(item: list[index], ruleType: widget.ruleType))
                  .then((value) {
                if (value != null) setState(() {});
              }),
          onSecondaryTapDown: (details) => showMenus(details, index),
          child: Container(
              color: selected == index
                  ? primaryColor
                  : index.isEven
                      ? Colors.grey.withOpacity(0.1)
                      : null,
              height: 30,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  SizedBox(width: 130, child: Text(list[index].type.label, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 40,
                      child: SwitchWidget(
                          scale: 0.6,
                          value: list[index].enabled,
                          onChanged: (val) {
                            list[index].enabled = val;
                          })),
                  const SizedBox(width: 20),
                  Expanded(child: Text(getText(list[index]), style: const TextStyle(fontSize: 13))),
                ],
              )));
    });
  }

  String getText(RewriteItem item) {
    bool isUpdate =
        [RewriteType.updateBody, RewriteType.updateHeader, RewriteType.updateQueryParam].contains(item.type);
    if (isUpdate) {
      return "${item.key} -> ${item.value}";
    }

    return "${item.key}=${item.value}";
  }

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
                builder: (BuildContext context) =>
                    RewriteUpdateAddDialog(item: widget.items[index], ruleType: widget.ruleType)).then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          }),
      // PopupMenuItem(height: 35, child: const Text("导出"), onTap: () => export(widget.scripts[index])),
      PopupMenuItem(
          height: 35,
          child: widget.items[index].enabled ? const Text("禁用") : const Text("启用"),
          onTap: () => widget.items[index].enabled = !widget.items[index].enabled),
      const PopupMenuDivider(),
      PopupMenuItem(
          height: 35,
          child: const Text("删除"),
          onTap: () async {
            // widget.requestRewrites.removeIndex([index]);
            if (mounted) FlutterToastr.show('删除成功', context);
          }),
    ]).then((value) {
      setState(() {
        selected = -1;
      });
    });
  }
}
