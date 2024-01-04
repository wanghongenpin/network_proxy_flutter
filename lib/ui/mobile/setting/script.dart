import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:network_proxy/network/components/script_manager.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// @author wanghongen
/// 2023/10/19
/// js脚本
class MobileScript extends StatefulWidget {
  const MobileScript({super.key});

  @override
  State<StatefulWidget> createState() => _MobileScriptState();
}

bool _refresh = false;

/// 刷新脚本
void _refreshScript() {
  if (_refresh) {
    return;
  }
  _refresh = true;
  Future.delayed(const Duration(milliseconds: 1500), () async {
    _refresh = false;
    (await ScriptManager.instance).flushConfig();
  });
}

class _MobileScriptState extends State<MobileScript> {
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(localizations.script, style: const TextStyle(fontSize: 16))),
        body: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10),
            child: futureWidget(
                ScriptManager.instance,
                loading: true,
                (data) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Row(children: [
                            SizedBox(
                                width: 300,
                                child: SwitchWidget(
                                  title: localizations.enableScript,
                                  subtitle: localizations.scriptUseDescribe,
                                  value: data.enabled,
                                  onChanged: (value) {
                                    data.enabled = value;
                                    _refreshScript();
                                  },
                                )),
                          ]),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const SizedBox(width: 10),
                              FilledButton(
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.only(left: 20, right: 20)),
                                onPressed: scriptEdit,
                                child: Text(localizations.add),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.only(left: 20, right: 20)),
                                onPressed: import,
                                child: Text(localizations.import),
                              ),
                              const SizedBox(width: 15),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(
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
                                    Container(
                                        width: 100,
                                        padding: const EdgeInsets.only(left: 10),
                                        child: Text(localizations.name)),
                                    SizedBox(width: 50, child: Text(localizations.enable, textAlign: TextAlign.center)),
                                    const VerticalDivider(),
                                    const Expanded(child: Text("URL")),
                                  ],
                                ),
                                const Divider(thickness: 0.5),
                                ScriptList(scripts: data.list),
                              ]))),
                        ]))));
  }

  //导入js
  import() async {
    final XFile? file = await openFile();
    if (file == null) {
      return;
    }

    try {
      var json = jsonDecode(utf8.decode(await file.readAsBytes()));
      var scriptItem = ScriptItem.fromJson(json);
      (await ScriptManager.instance).addScript(scriptItem, json['script']);
      _refreshScript();
      if (context.mounted) {
        FlutterToastr.show(localizations.importSuccess, context);
      }
      setState(() {});
    } catch (e, t) {
      logger.e('导入失败 $file', error: e, stackTrace: t);
      if (context.mounted) {
        FlutterToastr.show("${localizations.importFailed} $e", context);
      }
    }
  }

  /// 添加脚本
  scriptEdit() async {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ScriptEdit())).then((value) {
      if (value != null) {
        setState(() {});
      }
    });
  }
}

/// 编辑脚本
class ScriptEdit extends StatefulWidget {
  final ScriptItem? scriptItem;
  final String? script;

  const ScriptEdit({super.key, this.scriptItem, this.script});

  @override
  State<StatefulWidget> createState() => _ScriptEditState();
}

class _ScriptEditState extends State<ScriptEdit> {
  late CodeController script;
  late TextEditingController nameController;
  late TextEditingController urlController;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    script = CodeController(language: javascript, text: widget.script ?? ScriptManager.template);
    nameController = TextEditingController(text: widget.scriptItem?.name);
    urlController = TextEditingController(text: widget.scriptItem?.url);
  }

  @override
  void dispose() {
    script.dispose();
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey formKey = GlobalKey<FormState>();
    return Scaffold(
        appBar: AppBar(
            title: Row(children: [
              Text(localizations.scriptEdit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              Text.rich(TextSpan(
                  text: localizations.useGuide,
                  style: const TextStyle(color: Colors.blue, fontSize: 14),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                        Uri.parse('https://gitee.com/wanghongenpin/network-proxy-flutter/wikis/%E8%84%9A%E6%9C%AC')))),
            ]),
            actions: [
              TextButton(
                  onPressed: () async {
                    if (!(formKey.currentState as FormState).validate()) {
                      FlutterToastr.show("${localizations.name} URL ${localizations.cannotBeEmpty}", context,
                          position: FlutterToastr.top);
                      return;
                    }
                    //新增
                    var scriptManager = await ScriptManager.instance;
                    if (widget.scriptItem == null) {
                      var scriptItem = ScriptItem(true, nameController.text, urlController.text);
                      await scriptManager.addScript(scriptItem, script.text);
                    } else {
                      widget.scriptItem?.name = nameController.text;
                      widget.scriptItem?.url = urlController.text;
                      widget.scriptItem?.urlReg = null;
                      await scriptManager.updateScript(widget.scriptItem!, script.text);
                    }

                    _refreshScript();
                    if (context.mounted) {
                      Navigator.of(context).maybePop(true);
                    }
                  },
                  child: Text(localizations.save)),
            ]),
        body: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10, bottom: 20),
            child: Form(
                key: formKey,
                child: ListView(
                  children: [
                    textField("${localizations.name}:", nameController, localizations.pleaseEnter),
                    const SizedBox(height: 10),
                    textField("URL:", urlController, "github.com/api/*", keyboardType: TextInputType.url),
                    const SizedBox(height: 10),
                    Text("${localizations.script}:"),
                    const SizedBox(height: 5),
                    CodeTheme(
                        data: CodeThemeData(styles: monokaiSublimeTheme),
                        child: SingleChildScrollView(
                            child: CodeField(textStyle: const TextStyle(fontSize: 14), controller: script)))
                  ],
                ))));
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

/// 脚本列表
class ScriptList extends StatefulWidget {
  final List<ScriptItem> scripts;

  const ScriptList({super.key, required this.scripts});

  @override
  State<ScriptList> createState() => _ScriptListState();
}

class _ScriptListState extends State<ScriptList> {
  int selected = -1;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Column(children: rows(widget.scripts));
  }

  List<Widget> rows(List<ScriptItem> list) {
    var primaryColor = Theme.of(context).primaryColor;

    return List.generate(list.length, (index) {
      return InkWell(
          splashColor: primaryColor.withOpacity(0.3),
          onTap: () async {
            String script = await (await ScriptManager.instance).getScript(list[index]);
            if (!context.mounted) {
              return;
            }
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => ScriptEdit(scriptItem: list[index], script: script)))
                .then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          },
          onLongPress: () => showMenus(index),
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
                      width: 100,
                      child: Text(list[index].name!,
                          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  SizedBox(
                      width: 50,
                      child: Transform.scale(
                          scale: 0.65,
                          child: SwitchWidget(
                              value: list[index].enabled,
                              onChanged: (val) {
                                list[index].enabled = val;
                                _refreshScript();
                              }))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(list[index].url, style: const TextStyle(fontSize: 13))),
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
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        enableDrag: true,
        builder: (context) {
          return Wrap(
            alignment: WrapAlignment.center,
            children: [
              BottomSheetItem(
                  text: localizations.edit,
                  onPressed: () async {
                    String script = await (await ScriptManager.instance).getScript(widget.scripts[index]);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (context) => ScriptEdit(scriptItem: widget.scripts[index], script: script)))
                        .then((value) {
                      if (value != null) {
                        setState(() {});
                      }
                    });
                  }),
              const Divider(thickness: 0.5, height: 1),
              BottomSheetItem(
                  text: localizations.share,
                  onPressed: () {
                    export(widget.scripts[index]);
                  }),
              const Divider(thickness: 0.5, height: 1),
              BottomSheetItem(
                  text: widget.scripts[index].enabled ? localizations.disabled : localizations.enable,
                  onPressed: () {
                    widget.scripts[index].enabled = !widget.scripts[index].enabled;
                    _refreshScript();
                  }),
              const Divider(thickness: 0.5, height: 1),
              BottomSheetItem(
                  text: localizations.delete,
                  onPressed: () async {
                    await (await ScriptManager.instance).removeScript(index);
                    _refreshScript();
                    if (context.mounted) FlutterToastr.show(localizations.importSuccess, context);
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
                },
              ),
            ],
          );
        }).then((value) {
      setState(() {
        selected = -1;
      });
    });
  }

  //导出js
  export(ScriptItem item) async {
    //文件名称
    String fileName = '${item.name}.json';
    var json = item.toJson();
    json.remove("scriptPath");
    json['script'] = await (await ScriptManager.instance).getScript(item);
    final XFile file = XFile.fromData(utf8.encode(jsonEncode(json)), mimeType: 'json');
    Share.shareXFiles([file], subject: fileName);
  }
}
