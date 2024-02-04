import 'dart:collection';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/mobile/setting/rewrite/rewrite_update.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rewrite/rewrite_replace.dart';

class MobileRequestRewrite extends StatefulWidget {
  final RequestRewrites requestRewrites;

  const MobileRequestRewrite({super.key, required this.requestRewrites});

  @override
  State<MobileRequestRewrite> createState() => _MobileRequestRewriteState();
}

class _MobileRequestRewriteState extends State<MobileRequestRewrite> {
  bool enabled = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
        appBar: AppBar(
            centerTitle: true, title: Text(localizations.requestRewriteList, style: const TextStyle(fontSize: 16))),
        body: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(localizations.requestRewriteEnable),
                    SwitchWidget(value: enabled, scale: 0.8, onChanged: (val) => enabled = val),
                  ],
                ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18), onPressed: add, label: Text(localizations.add)),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.input_rounded, size: 18),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.only(left: 20, right: 20)),
                    onPressed: import,
                    label: Text(localizations.import),
                  ),
                ]),
                const SizedBox(height: 10),
                Expanded(child: RequestRuleList(widget.requestRewrites)),
              ],
            )));
  }

  //导入
  import() async {
    final XFile? file = await openFile();
    if (file == null) {
      return;
    }

    try {
      List json = jsonDecode(utf8.decode(await file.readAsBytes()));

      for (var item in json) {
        var rule = RequestRewriteRule.formJson(item);
        var items = (item['items'] as List).map((e) => RewriteItem.fromJson(e)).toList();
        await widget.requestRewrites.addRule(rule, items);
      }
      widget.requestRewrites.flushRequestRewriteConfig();

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
  Set<int> selected = HashSet<int>();
  late List<RequestRewriteRule> rules;
  bool changed = false;

  bool multiple = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
    return Scaffold(
        persistentFooterButtons: [multiple ? globalMenu() : const SizedBox()],
        body: Container(
            padding: const EdgeInsets.only(top: 10, bottom: 30),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2))),
            child: Scrollbar(
                child: ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(width: 80, padding: const EdgeInsets.only(left: 10), child: Text(localizations.name)),
                    SizedBox(width: 46, child: Text(localizations.enable, textAlign: TextAlign.center)),
                    const VerticalDivider(),
                    const Expanded(child: Text("URL")),
                    SizedBox(width: 60, child: Text(localizations.action, textAlign: TextAlign.center)),
                  ],
                ),
                const Divider(thickness: 0.5),
                Column(children: rows(widget.requestRewrites.rules))
              ],
            ))));
  }

  globalMenu() {
    return Stack(children: [
      Container(
          height: 50,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2)))),
      Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
              child: TextButton(
                  onPressed: () {},
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton.icon(
                        onPressed: () {
                          export(selected.toList());
                          setState(() {
                            selected.clear();
                            multiple = false;
                          });
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(localizations.export, style: const TextStyle(fontSize: 14))),
                    TextButton.icon(
                        onPressed: () => removeRewrite(),
                        icon: const Icon(Icons.delete, size: 18),
                        label: Text(localizations.delete, style: const TextStyle(fontSize: 14))),
                    TextButton.icon(
                        onPressed: () {
                          setState(() {
                            multiple = false;
                            selected.clear();
                          });
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: Text(localizations.cancel, style: const TextStyle(fontSize: 14))),
                  ]))))
    ]);
  }

  List<Widget> rows(List<RequestRewriteRule> list) {
    var primaryColor = Theme.of(context).colorScheme.primary;
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');
    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onLongPress: () => showMenus(index),
          onTap: () async {
            if (multiple) {
              setState(() {
                if (!selected.add(index)) {
                  selected.remove(index);
                }
              });
              return;
            }
            showEdit(index);
          },
          child: Container(
              color: selected.contains(index)
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
                      width: 35,
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
                      child: Text(isCN ? list[index].type.label : list[index].type.name,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                ],
              )));
    });
  }

  showEdit(int index) async {
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
  }

  //点击菜单
  showMenus(int index) {
    setState(() {
      selected.add(index);
    });

    showModalBottomSheet(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        context: context,
        enableDrag: true,
        builder: (ctx) {
          return Wrap(alignment: WrapAlignment.center, children: [
            BottomSheetItem(
                text: localizations.multiple,
                onPressed: () {
                  setState(() => multiple = true);
                }),
            const Divider(thickness: 0.5, height: 5),
            BottomSheetItem(text: localizations.edit, onPressed: () => showEdit(index)),
            const Divider(thickness: 0.5, height: 5),
            BottomSheetItem(text: localizations.share, onPressed: () => export([index])),
            const Divider(thickness: 0.5, height: 5),
            BottomSheetItem(
                text: rules[index].enabled ? localizations.disabled : localizations.enable,
                onPressed: () {
                  rules[index].enabled = !rules[index].enabled;
                  changed = true;
                }),
            const Divider(thickness: 0.5, height: 5),
            BottomSheetItem(
                text: localizations.delete,
                onPressed: () async {
                  await widget.requestRewrites.removeIndex([index]);
                  widget.requestRewrites.flushRequestRewriteConfig();
                  if (mounted) FlutterToastr.show(localizations.deleteSuccess, context);
                }),
            Container(color: Theme.of(context).hoverColor, height: 8),
            TextButton(
                child: Container(
                    height: 50,
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(localizations.cancel, textAlign: TextAlign.center)),
                onPressed: () {
                  Navigator.of(context).pop();
                }),
          ]);
        }).then((value) {
      if (multiple) {
        return;
      }
      setState(() {
        selected.remove(index);
      });
    });
  }

  //导出js
  Future<void> export(List<int> indexes) async {
    if (indexes.isEmpty) return;
    String fileName = 'proxypin-rewrites.config';

    var list = [];
    for (var index in indexes) {
      var rule = widget.requestRewrites.rules[index];
      var json = rule.toJson();
      json.remove("rewritePath");
      json['items'] = await widget.requestRewrites.getRewriteItems(rule);
      list.add(json);
    }

    final XFile file = XFile.fromData(utf8.encode(jsonEncode(list)), mimeType: 'config');
    await Share.shareXFiles([file], subject: fileName);
  }

  //删除
  Future<void> removeRewrite() async {
    if (selected.isEmpty) return;
    return showConfirmDialog(context, content: localizations.requestRewriteDeleteConfirm(selected.length),
        onConfirm: () async {
      var list = selected.toList();
      list.sort((a, b) => b.compareTo(a));
      for (var value in list) {
        await widget.requestRewrites.removeIndex([value]);
      }
      widget.requestRewrites.flushRequestRewriteConfig();
      setState(() {
        multiple = false;
        selected.clear();
      });
      if (mounted) FlutterToastr.show(localizations.deleteSuccess, context);
    });
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

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(localizations.requestRewrite, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 15),
          Text.rich(TextSpan(
              text: localizations.useGuide,
              style: const TextStyle(color: Colors.blue, fontSize: 14),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(Uri.parse(isCN
                    ? 'https://gitee.com/wanghongenpin/network-proxy-flutter/wikis/%E8%AF%B7%E6%B1%82%E9%87%8D%E5%86%99'
                    : 'https://github.com/wanghongenpin/network_proxy_flutter/wiki/Request-Rewrite')))),
        ]),
        actions: [
          TextButton(
              child: Text(localizations.save),
              onPressed: () async {
                if (!(formKey.currentState as FormState).validate()) {
                  FlutterToastr.show(localizations.cannotBeEmpty, context, position: FlutterToastr.center);
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
                  FlutterToastr.show(localizations.saveSuccess, this.context);
                  Navigator.of(this.context).pop(rule);
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
                          title: Text(localizations.enable, textAlign: TextAlign.start),
                          value: enable,
                          onChanged: (value) => enableNotifier.value = value);
                    }),
                textField('${localizations.name}:', nameInput, localizations.pleaseEnter),
                textField('URL:', urlInput, 'http://www.example.com/api/*',
                    required: true, keyboardType: TextInputType.url),
                Row(children: [
                  SizedBox(
                      width: 58,
                      child: Text('${localizations.action}:',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  SizedBox(
                      width: 165,
                      height: 50,
                      child: DropdownButtonFormField<RuleType>(
                        onSaved: (val) => rule.type = val!,
                        validator: (val) => items == null || items!.isEmpty ? "" : null,
                        value: ruleType,
                        decoration: const InputDecoration(
                          errorStyle: TextStyle(height: 0, fontSize: 0),
                          contentPadding: EdgeInsets.only(),
                        ),
                        items: RuleType.values
                            .map((e) => DropdownMenuItem(value: e, child: Text(isCN ? e.label : e.name)))
                            .toList(),
                        onChanged: (val) {
                          ruleType = val!;
                          items = ruleType == widget.rule?.type ? widget.items : [];
                        },
                      )),
                  const SizedBox(width: 10),
                  TextButton(
                      onPressed: () => showEdit(rule),
                      child: Text(localizations.clickEdit, style: const TextStyle(fontSize: 16))),
                ]),
                const SizedBox(height: 10),
                Padding(padding: const EdgeInsets.only(left: 60), child: getDescribe()),
              ]))),
    );
  }

  Widget getDescribe() {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');
    if (items?.isNotEmpty == true && (ruleType == RuleType.requestReplace || ruleType == RuleType.responseReplace)) {
      return Text(
          "${localizations.replace}: ${items?.where((it) => it.enabled).map((e) => e.type.getDescribe(isCN)).join(" ")}",
          style: const TextStyle(color: Colors.grey));
    }

    if (ruleType == RuleType.requestUpdate || ruleType == RuleType.responseUpdate) {
      return Text(localizations.itemUpdate(items?.length ?? 0), style: const TextStyle(color: Colors.grey));
    }
    return const SizedBox();
  }

  void showEdit(RequestRewriteRule rule) async {
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (context) => ruleType == RuleType.requestUpdate || ruleType == RuleType.responseUpdate
                ? RewriteUpdateWidget(subtitle: urlInput.text, items: items, ruleType: ruleType)
                : RewriteReplaceWidget(subtitle: urlInput.text, items: items, ruleType: ruleType)))
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
      SizedBox(width: 58, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
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
