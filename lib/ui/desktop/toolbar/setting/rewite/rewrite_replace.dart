import 'package:flutter/material.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/ui/component/widgets.dart';

/// 重写替换
class RewriteReplaceDialog extends StatefulWidget {
  final RequestRewriteRule? rule;

  const RewriteReplaceDialog({super.key, this.rule});

  @override
  State<RewriteReplaceDialog> createState() => _RewriteReplaceState();
}

class _RewriteReplaceState extends State<RewriteReplaceDialog> {
  // final _formKey = GlobalKey<FormState>();
  late RequestRewriteRule rule;

  @override
  initState() {
    super.initState();
    rule = widget.rule ?? RequestRewriteRule(true, url: '', type: RuleType.responseReplace);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        actionsPadding: const EdgeInsets.only(right: 10, bottom: 10),
        contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop(rule);
              },
              child: const Text("完成")),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("关闭"))
        ],
        title: ListTile(
            title: Text(rule.type.label,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle:
                Text(rule.url, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        content: SizedBox(width: 500, height: 320, child: rewriteWidgets()));
  }

  Widget rewriteWidgets() {
    if (rule.type == RuleType.redirect) {
      return TextFormField(
          decoration: decoration('重定向到:', hintText: 'http://www.example.com/api'),
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          initialValue: rule.redirectUrl,
          onSaved: (val) => rule.redirectUrl = val,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return '重定向URL不能为空';
            }
            return null;
          });
    }

    if (rule.type == RuleType.responseReplace || rule.type == RuleType.requestReplace) {
      List tabs = rule.type == RuleType.responseReplace ? ["状态码", "响应头", "响应体"] : ["请求行", "请求头", "请求体"];
      return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: TabBar(
              tabs: tabs
                  .map((label) => Tab(
                      height: 38,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 5),
                        const Dot()
                      ])))
                  .toList()),
          body: TabBarView(children: [
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(children: [
                    const Text('请求方法'),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                            value: 'GET',
                            focusColor: Colors.transparent,
                            itemHeight: 48,
                            decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(10), isDense: true, border: InputBorder.none),
                            items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS']
                                .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))))
                                .toList(),
                            onChanged: (val) {})),
                    Expanded(
                        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      const Text('启用'),
                      const SizedBox(width: 10),
                      SwitchWidget(value: true, scale: 0.65, onChanged: (val) {})
                    ])),
                  ]),
                  const SizedBox(height: 15),
                  textField("Path", "", "示例: /api/v1/user"),
                  const SizedBox(height: 15),
                  textField("URL参数", rule.queryParam, "示例: id=1&name=2"),
                ],
              ),
            ),
            Container(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('响应头列表'),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          const Text('启用'),
                          const SizedBox(width: 10),
                          SwitchWidget(value: true, scale: 0.65, onChanged: (val) {})
                        ]))
                      ]),
                  const Headers()
                ])),
            Container(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  Row(children: [
                    // const Text('类型'),
                    // const SizedBox(width: 10), //文本或文件
                    // SizedBox(
                    //     width: 80,
                    //     child: DropdownButtonFormField<String>(
                    //         value: '文本',
                    //         focusColor: Colors.transparent,
                    //         itemHeight: 48,
                    //         decoration: const InputDecoration(
                    //             contentPadding: EdgeInsets.all(10), isDense: true, border: InputBorder.none),
                    //         items: ['文本', '文件']
                    //             .map((e) => DropdownMenuItem(
                    //                 value: e,
                    //                 child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))))
                    //             .toList(),
                    //         onChanged: (val) {})),
                    Expanded(
                        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      const Text('启用'),
                      const SizedBox(width: 10),
                      SwitchWidget(value: true, scale: 0.65, onChanged: (val) {})
                    ])),
                  ]),
                  const SizedBox(height: 5),
                  TextFormField(
                      initialValue: rule.responseBody,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 10,
                      decoration: decoration('响应体替换为:', hintText: '示例: {"code":"200","data":{}}'),
                      onSaved: (val) => rule.responseBody = val)
                ]))
          ]),
        ),
      );
    }

    return Container();
    // return [
    //   TextFormField(
    //       initialValue: rule.queryParam,
    //       decoration: decoration('URL参数替换为:'),
    //       maxLines: 1,
    //       onSaved: (val) => rule.queryParam = val),
    //   const SizedBox(height: 5),
    //   TextFormField(
    //       initialValue: rule.requestBody,
    //       decoration: decoration('请求体替换为:'),
    //       minLines: 1,
    //       maxLines: 5,
    //       onSaved: (val) => rule.requestBody = val),
    //   const SizedBox(height: 5),
    //   TextFormField(
    //       initialValue: rule.responseBody,
    //       minLines: 3,
    //       maxLines: 10,
    //       decoration: decoration('响应体替换为:', hintText: '{"code":"200","data":{}}'),
    //       onSaved: (val) => rule.responseBody = val)
    // ];
  }

  Widget textField(String label, dynamic value, String hint) {
    return Row(children: [
      SizedBox(width: 80, child: Text(label)),
      Expanded(
          child: TextFormField(
        initialValue: value,
        validator: (val) => val?.isNotEmpty == true ? null : "",
        onChanged: (val) => value = val,
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

  Widget statusCodeEdit() {
    return Container(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Text('状态码'),
            const SizedBox(width: 10),
            SizedBox(
                width: 100,
                child: TextFormField(
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(10),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                      focusedBorder: focusedBorder(),
                      isDense: true,
                      border: const OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return '状态码不能为空';
                    }
                    return null;
                  },
                )),
            Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('启用'),
              const SizedBox(width: 10),
              SwitchWidget(value: true, scale: 0.65, onChanged: (val) {})
            ])),
            const SizedBox(width: 10),
          ])
        ]));
  }

  InputDecoration decoration(String label, {String? hintText}) {
    Color color = Theme.of(context).colorScheme.primary;
    // Color color = Colors.blueAccent;
    return InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: label,
        hintText: hintText,
        isDense: true,
        border: OutlineInputBorder(borderSide: BorderSide(width: 0.8, color: color)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.5, color: color)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2, color: color)));
  }

  InputBorder focusedBorder() {
    return OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2));
  }
}

///请求头
class Headers extends StatefulWidget {
  final Map<String, String>? headers;

  const Headers({super.key, this.headers});

  @override
  State<StatefulWidget> createState() {
    return HeadersState();
  }
}

class HeadersState extends State<Headers> with AutomaticKeepAliveClientMixin {
  final Map<TextEditingController, TextEditingController> _headers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.headers == null) {
      return;
    }
    widget.headers?.forEach((name, value) {
      _headers[TextEditingController(text: name)] = TextEditingController(text: value);
    });
  }

  ///获取所有请求头
  Map<String, String> getHeaders() {
    var headers = <String, String>{};
    _headers.forEach((name, value) {
      if (name.text.isEmpty) {
        return;
      }
      headers[name.text] = value.text;
    });
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    var list = [
      ..._buildRows(),
    ];

    list.add(TextButton(
      child: const Text("添加Header", textAlign: TextAlign.center),
      onPressed: () {
        setState(() {
          _headers[TextEditingController()] = TextEditingController();
        });
      },
    ));

    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ListView.separated(
            shrinkWrap: true,
            separatorBuilder: (context, index) =>
                index == list.length ? const SizedBox() : const Divider(thickness: 0.2),
            itemBuilder: (context, index) => list[index],
            itemCount: list.length));
  }

  List<Widget> _buildRows() {
    List<Widget> list = [];

    _headers.forEach((key, val) {
      list.add(_row(
          _cell(key, isKey: true),
          _cell(val),
          Padding(
              padding: const EdgeInsets.only(right: 15),
              child: InkWell(
                  onTap: () {
                    setState(() {
                      _headers.remove(key);
                    });
                  },
                  child: const Icon(Icons.remove_circle, size: 16)))));
    });

    return list;
  }

  Widget _cell(TextEditingController val, {bool isKey = false}) {
    return Container(
        padding: const EdgeInsets.only(right: 5),
        child: TextFormField(
            style: TextStyle(fontSize: 12, fontWeight: isKey ? FontWeight.w500 : null),
            controller: val,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: isKey ? "Key" : "Value")));
  }

  Widget _row(Widget key, Widget val, Widget? op) {
    return Row(children: [
      Expanded(flex: 4, child: key),
      const Text(": ", style: TextStyle(color: Colors.deepOrangeAccent)),
      Expanded(flex: 6, child: val),
      op ?? const SizedBox()
    ]);
  }
}
