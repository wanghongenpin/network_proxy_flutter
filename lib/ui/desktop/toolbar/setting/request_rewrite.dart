import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/component/multi_window.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/rewrite/rewrite_replace.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/rewrite/rewrite_update.dart';

/// @author wanghongen
/// 2023/10/8
class RequestRewriteWidget extends StatefulWidget {
  final int windowId;
  final RequestRewrites requestRewrites;

  const RequestRewriteWidget(
      {super.key, required this.windowId, required this.requestRewrites});

  @override
  State<StatefulWidget> createState() {
    return RequestRewriteState();
  }
}

class RequestRewriteState extends State<RequestRewriteWidget> {
  late ValueNotifier<bool> enableNotifier;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(onKeyEvent);
    enableNotifier = ValueNotifier(widget.requestRewrites.enabled == true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(onKeyEvent);
    super.dispose();
  }

  bool onKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        Navigator.canPop(context)) {
      Navigator.maybePop(context);
      return true;
    }

    if ((HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        event.logicalKey == LogicalKeyboardKey.keyW) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
      HardwareKeyboard.instance.removeHandler(onKeyEvent);
      WindowController.fromWindowId(widget.windowId).close();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        appBar: AppBar(
            title: Text(localizations.requestRewrite,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            toolbarHeight: 34,
            centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(
                    width: 280,
                    child: ValueListenableBuilder(
                        valueListenable: enableNotifier,
                        builder: (_, bool v, __) {
                          return Transform.scale(
                              scale: 0.8,
                              child: SwitchListTile(
                                  contentPadding:
                                      const EdgeInsets.only(left: 2),
                                  title:
                                      Text(localizations.requestRewriteEnable),
                                  value: enableNotifier.value,
                                  onChanged: (value) {
                                    enableNotifier.value = value;
                                    MultiWindow.invokeRefreshRewrite(
                                        Operation.enabled,
                                        enabled: value);
                                  }));
                        })),
                const SizedBox(width: 10),
                Expanded(
                    child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        tooltip: localizations.refresh),
                    const SizedBox(width: 30),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(localizations.add,
                          style: const TextStyle(fontSize: 12)),
                      onPressed: add,
                    ),
                    const SizedBox(width: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.input_rounded, size: 18),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(left: 20, right: 20)),
                      onPressed: import,
                      label: Text(localizations.import),
                    )
                  ],
                )),
                const SizedBox(width: 15)
              ]),
              const SizedBox(height: 10),
              RequestRuleList(widget.requestRewrites,
                  windowId: widget.windowId),
            ])));
  }

  //刷新
  void refresh() async {
    await widget.requestRewrites.reloadRequestRewrite();
    setState(() {});
  }

  //导入js
  import() async {
    String? file =
        await DesktopMultiWindow.invokeMethod(0, 'openFile', 'config');
    WindowController.fromWindowId(widget.windowId).show();
    if (file == null) {
      return;
    }

    try {
      List json = jsonDecode(await File(file).readAsString());
      for (var item in json) {
        var rule = RequestRewriteRule.formJson(item);
        var items = (item['items'] as List)
            .map((e) => RewriteItem.fromJson(e))
            .toList();

        widget.requestRewrites.addRule(rule, items);
        await MultiWindow.invokeRefreshRewrite(Operation.add,
            rule: rule, items: items);
      }

      if (mounted) {
        FlutterToastr.show(localizations.importSuccess, context);
      }
      setState(() {});
    } catch (e, t) {
      logger.e('导入失败 $file', error: e, stackTrace: t);
      if (mounted) {
        FlutterToastr.show("${localizations.importFailed} $e", context);
      }
    }
  }

  void add() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            RuleAddDialog(windowId: widget.windowId)).then((value) {
      if (value != null) setState(() {});
    });
  }
}

///请求重写规则列表
class RequestRuleList extends StatefulWidget {
  final int windowId;
  final RequestRewrites requestRewrites;

  const RequestRuleList(this.requestRewrites,
      {super.key, required this.windowId});

  @override
  State<RequestRuleList> createState() => _RequestRuleListState();
}

class _RequestRuleListState extends State<RequestRuleList> {
  Map<int, bool> selected = {};
  late List<RequestRewriteRule> rules;
  bool isPress = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  initState() {
    super.initState();
    rules = widget.requestRewrites.rules;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onSecondaryTapDown: (details) => showGlobalMenu(details.globalPosition),
        onTapDown: (details) {
          if (selected.isEmpty) {
            return;
          }
          if (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed) {
            return;
          }
          setState(() {
            selected.clear();
          });
        },
        child: Listener(
            onPointerUp: (details) => isPress = false,
            onPointerDown: (details) => isPress = true,
            child: Container(
                padding: const EdgeInsets.only(top: 10),
                height: 500,
                // constraints: const BoxConstraints(maxHeight: 500, minHeight: 350),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.2))),
                child: SingleChildScrollView(
                    child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                          width: 130,
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(localizations.name)),
                      SizedBox(
                          width: 50,
                          child: Text(localizations.enable,
                              textAlign: TextAlign.center)),
                      const VerticalDivider(),
                      const Expanded(child: Text("URL")),
                      SizedBox(
                          width: 100,
                          child: Text(localizations.action,
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const Divider(thickness: 0.5),
                  Column(children: rows(widget.requestRewrites.rules))
                ])))));
  }

  enableStatus(bool enable) {
    if (selected.isEmpty) return;
    selected.forEach((key, value) {
      if (rules[key].enabled == enable) return;

      rules[key].enabled = enable;
      MultiWindow.invokeRefreshRewrite(Operation.update,
          index: key, rule: rules[key]);
    });

    setState(() {});
  }

  showGlobalMenu(Offset offset) {
    showContextMenu(context, offset, items: [
      PopupMenuItem(
          height: 35,
          child: Text(localizations.newBuilt),
          onTap: () => showEdit()),
      PopupMenuItem(
          height: 35,
          child: Text(localizations.export),
          onTap: () => export(selected.keys.toList())),
      const PopupMenuDivider(),
      PopupMenuItem(
          height: 35,
          child: Text(localizations.enableSelect),
          onTap: () => enableStatus(true)),
      PopupMenuItem(
          height: 35,
          child: Text(localizations.disableSelect),
          onTap: () => enableStatus(false)),
      const PopupMenuDivider(),
      PopupMenuItem(
          height: 35,
          child: Text(localizations.deleteSelect),
          onTap: () => removeRewrite(selected.keys.toList())),
    ]);
  }

  List<Widget> rows(List<RequestRewriteRule> list) {
    var primaryColor = Theme.of(context).colorScheme.primary;
    bool isCN = Localizations.localeOf(context) ==
        const Locale.fromSubtags(languageCode: 'zh');

    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onSecondaryTapDown: (details) => showMenus(details, index),
          onDoubleTap: () => showEdit(index),
          onHover: (hover) {
            if (isPress && selected[index] != true) {
              setState(() {
                selected[index] = true;
              });
            }
          },
          onTap: () {
            if (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) {
              setState(() {
                selected[index] = !(selected[index] ?? false);
              });
              return;
            }
            if (selected.isEmpty) {
              return;
            }
            setState(() {
              selected.clear();
            });
          },
          child: Container(
              color: selected[index] == true
                  ? primaryColor.withOpacity(0.8)
                  : index.isEven
                      ? Colors.grey.withOpacity(0.1)
                      : null,
              height: 30,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  SizedBox(
                      width: 130,
                      child: Text(list[index].name ?? '',
                          style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 40,
                      child: SwitchWidget(
                          scale: 0.6,
                          value: list[index].enabled,
                          onChanged: (val) {
                            list[index].enabled = val;
                            MultiWindow.invokeRefreshRewrite(Operation.update,
                                index: index, rule: list[index]);
                          })),
                  const SizedBox(width: 20),
                  Expanded(
                      child: Text(list[index].url,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 100,
                      child: Text(
                          isCN ? list[index].type.label : list[index].type.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13))),
                ],
              )));
    });
  }

  //导出
  export(List<int> indexes) async {
    if (indexes.isEmpty) return;

    String fileName = 'proxypin-rewrites.config';
    String? saveLocation =
        await DesktopMultiWindow.invokeMethod(0, 'getSaveLocation', fileName);
    WindowController.fromWindowId(widget.windowId).show();
    if (saveLocation == null) {
      return;
    }

    var list = [];
    for (var index in indexes) {
      var rule = widget.requestRewrites.rules[index];
      var json = rule.toJson();
      json.remove("rewritePath");
      json['items'] = await widget.requestRewrites.getRewriteItems(rule);
      list.add(json);
    }

    final XFile xFile =
        XFile.fromData(utf8.encode(jsonEncode(list)), mimeType: 'json');
    await xFile.saveTo(saveLocation);
    if (mounted) FlutterToastr.show(localizations.exportSuccess, context);
  }

  //删除
  Future<void> removeRewrite(List<int> indexes) async {
    if (indexes.isEmpty) return;
    return showConfirmDialog(context,
        content: localizations.requestRewriteDeleteConfirm(indexes.length),
        onConfirm: () async {
      var list = indexes.toList();
      list.sort((a, b) => b.compareTo(a));
      for (var value in list) {
        await widget.requestRewrites.removeIndex([value]);
        MultiWindow.invokeRefreshRewrite(Operation.delete, index: value);
      }

      setState(() {
        selected.clear();
      });
      if (mounted) FlutterToastr.show(localizations.deleteSuccess, context);
    });
  }

  showEdit([int? index]) async {
    RequestRewriteRule? rule;
    List<RewriteItem>? rewriteItems;

    if (index != null) {
      rule = widget.requestRewrites.rules[index];
      rewriteItems = await widget.requestRewrites.getRewriteItems(rule);
    }
    if (!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return RuleAddDialog(
              rule: rule, items: rewriteItems, windowId: widget.windowId);
        }).then((value) {
      if (value != null) {
        setState(() {});
      }
    });
  }

  //点击菜单
  showMenus(TapDownDetails details, int index) {
    if (selected.length > 1) {
      showGlobalMenu(details.globalPosition);
      return;
    }
    setState(() {
      selected[index] = true;
    });
    showContextMenu(context, details.globalPosition, items: [
      PopupMenuItem(
          height: 35,
          child: Text(localizations.edit),
          onTap: () => showEdit(index)),
      PopupMenuItem(
          height: 35,
          onTap: () => export([index]),
          child: Text(localizations.export)),
      PopupMenuItem(
          height: 35,
          child: rules[index].enabled
              ? Text(localizations.disabled)
              : Text(localizations.enable),
          onTap: () {
            rules[index].enabled = !rules[index].enabled;
            MultiWindow.invokeRefreshRewrite(Operation.update,
                index: index, rule: rules[index]);
          }),
      const PopupMenuDivider(),
      PopupMenuItem(
          height: 35,
          child: Text(localizations.delete),
          onTap: () async {
            await widget.requestRewrites.removeIndex([index]);
            MultiWindow.invokeRefreshRewrite(Operation.delete, index: index);
          })
    ]).then((value) {
      setState(() {
        selected.remove(index);
      });
    });
  }
}

///请求重写规则添加对话框
class RuleAddDialog extends StatefulWidget {
  final RequestRewriteRule? rule;
  final List<RewriteItem>? items;
  final int? windowId;

  const RuleAddDialog(
      {super.key, this.rule, this.items, required this.windowId});

  @override
  State<StatefulWidget> createState() {
    return _RuleAddDialogState();
  }
}

class _RuleAddDialogState extends State<RuleAddDialog> {
  late ValueNotifier<bool> enableNotifier;
  late RequestRewriteRule rule;
  List<RewriteItem>? items;

  late RuleType ruleType;
  late TextEditingController nameInput;
  late TextEditingController urlInput;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    rule = widget.rule ??
        RequestRewriteRule(url: '', type: RuleType.responseReplace);
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
    bool isCN = Localizations.localeOf(context) ==
        const Locale.fromSubtags(languageCode: 'zh');

    return AlertDialog(
        scrollable: true,
        title: Row(children: [
          Text(localizations.requestRewriteRule,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 20),
          Text.rich(TextSpan(
              text: localizations.useGuide,
              style: const TextStyle(color: Colors.blue, fontSize: 14),
              recognizer: TapGestureRecognizer()
                ..onTap = () => DesktopMultiWindow.invokeMethod(
                    0,
                    "launchUrl",
                    isCN
                        ? 'https://gitee.com/wanghongenpin/network-proxy-flutter/wikis/%E8%AF%B7%E6%B1%82%E9%87%8D%E5%86%99'
                        : 'https://github.com/wanghongenpin/network_proxy_flutter/wiki/Request-Rewrite'))),
        ]),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        content: Container(
            constraints: const BoxConstraints(
                minWidth: 350, minHeight: 200, maxWidth: 500),
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
                                title: Text(localizations.enable),
                                value: enable,
                                onChanged: (value) =>
                                    enableNotifier.value = value);
                          }),
                      const SizedBox(height: 5),
                      textField('${localizations.name}:', nameInput,
                          localizations.pleaseEnter),
                      const SizedBox(height: 10),
                      textField(
                          'URL:', urlInput, 'http://www.example.com/api/*',
                          required: true),
                      const SizedBox(height: 10),
                      Row(children: [
                        SizedBox(
                            width: 60, child: Text('${localizations.action}:')),
                        SizedBox(
                            width: 150,
                            height: 33,
                            child: DropdownButtonFormField<RuleType>(
                              onSaved: (val) => rule.type = val!,
                              validator: (val) =>
                                  items == null || items!.isEmpty ? "" : null,
                              value: ruleType,
                              decoration: InputDecoration(
                                  errorStyle:
                                      const TextStyle(height: 0, fontSize: 0),
                                  contentPadding:
                                      const EdgeInsets.only(left: 7, right: 7),
                                  focusedBorder: focusedBorder(),
                                  border: const OutlineInputBorder()),
                              items: RuleType.values
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(isCN ? e.label : e.name,
                                          style:
                                              const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                ruleType = val!;
                                items = ruleType == widget.rule?.type
                                    ? widget.items
                                    : [];
                              },
                            )),
                        const SizedBox(width: 10),
                        TextButton(
                            onPressed: () => showEdit(rule),
                            child: Text(localizations.clickEdit)),
                      ]),
                      const SizedBox(height: 10),
                      Padding(
                          padding: const EdgeInsets.only(left: 60),
                          child: getDescribe()),
                    ]))),
        actions: [
          ElevatedButton(
              child: Text(localizations.close),
              onPressed: () => Navigator.of(context).pop()),
          FilledButton(
              child: Text(localizations.save),
              onPressed: () async {
                if (!(formKey.currentState as FormState).validate()) {
                  FlutterToastr.show(localizations.cannotBeEmpty, context,
                      position: FlutterToastr.center);
                  return;
                }

                (formKey.currentState as FormState).save();
                rule.enabled = enableNotifier.value;
                rule.name = nameInput.text;
                rule.url = urlInput.text;

                var requestRewrites = await RequestRewrites.instance;
                requestRewrites.rewriteItemsCache[rule] = items!;
                var index = requestRewrites.rules.indexOf(rule);

                if (index >= 0) {
                  //存在 更新重写
                  MultiWindow.invokeRefreshRewrite(Operation.update,
                      index: index, rule: rule, items: items);
                } else {
                  //添加
                  if (widget.windowId != null) {
                    requestRewrites.rules.add(rule);
                  }

                  MultiWindow.invokeRefreshRewrite(Operation.add,
                      rule: rule, items: items);
                }
                if (mounted) {
                  Navigator.of(this.context).pop(rule);
                }
              })
        ]);
  }

  Widget getDescribe() {
    bool isCN = localizations.localeName == 'zh';

    if (items?.isNotEmpty == true &&
        (ruleType == RuleType.requestReplace ||
            ruleType == RuleType.responseReplace)) {
      return Text(
          "${localizations.replace}: ${items?.where((it) => it.enabled).map((e) => e.type.getDescribe(isCN)).join(" ")}",
          style: const TextStyle(color: Colors.grey));
    }

    if (ruleType == RuleType.requestUpdate ||
        ruleType == RuleType.responseUpdate) {
      return Text(localizations.itemUpdate(items?.length ?? 0),
          style: const TextStyle(color: Colors.grey));
    }
    return const SizedBox();
  }

  void showEdit(RequestRewriteRule rule) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => ruleType == RuleType.requestUpdate ||
              ruleType == RuleType.responseUpdate
          ? RewriteUpdateDialog(
              subtitle: urlInput.text, items: items, ruleType: ruleType)
          : RewriteReplaceDialog(
              windowId: widget.windowId,
              subtitle: urlInput.text,
              items: items,
              ruleType: ruleType),
    ).then((value) {
      if (value is List<RewriteItem>) {
        setState(() {
          items = value;
        });
      }
    });
  }

  Widget textField(String label, TextEditingController controller, String hint,
      {bool required = false, FormFieldSetter<String>? onSaved}) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label)),
      Expanded(
          child: TextFormField(
        controller: controller,
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
    return OutlineInputBorder(
        borderSide:
            BorderSide(color: Theme.of(context).colorScheme.primary, width: 2));
  }
}
