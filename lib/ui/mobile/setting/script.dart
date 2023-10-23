import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/network/util/script_manager.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("脚本", style: TextStyle(fontSize: 16))),
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
                                  title: '启用脚本工具',
                                  subtitle: "使用 JavaScript 修改请求和响应",
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
                                child: const Text("添加"),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.only(left: 20, right: 20)),
                                onPressed: import,
                                child: const Text("导入"),
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
                                        width: 100, padding: const EdgeInsets.only(left: 10), child: const Text("名称")),
                                    const SizedBox(width: 50, child: Text("启用", textAlign: TextAlign.center)),
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
      var json = jsonDecode(await file.readAsString());
      var scriptItem = ScriptItem.fromJson(json);
      (await ScriptManager.instance).addScript(scriptItem, json['script']);
      _refreshScript();
      if (context.mounted) {
        FlutterToastr.show("导入成功", context);
      }
      setState(() {});
    } catch (e, t) {
      logger.e('导入失败 $file', error: e, stackTrace: t);
      if (context.mounted) {
        FlutterToastr.show("导入失败 $e", context);
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

  const ScriptEdit({Key? key, this.scriptItem, this.script}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ScriptEditState();
}

class _ScriptEditState extends State<ScriptEdit> {
  late CodeController script;
  late TextEditingController nameController;
  late TextEditingController urlController;

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
              const Text("编辑脚本", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              Text.rich(TextSpan(
                  text: '使用文档',
                  style: const TextStyle(color: Colors.blue, fontSize: 14),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                        Uri.parse('https://gitee.com/wanghongenpin/network-proxy-flutter/wikis/%E8%84%9A%E6%9C%AC')))),
            ]),
            actions: [
              TextButton(
                  onPressed: () async {
                    if (!(formKey.currentState as FormState).validate()) {
                      FlutterToastr.show("名称和URL不能为空", context, position: FlutterToastr.top);
                      return;
                    }
                    //新增
                    if (widget.scriptItem == null) {
                      var scriptItem = ScriptItem(true, nameController.text, urlController.text);
                      (await ScriptManager.instance).addScript(scriptItem, script.text);
                    } else {
                      widget.scriptItem?.name = nameController.text;
                      widget.scriptItem?.url = urlController.text;
                      widget.scriptItem?.urlReg = null;
                      (await ScriptManager.instance).updateScript(widget.scriptItem!, script.text);
                    }

                    _refreshScript();
                    if (context.mounted) {
                      Navigator.of(context).maybePop(true);
                    }
                  },
                  child: const Text("保存")),
            ]),
        body: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10, bottom: 20),
            child: Form(
                key: formKey,
                child: ListView(
                  children: [
                    textField("名称:", nameController, "请输入名称"),
                    const SizedBox(height: 10),
                    textField("URL:", urlController, "github.com/api/*", keyboardType: TextInputType.url),
                    const SizedBox(height: 10),
                    const Text("脚本:"),
                    const SizedBox(height: 5),
                    CodeTheme(
                        data: CodeThemeData(styles: monokaiSublimeTheme),
                        child: SingleChildScrollView(
                            child: CodeField(
                                textStyle: const TextStyle(fontSize: 14), controller: script)))
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
  @override
  Widget build(BuildContext context) {
    return Column(children: rows(widget.scripts));
  }

  List<Widget> rows(List<ScriptItem> list) {
    return List.generate(list.length, (index) {
      return InkWell(
          onDoubleTap: () async {
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
          onTapDown: (details) {
            showContextMenu(context, details.globalPosition, items: [
              PopupMenuItem(
                  height: 35,
                  child: const Text("编辑"),
                  onTap: () async {
                    String script = await (await ScriptManager.instance).getScript(list[index]);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (context) => ScriptEdit(scriptItem: list[index], script: script)))
                        .then((value) {
                      if (value != null) {
                        setState(() {});
                      }
                    });
                  }),
              PopupMenuItem(height: 35, child: const Text("分享"), onTap: () => export(list[index])),
              PopupMenuItem(
                  height: 35,
                  child: list[index].enabled ? const Text("禁用") : const Text("启用"),
                  onTap: () {
                    list[index].enabled = !list[index].enabled;
                    setState(() {});
                  }),
              const PopupMenuDivider(),
              PopupMenuItem(
                  height: 35,
                  child: const Text("删除"),
                  onTap: () async {
                    (await ScriptManager.instance).removeScript(index);
                    _refreshScript();
                    setState(() {});
                    if (context.mounted) FlutterToastr.show('删除成功', context);
                  }),
            ]);
          },
          child: Container(
              color: index.isEven ? Colors.grey.withOpacity(0.1) : null,
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
                          scale: 0.8,
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
