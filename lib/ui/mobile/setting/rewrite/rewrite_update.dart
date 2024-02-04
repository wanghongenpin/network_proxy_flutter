import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/ui/component/widgets.dart';

class RewriteUpdateWidget extends StatefulWidget {
  final String subtitle;
  final RuleType ruleType;
  final List<RewriteItem>? items;

  const RewriteUpdateWidget({super.key, required this.subtitle, required this.ruleType, this.items});

  @override
  State<RewriteUpdateWidget> createState() => _RewriteUpdateState();
}

class _RewriteUpdateState extends State<RewriteUpdateWidget> {
  List<RewriteItem> items = [];

  AppLocalizations get i18n => AppLocalizations.of(context)!;

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
    bool isCN = Localizations.localeOf(context).languageCode == "zh";
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(isCN ? widget.ruleType.label : widget.ruleType.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop(items);
                },
                child: Text(i18n.done)),
            const SizedBox(width: 10)
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.all(8),
            child: ListView(
              children: [
                Row(
                  children: [
                    SizedBox(
                        width: 260,
                        child: Text(widget.subtitle,
                            maxLines: 1, style: const TextStyle(fontSize: 13, color: Colors.grey))),
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

  AppLocalizations get i18n => AppLocalizations.of(context)!;

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
      keyTips = i18n.matchRule;
      valueTips = i18n.emptyMatchAll;
    } else if (rewriteType == RewriteType.updateQueryParam || rewriteType == RewriteType.updateHeader) {
      keyTips = rewriteType == RewriteType.updateQueryParam ? "name=123" : "Content-Type: application/json";
      valueTips = rewriteType == RewriteType.updateQueryParam ? "name=456" : "Content-Type: application/xml";
    }

    var typeList = widget.ruleType == RuleType.requestUpdate ? RewriteType.updateRequest : RewriteType.updateResponse;
    bool isCN = Localizations.localeOf(context).languageCode == "zh";
    return AlertDialog(
        title: Text(i18n.add,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n.cancel)),
          TextButton(
              onPressed: () {
                if (!(formKey.currentState as FormState).validate()) {
                  FlutterToastr.show(i18n.cannotBeEmpty, context, position: FlutterToastr.center);
                  return;
                }
                (formKey.currentState as FormState).save();
                rewriteItem.type = rewriteType;
                Navigator.of(context).pop(rewriteItem);
              },
              child: Text(i18n.confirm)),
        ],
        content: SizedBox(
            width: 320,
            height: 180,
            child: Form(
                key: formKey,
                child: ListView(children: [
                  Row(
                    children: [
                      Text(i18n.type),
                      const SizedBox(width: 15),
                      SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<RewriteType>(
                              value: rewriteType,
                              focusColor: Colors.transparent,
                              itemHeight: 48,
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.all(10), isDense: true, border: InputBorder.none),
                              items: typeList
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.getDescribe(isCN),
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
                  textField(isUpdate ? i18n.match : i18n.name, rewriteItem.key, keyTips,
                      required: !isDelete, onSaved: (val) => rewriteItem.key = val),
                  const SizedBox(height: 15),
                  textField(isUpdate ? i18n.replace : i18n.value, rewriteItem.value, valueTips,
                      onSaved: (val) => rewriteItem.value = val),
                ]))));
  }

  Widget textField(String label, String? val, String hint, {bool required = false, FormFieldSetter<String>? onSaved}) {
    return Row(children: [
      SizedBox(width: 55, child: Text(label)),
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
    return OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2));
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
  AppLocalizations get i18n => AppLocalizations.of(context)!;

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
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2))),
        child: SingleChildScrollView(
            child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(width: 130, padding: const EdgeInsets.only(left: 10), child: Text(i18n.type)),
              SizedBox(width: 50, child: Text(i18n.enable, textAlign: TextAlign.center)),
              const VerticalDivider(),
              Expanded(child: Text(i18n.modify)),
            ],
          ),
          const Divider(thickness: 0.5),
          Column(children: rows(widget.items))
        ])));
  }

  int selected = -1;

  List<Widget> rows(List<RewriteItem> list) {
    var primaryColor = Theme.of(context).colorScheme.primary;

    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onTap: () => showDialog(
                      context: context,
                      builder: (context) => RewriteUpdateAddDialog(item: list[index], ruleType: widget.ruleType))
                  .then((value) {
                if (value != null) setState(() {});
              }),
          onLongPress: () => showMenus(index),
          child: Container(
              color: selected == index
                  ? primaryColor
                  : index.isEven
                      ? Colors.grey.withOpacity(0.1)
                      : null,
              height: 38,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  SizedBox(
                      width: 130,
                      child: Text(list[index].type.getDescribe(i18n.localeName == 'zh'),
                          style: const TextStyle(fontSize: 13))),
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
                text: i18n.modify,
                onPressed: () async {
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
            const Divider(thickness: 0.5),
            BottomSheetItem(
                text: widget.items[index].enabled ? i18n.disabled : i18n.enable,
                onPressed: () => widget.items[index].enabled = !widget.items[index].enabled),
            const Divider(thickness: 0.5),
            BottomSheetItem(
                text: i18n.delete,
                onPressed: () async {
                  widget.items.removeAt(index);
                  if (mounted) FlutterToastr.show(i18n.deleteSuccess, context);
                }),
            Container(color: Theme.of(context).hoverColor, height: 8),
            TextButton(
                child: Container(
                    height: 50,
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(i18n.cancel, textAlign: TextAlign.center)),
                onPressed: () {
                  Navigator.of(context).pop();
                }),
          ]);
        }).then((value) {
      setState(() {
        selected = -1;
      });
    });
  }
}
