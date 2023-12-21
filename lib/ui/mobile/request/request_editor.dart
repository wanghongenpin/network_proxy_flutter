import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/utils/curl.dart';

class MobileRequestEditor extends StatefulWidget {
  final HttpRequest? request;
  final ProxyServer? proxyServer;

  const MobileRequestEditor({super.key, this.request, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return RequestEditorState();
  }
}

class RequestEditorState extends State<MobileRequestEditor> with SingleTickerProviderStateMixin {
  var tabs = const [
    Tab(text: "请求"),
    Tab(text: "响应"),
  ];

  final requestLineKey = GlobalKey<_RequestLineState>();
  final requestKey = GlobalKey<_HttpState>();
  final responseKey = GlobalKey<_HttpState>();

  ValueNotifier responseChange = ValueNotifier<bool>(false);

  late TabController tabController;

  HttpRequest? request;
  HttpResponse? response;

  @override
  void dispose() {
    tabController.dispose();
    responseChange.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: tabs.length, vsync: this);
    request = widget.request;
    if (widget.request == null) {
      curlParse();
    }
  }

  curlParse() async {
    //获取剪切板内容
    var data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null) {
      return;
    }
    var text = data.text;
    if (text?.trimLeft().startsWith('curl') == true && context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(title: const Text('提示'), content: const Text('识别到剪切板内容是curl格式，是否转换为HTTP请求？'), actions: [
            TextButton(child: const Text('取消'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
                child: const Text('确定'),
                onPressed: () {
                  try {
                    setState(() {
                      request = parseCurl(text!);
                      requestKey.currentState?.change(request!);
                      requestLineKey.currentState?.change(request?.uri, request?.method.name);
                    });
                  } catch (e) {
                    FlutterToastr.show('转换失败', context);
                  }
                  Navigator.of(context).pop();
                }),
          ]);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text("发起请求", style: TextStyle(fontSize: 16)),
            centerTitle: true,
            leading: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("取消", style: Theme.of(context).textTheme.bodyMedium)),
            actions: [TextButton.icon(icon: const Icon(Icons.send), label: const Text("发送"), onPressed: sendRequest)],
            bottom: TabBar(controller: tabController, tabs: tabs)),
        body: TabBarView(
          controller: tabController,
          children: [
            _HttpWidget(title: _RequestLine(request: request, key: requestLineKey), message: request, key: requestKey),
            ValueListenableBuilder(
                valueListenable: responseChange,
                builder: (_, value, __) => _HttpWidget(
                    key: responseKey,
                    title: Row(children: [
                      const Text('状态码：', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      Text(response?.status.toString() ?? "", style: const TextStyle(color: Colors.blue))
                    ]),
                    readOnly: true,
                    message: response)),
          ],
        ));
  }

  ///发送请求
  sendRequest() async {
    var currentState = requestLineKey.currentState!;
    var headers = requestKey.currentState?.getHeaders();
    var requestBody = requestKey.currentState?.getBody();

    HttpRequest request =
        HttpRequest(HttpMethod.valueOf(currentState.requestMethod), Uri.encodeFull(currentState.requestUrl));
    request.headers.addAll(headers);
    request.body = requestBody == null ? null : utf8.encode(requestBody);

    var proxyInfo =
        Vpn.isVpnStarted && widget.proxyServer != null ? ProxyInfo.of("127.0.0.1", widget.proxyServer?.port) : null;
    HttpClients.proxyRequest(proxyInfo: proxyInfo, request).then((response) {
      FlutterToastr.show('请求成功', context);
      this.response = response;
      this.response?.request = request;
      responseChange.value = !responseChange.value;
      responseKey.currentState?.change(response);
      tabController.animateTo(1);
    }).catchError((e) {
      FlutterToastr.show('请求失败$e', context);
    });
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

class _HttpState extends State<_HttpWidget> with AutomaticKeepAliveClientMixin {
  final headerKey = GlobalKey<HeadersState>();
  HttpMessage? message;
  String? body;

  @override
  bool get wantKeepAlive => true;

  String? getBody() {
    return body;
  }

  @override
  void initState() {
    super.initState();
    message = widget.message;
    body = widget.message?.bodyAsString;
    print("_HttpWidget initState");
  }

  change(HttpMessage message) {
    this.message = message;
    body = message.bodyAsString;
    headerKey.currentState?.refreshHeader(message.headers);
  }

  HttpHeaders? getHeaders() {
    return headerKey.currentState?.getHeaders();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (message == null && widget.readOnly) {
      return const Center(child: Text("无数据"));
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          widget.title,
          Headers(headers: message?.headers, key: headerKey, readOnly: widget.readOnly), // 请求头
          const SizedBox(height: 10),
          const Text("Body", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue)),
          _body(),
          const SizedBox(height: 10),
        ]));
  }

  Widget _body() {
    if (widget.readOnly) {
      return SingleChildScrollView(child: HttpBodyWidget(httpMessage: message));
    }

    return TextField(
        controller: TextEditingController(text: body),
        readOnly: widget.readOnly,
        onChanged: (value) {
          body = value;
        },
        minLines: 3,
        maxLines: 15);
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
  final bool readOnly; //只读

  const Headers({super.key, this.headers, required this.readOnly});

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
    if (widget.headers == null && !widget.readOnly) {
      headers["User-Agent"] = ["ProxyPin/1.0.2"];
      headers["Accept"] = ["*/*"];
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

  //刷新header
  refreshHeader(HttpHeaders? headers) {
    this.headers.clear();
    headers?.forEach((name, values) {
      this.headers[name] = values;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text("Headers", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue)),
      tilePadding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
      initiallyExpanded: true,
      shape: const Border(),
      children: [
        ...buildHeaders(),
        widget.readOnly
            ? const SizedBox()
            : Container(
                alignment: Alignment.center,
                child: TextButton(
                    onPressed: () {
                      modifyHeader("", "");
                    },
                    child: const Text("添加Header", textAlign: TextAlign.center))) //添加按钮
      ],
    );
  }

  List<Widget> buildHeaders() {
    List<Widget> list = [];
    headers.forEach((key, values) {
      for (var val in values) {
        var header = row(Text(key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(val, style: const TextStyle(fontSize: 12), maxLines: 5, overflow: TextOverflow.ellipsis));

        Widget headerWidget = Padding(padding: const EdgeInsets.only(top: 5, bottom: 5), child: header);
        if (!widget.readOnly) {
          headerWidget =
              InkWell(onTap: () => modifyHeader(key, val), onLongPress: () => deleteHeader(key), child: headerWidget);
        }

        list.add(headerWidget);
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
