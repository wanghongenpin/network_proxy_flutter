/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/component/split_view.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/utils/curl.dart';

class RequestEditor extends StatefulWidget {
  final WindowController? windowController;
  final HttpRequest? request;

  const RequestEditor({super.key, this.request, this.windowController});

  @override
  State<StatefulWidget> createState() {
    return RequestEditorState();
  }
}

class RequestEditorState extends State<RequestEditor> {
  final requestLineKey = GlobalKey<_RequestLineState>();
  final requestKey = GlobalKey<_HttpState>();
  ValueNotifier responseChange = ValueNotifier<bool>(false);
  HttpRequest? request;
  HttpResponse? response;

  bool showCURLDialog = false;

  @override
  void initState() {
    super.initState();
    request = widget.request;
    RawKeyboard.instance.addListener(onKeyEvent);
    if (widget.request == null) {
      curlParse();
    }
  }

  void onKeyEvent(RawKeyEvent event) {
    //cmd+w 关闭窗口
    if ((event.isKeyPressed(LogicalKeyboardKey.metaLeft) || event.isControlPressed) &&
        event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      RawKeyboard.instance.removeListener(onKeyEvent);
      responseChange.dispose();
      widget.windowController?.close();
      return;
    }

    //粘贴
    if ((event.isKeyPressed(LogicalKeyboardKey.metaLeft) || event.isControlPressed) &&
        event.data.logicalKey == LogicalKeyboardKey.keyV) {
      curlParse();
      return;
    }
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(onKeyEvent);
    responseChange.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("发起请求", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          toolbarHeight: Platform.isWindows ? 36 : null,
          centerTitle: true,
          actions: [
            TextButton.icon(
                onPressed: () async => sendRequest(), icon: const Icon(Icons.send), label: const Text("发送")),
            const SizedBox(width: 10)
          ],
        ),
        body: Column(children: [
          _RequestLine(key: requestLineKey, request: request),
          Expanded(
              child: VerticalSplitView(
            ratio: 0.53,
            left: _HttpWidget(
                key: requestKey,
                title: const Text("Request", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                message: request),
            right: ValueListenableBuilder(
                valueListenable: responseChange,
                builder: (_, value, __) => _HttpWidget(
                    title: Row(children: [
                      const Text("Response", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(response?.status.toString() ?? '', style: const TextStyle(fontSize: 14))
                    ]),
                    message: response,
                    readOnly: true)),
          )),
        ]));
  }

  ///发送请求
  sendRequest() async {
    var currentState = requestLineKey.currentState!;
    var headers = requestKey.currentState?.getHeaders();
    var requestBody = requestKey.currentState?.getBody();

    HttpRequest request = HttpRequest(HttpMethod.valueOf(currentState.requestMethod), currentState.requestUrl);
    request.headers.addAll(headers);
    request.body = requestBody?.codeUnits;

    HttpClients.proxyRequest(request).then((response) {
      FlutterToastr.show('请求成功', context);
      this.response = response;
      responseChange.value = !responseChange.value;
    }).catchError((e) {
      FlutterToastr.show('请求失败$e', context);
    });
  }

  curlParse() async {
    var data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null) {
      return;
    }

    var text = data.text;
    if (text?.trimLeft().startsWith('curl') == true && context.mounted && !showCURLDialog) {
      showCURLDialog = true;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(title: const Text('提示'), content: const Text('识别到curl格式，是否转换为HTTP请求？'), actions: [
            TextButton(child: const Text('取消'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
                child: const Text('确定'),
                onPressed: () {
                  try {
                    setState(() {
                      request = parseCurl(text!);
                      requestLineKey.currentState?.change(request?.requestUrl, request?.method.name);
                    });
                  } catch (e) {
                    FlutterToastr.show('转换失败', context);
                  }
                  Navigator.of(context).pop();
                }),
          ]);
        },
      ).then((value) => showCURLDialog = false);
    }
  }
}

class _HttpWidget extends StatefulWidget {
  final HttpMessage? message;
  final bool readOnly;
  final Widget title;

  const _HttpWidget({this.message, this.readOnly = false, super.key, required this.title});

  @override
  State<StatefulWidget> createState() {
    return _HttpState();
  }
}

class _HttpState extends State<_HttpWidget> {
  final tabs = ['Header', 'Body'];
  final headerKey = GlobalKey<HeadersState>();
  String? body;

  String? getBody() {
    return body;
  }

  HttpHeaders? getHeaders() {
    return headerKey.currentState?.getHeaders();
  }

  @override
  Widget build(BuildContext context) {
    body = widget.message?.bodyAsString;
    headerKey.currentState?.refreshHeader(widget.message?.headers);

    if (widget.message == null && widget.readOnly) {
      return Scaffold(appBar: AppBar(title: widget.title), body: const Center(child: Text("无数据")));
    }

    return SingleChildScrollView(
        child: SizedBox(
            height: MediaQuery.of(context).size.height - 120,
            child: DefaultTabController(
                length: tabs.length,
                child: Scaffold(
                  primary: false,
                  appBar: PreferredSize(
                      preferredSize: const Size.fromHeight(70),
                      child: AppBar(
                        title: widget.title,
                        bottom: TabBar(tabs: tabs.map((e) => Tab(text: e, height: 35)).toList()),
                      )),
                  body: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: TabBarView(
                        children: [
                          Headers(key: headerKey, headers: widget.message?.headers, readOnly: widget.readOnly),
                          _body()
                        ],
                      )),
                ))));
  }

  Widget _body() {
    if (widget.readOnly) {
      return KeepAliveWrapper(
          child: SingleChildScrollView(child: HttpBodyWidget(httpMessage: widget.message, hideRequestRewrite: true)));
    }

    return TextField(
        autofocus: true,
        controller: TextEditingController(text: body),
        readOnly: widget.readOnly,
        onChanged: (value) {
          body = value;
        },
        minLines: 20,
        maxLines: 20);
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
      requestUrl = 'https://';
      return;
    }

    var request = widget.request!;
    requestUrl = request.requestUrl;
    requestMethod = request.method.name;
  }

  change(String? requestUrl, String? requestMethod) {
    this.requestUrl = requestUrl ?? this.requestUrl;
    this.requestMethod = requestMethod ?? this.requestMethod;
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
  final bool readOnly; //只读

  const Headers({super.key, this.headers, this.readOnly = false});

  @override
  State<StatefulWidget> createState() {
    return HeadersState();
  }
}

class HeadersState extends State<Headers> with AutomaticKeepAliveClientMixin {
  final Map<TextEditingController, List<TextEditingController>> _headers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.headers == null && !widget.readOnly) {
      _headers[TextEditingController(text: "User-Agent")] = [TextEditingController(text: "ProxyPin/1.0.2")];
      _headers[TextEditingController(text: "Accept")] = [TextEditingController(text: "*/*")];
      return;
    }
    widget.headers?.forEach((name, values) {
      _headers[TextEditingController(text: name)] = values.map((it) => TextEditingController(text: it)).toList();
    });
  }

  //刷新header
  refreshHeader(HttpHeaders? headers) {
    _headers.clear();
    setState(() {
      headers?.forEach((name, values) {
        _headers[TextEditingController(text: name)] = values.map((it) => TextEditingController(text: it)).toList();
      });
    });
  }

  ///获取所有请求头
  HttpHeaders getHeaders() {
    var headers = HttpHeaders();
    _headers.forEach((name, values) {
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
    super.build(context);

    var list = [
      _row(const Text('Key'), const Text('Value'), const Text('')),
      ..._buildRows(),
    ];

    if (!widget.readOnly) {
      list.add(TextButton(
        child: const Text("添加Header", textAlign: TextAlign.center),
        onPressed: () {
          setState(() {
            _headers[TextEditingController()] = [TextEditingController()];
          });
        },
      ));
    }
    return Scaffold(
        body: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ListView.separated(
                separatorBuilder: (context, index) =>
                    index == list.length ? const SizedBox() : const Divider(thickness: 0.2),
                itemBuilder: (context, index) => list[index],
                itemCount: list.length)));
  }

  List<Widget> _buildRows() {
    List<Widget> list = [];

    _headers.forEach((key, values) {
      for (var val in values) {
        list.add(_row(
            _cell(key, isKey: true),
            _cell(val),
            widget.readOnly
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: InkWell(
                        onTap: () {
                          setState(() {
                            _headers.remove(key);
                          });
                        },
                        child: const Icon(Icons.remove_circle, size: 16)))));
      }
    });

    return list;
  }

  Widget _cell(TextEditingController val, {bool isKey = false}) {
    return Container(
        padding: const EdgeInsets.only(right: 5),
        child: TextFormField(
            readOnly: widget.readOnly,
            style: TextStyle(fontSize: 12, fontWeight: isKey ? FontWeight.w500 : null),
            controller: val,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: isKey ? "Key" : "Value")));
  }

  Widget _row(Widget key, Widget val, Widget? op) {
    return Row(children: [Expanded(flex: 4, child: key), Expanded(flex: 6, child: val), op ?? const SizedBox()]);
  }
}
