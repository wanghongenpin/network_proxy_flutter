import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/http_client.dart';

class MobileRequestEditor extends StatefulWidget {
  final HttpRequest? request;
  final ProxyServer proxyServer;

  const MobileRequestEditor({super.key, this.request, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return RequestEditorState();
  }
}

class RequestEditorState extends State<MobileRequestEditor> {
  final requestLineKey = GlobalKey<_RequestLineState>();
  final headerKey = GlobalKey<HeadersState>();

  String requestBody = "";

  @override
  void initState() {
    super.initState();
    requestBody = widget.request?.bodyAsString ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("编辑请求", style: TextStyle(fontSize: 16)),
          centerTitle: true,
          leading: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("取消", style: Theme.of(context).textTheme.bodyMedium)),
          actions: [TextButton.icon(icon: const Icon(Icons.send), label: const Text("发送"), onPressed: sendRequest)],
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RequestLine(request: widget.request, key: requestLineKey), // 请求行
              Headers(headers: widget.request?.headers, key: headerKey), // 请求头
              const SizedBox(height: 10),
              const Text("Body", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue)),
              body()
            ])));
  }

  ///发送请求
  sendRequest() {
    if (!widget.proxyServer.isRunning) {
      FlutterToastr.show('代理服务未启动', context);
      return;
    }

    var currentState = requestLineKey.currentState!;
    HttpRequest request = HttpRequest(HttpMethod.valueOf(currentState.requestMethod), currentState.requestUrl);
    var headers = headerKey.currentState?.getHeaders();
    request.headers.addAll(headers);
    request.body = requestBody.codeUnits;
    HttpClients.proxyRequest("127.0.0.1", widget.proxyServer.port, request);
    FlutterToastr.show('已重新发送请求', context);
    Navigator.pop(context, request);
  }

  ///请求体
  Widget body() {
    return TextField(
        controller: TextEditingController(text: requestBody),
        onChanged: (value) {
          requestBody = value;
        },
        minLines: 3,
        maxLines: 10);
  }
}

class _RequestLine extends StatefulWidget {
  final HttpRequest? request;

  const _RequestLine({this.request, super.key});

  @override
  State<StatefulWidget> createState() {
    return _RequestLineState();
  }
}

class _RequestLineState extends State<_RequestLine> {
  String requestUrl = "";
  String requestMethod = HttpMethod.get.name;

  @override
  void initState() {
    super.initState();
    if (widget.request == null) {
      return;
    }
    var request = widget.request!;
    requestUrl = request.requestUrl;
    requestMethod = request.method.name;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        style: const TextStyle(fontSize: 14),
        minLines: 1,
        maxLines: 5,
        decoration: InputDecoration(
            prefix: DropdownButton(
              padding: const EdgeInsets.only(right: 10),
              underline: const SizedBox(),
              isDense: true,
              focusColor: Colors.transparent,
              value: requestMethod,
              items: HttpMethod.values
                  .map((it) =>
                      DropdownMenuItem(value: it.name, child: Text(it.name, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  requestMethod = value!;
                });
              },
            ),
            isDense: true,
            border: const OutlineInputBorder(borderSide: BorderSide()),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey, width: 0.3))),
        controller: TextEditingController(text: requestUrl),
        onChanged: (value) {
          requestUrl = value;
        });
  }
}

class Headers extends StatefulWidget {
  final HttpHeaders? headers;

  const Headers({super.key, this.headers});

  @override
  State<StatefulWidget> createState() {
    return HeadersState();
  }
}

class HeadersState extends State<Headers> {
  Map<String, List<String>> headers = {};

  @override
  void initState() {
    super.initState();
    if (widget.headers == null) {
      return;
    }
    widget.headers?.forEach((name, values) {
      headers[name] = values;
    });
  }

  HttpHeaders getHeaders() {
    var headers = HttpHeaders();
    this.headers.forEach((key, values) {
      if (key.isNotEmpty) {
        headers.addValues(key, values);
      }
    });
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(
              width: double.infinity,
              child: Text("Headers", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue))),
          const SizedBox(height: 10),
          ...buildHeaders(),
          Container(
              alignment: Alignment.center,
              child: TextButton(
                  onPressed: () {
                    modifyHeader("", "");
                  },
                  child: const Text("添加Header", textAlign: TextAlign.center))) //添加按钮
        ]));
  }

  List<Widget> buildHeaders() {
    List<Widget> list = [];
    headers.forEach((key, values) {
      for (var val in values) {
        var header = row(Text(key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(val, style: const TextStyle(fontSize: 12), maxLines: 5, overflow: TextOverflow.ellipsis));
        var ink = InkWell(
            onTap: () => modifyHeader(key, val),
            onLongPress: () => deleteHeader(key),
            child: Padding(padding: const EdgeInsets.only(top: 5, bottom: 5), child: header));
        list.add(ink);
        list.add(const Divider(thickness: 0.2));
      }
    });
    return list;
  }

  /// 修改请求头
  modifyHeader(String key, String val) {
    String headerName = key;
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            titlePadding: const EdgeInsets.only(left: 25, top: 10),
            actionsPadding: const EdgeInsets.only(right: 10, bottom: 10),
            title: const Text("修改请求头", style: TextStyle(fontSize: 18)),
            content: Wrap(
              children: [
                TextField(
                  minLines: 1,
                  maxLines: 3,
                  controller: TextEditingController(text: headerName),
                  decoration: const InputDecoration(labelText: "请求头名称"),
                  onChanged: (value) {
                    headerName = value;
                  },
                ),
                TextField(
                  minLines: 1,
                  maxLines: 8,
                  controller: TextEditingController(text: val),
                  decoration: const InputDecoration(labelText: "请求头值"),
                  onChanged: (value) {
                    val = value;
                  },
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("取消")),
              TextButton(
                  onPressed: () {
                    setState(() {
                      if (headerName != key) {
                        headers.remove(key);
                      }

                      headers[headerName] = [val];
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("修改")),
            ],
          );
        });
  }

  //删除
  deleteHeader(String key) {
    HapticFeedback.heavyImpact();
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text("是否删除该请求头？", style: TextStyle(fontSize: 18)),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("取消")),
              TextButton(
                  onPressed: () {
                    setState(() {
                      headers.remove(key);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("删除")),
            ],
          );
        });
  }

  Widget row(Widget title, Widget child) {
    return Row(children: [
      Expanded(flex: 3, child: title),
      const SizedBox(width: 10, child: Text(":", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600))),
      Expanded(
        flex: 6,
        child: child,
      ),
    ]);
  }
}
