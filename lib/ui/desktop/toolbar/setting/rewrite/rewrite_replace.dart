import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/utils/lang.dart';

/// 重写替换
class RewriteReplaceDialog extends StatefulWidget {
  final String subtitle;
  final RuleType ruleType;
  final List<RewriteItem>? items;

  const RewriteReplaceDialog({super.key, required this.subtitle, this.items, required this.ruleType});

  @override
  State<RewriteReplaceDialog> createState() => _RewriteReplaceState();
}

class _RewriteReplaceState extends State<RewriteReplaceDialog> {
  final _headerKey = GlobalKey<HeadersState>();

  List<RewriteItem> items = [];

  @override
  initState() {
    super.initState();
    if (widget.ruleType== RuleType.redirect) {
      initRewriteItem(RewriteType.redirect, enabled: true);
      return;
    }

    if (widget.ruleType == RuleType.requestReplace) {
      initRewriteItem(RewriteType.replaceRequestLine);
      initRewriteItem(RewriteType.replaceRequestHeader);
      initRewriteItem(RewriteType.replaceRequestBody, enabled: true);
      return;
    }

    if (widget.ruleType == RuleType.responseReplace) {
      initRewriteItem(RewriteType.replaceResponseStatus);
      initRewriteItem(RewriteType.replaceResponseHeader);
      initRewriteItem(RewriteType.replaceResponseBody, enabled: true);
      return;
    }
  }

  initRewriteItem(RewriteType type, {bool enabled = false}) {
    var item = widget.items?.firstWhereOrNull((it) => it.type == type);
    RewriteItem rewriteItem = RewriteItem(type, item?.enabled ?? enabled, values: item?.values);
    items.add(rewriteItem);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        actionsPadding: const EdgeInsets.only(right: 10, bottom: 10),
        contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("关闭")),
          TextButton(
              onPressed: () {
                var headers = _headerKey.currentState?.getHeaders();
                if (headers != null) {
                  items
                      .firstWhere((item) =>
                          item.type == RewriteType.replaceRequestHeader ||
                          item.type == RewriteType.replaceResponseHeader)
                      .headers = headers;
                }
                Navigator.of(context).pop(items);
              },
              child: const Text("完成")),
        ],
        title: ListTile(
            title: Text(widget.ruleType.label,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(widget.subtitle.substring(0, min(widget.subtitle.length, 50)),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        content: rewriteWidgets());
  }

  ///重写
  Widget rewriteWidgets() {
    if (widget.ruleType == RuleType.redirect) {
      return SizedBox(width: 500, height: 120, child: redirectEdit(items.first));
    }

    if (widget.ruleType == RuleType.responseReplace || widget.ruleType == RuleType.requestReplace) {
      bool requestEdited = widget.ruleType == RuleType.requestReplace;
      List<String> tabs = requestEdited ? ["请求行", "请求头", "请求体"] : ["状态码", "响应头", "响应体"];

      return SizedBox(
        width: 500,
        height: 340,
        child: DefaultTabController(
            length: tabs.length,
            initialIndex: tabs.length - 1,
            child: Scaffold(
              appBar: tabBar(tabs),
              body: TabBarView(children: [
                KeepAliveWrapper(
                    child: Container(
                  padding: const EdgeInsets.all(10),
                  child: requestEdited ? requestLine() : statusCodeEdit(),
                )),
                KeepAliveWrapper(child: Container(padding: const EdgeInsets.all(10), child: headers())),
                KeepAliveWrapper(child: Container(padding: const EdgeInsets.all(10), child: body()))
              ]),
            )),
      );
    }

    return Container();
  }

  //tabBar
  TabBar tabBar(List<String> tabs) {
    return TabBar(
        tabs: tabs
            .map((label) => Tab(
                height: 38,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 5),
                  Dot(color: items[tabs.indexOf(label)].enabled ? const Color(0xFF00FF00) : Colors.grey)
                ])))
            .toList());
  }

  //body
  Widget body() {
    var rewriteItem = items.firstWhere(
        (item) => item.type == RewriteType.replaceRequestBody || item.type == RewriteType.replaceResponseBody);

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(width: 10),
        Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('启用'),
          const SizedBox(width: 10),
          SwitchWidget(
              value: rewriteItem.enabled,
              scale: 0.65,
              onChanged: (val) => setState(() {
                    rewriteItem.enabled = val;
                  }))
        ]))
      ]),
      const SizedBox(height: 5),
      TextFormField(
          initialValue: rewriteItem.body,
          style: const TextStyle(fontSize: 14),
          maxLines: 10,
          decoration: decoration('消息体替换为:', hintText: '示例: {"code":"200","data":{}}'),
          onChanged: (val) => rewriteItem.body = val)
    ]);
  }

  //headers
  Widget headers() {
    var rewriteItem = items.firstWhere(
        (item) => item.type == RewriteType.replaceRequestHeader || item.type == RewriteType.replaceResponseHeader);

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('Header列表'),
        const SizedBox(width: 10),
        Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('启用'),
          const SizedBox(width: 10),
          SwitchWidget(
              value: rewriteItem.enabled,
              scale: 0.65,
              onChanged: (val) => setState(() {
                    rewriteItem.enabled = val;
                  }))
        ]))
      ]),
      Headers(headers: rewriteItem.headers, key: _headerKey)
    ]);
  }

  ///请求行
  Widget requestLine() {
    var rewriteItem = items.firstWhere((item) => item.type == RewriteType.replaceRequestLine);
    return Column(
      children: [
        Row(children: [
          const Text('请求方法'),
          const SizedBox(width: 10),
          SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                  value: rewriteItem.method?.name ?? 'GET',
                  focusColor: Colors.transparent,
                  itemHeight: 48,
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(10), isDense: true, border: InputBorder.none),
                  items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS']
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      rewriteItem.values['method'] = val!;
                    });
                  })),
          Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('启用'),
            const SizedBox(width: 10),
            SwitchWidget(
                value: rewriteItem.enabled,
                scale: 0.65,
                onChanged: (val) {
                  setState(() {
                    rewriteItem.enabled = val;
                  });
                })
          ])),
        ]),
        const SizedBox(height: 15),
        textField("Path", rewriteItem.path, "示例: /api/v1/user", onChanged: (val) => rewriteItem.values['path'] = val),
        const SizedBox(height: 15),
        textField("URL参数", rewriteItem.queryParam, "示例: id=1&name=2", onChanged: (val) => rewriteItem.queryParam = val),
      ],
    );
  }

  //重定向
  Widget redirectEdit(RewriteItem rewriteItem) {
    return TextFormField(
        decoration: decoration('重定向到:', hintText: 'http://www.example.com/api'),
        maxLines: 3,
        style: const TextStyle(fontSize: 14),
        initialValue: rewriteItem.redirectUrl,
        onChanged: (val) => rewriteItem.redirectUrl = val,
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return '重定向URL不能为空';
          }
          return null;
        });
  }

  Widget textField(String label, dynamic value, String hint, {ValueChanged<String>? onChanged}) {
    return Row(children: [
      SizedBox(width: 80, child: Text(label)),
      Expanded(
          child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
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
    var rewriteItem = items.firstWhere((item) => item.type == RewriteType.replaceResponseStatus);

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
                  initialValue: rewriteItem.statusCode?.toString(),
                  onChanged: (val) => rewriteItem.statusCode = int.tryParse(val),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(10),
                      focusedBorder: focusedBorder(),
                      isDense: true,
                      border: const OutlineInputBorder()),
                )),
            Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('启用'),
              const SizedBox(width: 10),
              SwitchWidget(
                  value: rewriteItem.enabled,
                  scale: 0.65,
                  onChanged: (val) => setState(() {
                        rewriteItem.enabled = val;
                      }))
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
