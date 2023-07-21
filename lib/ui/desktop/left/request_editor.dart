import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/http_client.dart';

class RequestEditor extends StatefulWidget {
  final WindowController? windowController;
  final HttpRequest? request;
  final int proxyPort;

  const RequestEditor({super.key, this.request, this.windowController, required this.proxyPort});

  @override
  State<StatefulWidget> createState() {
    return RequestEditorState();
  }
}

class RequestEditorState extends State<RequestEditor> {
  final requestLineKey = GlobalKey<_RequestLineState>();
  final headerKey = GlobalKey<HeadersState>();

  String requestBody = "";

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(onKeyEvent);
    requestBody = widget.request?.bodyAsString ?? '';
  }

  void onKeyEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.metaLeft) && event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      RawKeyboard.instance.removeListener(onKeyEvent);
      widget.windowController?.close();
      return;
    }
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("请求编辑", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          toolbarHeight: Platform.isWindows ? 36 : null,
          centerTitle: true,
          actions: [
            TextButton.icon(onPressed: () async => sendRequest(), icon: const Icon(Icons.send), label: const Text("发送"))
          ],
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _RequestLine(request: widget.request, key: requestLineKey), // 请求行
              Headers(headers: widget.request?.headers, key: headerKey), // 请求头
              const Text("Body", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue)),
              body() // 请求体
            ])));
  }

  ///发送请求
  sendRequest() async {
    var currentState = requestLineKey.currentState!;
    HttpRequest request = HttpRequest(HttpMethod.valueOf(currentState.requestMethod), currentState.requestUrl);
    var headers = headerKey.currentState?.getHeaders();
    request.headers.addAll(headers);
    request.body = requestBody.codeUnits;
    HttpClients.proxyRequest("127.0.0.1", widget.proxyPort, request);

    FlutterToastr.show('已重新发送请求', context);
    RawKeyboard.instance.removeListener(onKeyEvent);
    await Future.delayed(const Duration(milliseconds: 500), () => widget.windowController?.close());
  }

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

///请求行
class _RequestLine extends StatefulWidget {
  final HttpRequest? request;

  const _RequestLine({super.key, this.request});

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
        decoration: InputDecoration(
            prefix: DropdownButton(
              padding: const EdgeInsets.only(right: 10),
              underline: const SizedBox(),
              isDense: true,
              focusColor: Colors.transparent,
              value: requestMethod,
              items: HttpMethod.values.map((it) => DropdownMenuItem(value: it.name, child: Text(it.name))).toList(),
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

///请求头
class Headers extends StatefulWidget {
  final HttpHeaders? headers;

  const Headers({super.key, this.headers});

  @override
  State<StatefulWidget> createState() {
    return HeadersState();
  }
}

class HeadersState extends State<Headers> {
  Map<TextEditingController, List<TextEditingController>> headers = {};

  @override
  void initState() {
    super.initState();
    if (widget.headers == null) {
      return;
    }
    widget.headers?.forEach((name, values) {
      headers[TextEditingController(text: name)] = values.map((it) => TextEditingController(text: it)).toList();
    });
  }

  ///获取所有请求头
  HttpHeaders getHeaders() {
    var headers = HttpHeaders();
    this.headers.forEach((name, values) {
      if (name.text.isEmpty) {
        return;
      }
      for (var element in values) {
        if (element.text.isNotEmpty) {
          headers.add(name.text, element.text);
        }
      }
    });
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(
              width: double.infinity,
              child: Text("Headers", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue))),
          const SizedBox(height: 10),
          DataTable(
              dataRowMaxHeight: 38,
              dataRowMinHeight: 38,
              dividerThickness: 0.2,
              border: TableBorder.all(color: Theme.of(context).highlightColor),
              columns: const [
                DataColumn(label: Text('Key')),
                DataColumn(label: Text('Value')),
                DataColumn(label: Text(''))
              ],
              rows: buildRows()),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
                onPressed: () {
                  setState(() {
                    headers[TextEditingController()] = [TextEditingController()];
                  });
                },
                child: const Text("添加Header", textAlign: TextAlign.center))
          ]),
        ]));
  }

  List<DataRow> buildRows() {
    var width = MediaQuery.of(context).size.width;
    List<DataRow> list = [];

    headers.forEach((key, values) {
      for (var val in values) {
        list.add(DataRow(cells: [
          cell(key, width: 200, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          cell(val, width: width - 410),
          DataCell(InkWell(
              onTap: () {
                setState(() {
                  headers.remove(key);
                });
              },
              child: const Icon(Icons.remove_circle, size: 16)))
        ]));
      }
    });

    return list;
  }

  DataCell cell(TextEditingController val, {TextStyle? style = const TextStyle(fontSize: 14), double? width}) {
    return DataCell(SizedBox(
        width: width,
        child: TextFormField(
            style: style,
            controller: val,
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: "Header"))));
  }
}
