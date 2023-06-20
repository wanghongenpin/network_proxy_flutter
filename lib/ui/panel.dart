import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/utils/lang.dart';

class NetworkTabController extends StatefulWidget {
  final tabs = <Tab>[
    const Tab(child: Text('General', style: TextStyle(fontSize: 18))),
    const Tab(child: Text('Request', style: TextStyle(fontSize: 18))),
    const Tab(child: Text('Response', style: TextStyle(fontSize: 18))),
    const Tab(child: Text('Cookies', style: TextStyle(fontSize: 18))),
  ];

  final ValueWrap<HttpRequest> request = ValueWrap();
  final ValueWrap<HttpResponse> response = ValueWrap();

  NetworkTabController() : super(key: GlobalKey<_NetworkTabState>());

  void change(HttpRequest request, HttpResponse? response) {
    this.request.set(request);
    if (response != null) {
      this.response.set(response);
    }
    var state = key as GlobalKey<_NetworkTabState>;
    state.currentState?.changeState();
  }

  @override
  State<StatefulWidget> createState() {
    return _NetworkTabState();
  }
}

class _NetworkTabState extends State<NetworkTabController> {
  void changeState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
        length: widget.tabs.length,
        child: Scaffold(
          appBar: AppBar(title: TabBar(tabs: widget.tabs)),
          body: TabBarView(
            children: [
              general(),
              request(),
              response(),
              cookies(),
            ],
          ),
        ));
  }

  Widget general() {
    var request = widget.request.get();
    if (request == null) {
      return const SizedBox();
    }
    var response = widget.response.get();
    var content = [
      rowWidget("Request URL", request.uri),
      const SizedBox(height: 20),
      rowWidget("Request Method", request.method.name),
      const SizedBox(height: 20),
      rowWidget("Status Code", response?.status.code.toString()),
      const SizedBox(height: 20),
      rowWidget("Remote Address", response?.remoteAddress),
      const SizedBox(height: 20),
      rowWidget("Request Time", request.requestTime.toString()),
      const SizedBox(height: 20),
      rowWidget("Duration", response?.costTime()),
      const SizedBox(height: 20),
      rowWidget("Request Content-Type", request.headers.contentType),
      const SizedBox(height: 20),
      rowWidget("Response Content-Type", response?.headers.contentType),
    ];

    return ListView(children: [expansionTile("General", content)]);
  }

  Widget request() {
    return message(widget.request.get(), "Request");
  }

  Widget response() {
    return message(widget.response.get(), "Response");
  }

  Widget cookies() {
    var requestCookie = _cookieWidget(widget.request.get()?.cookie);

    var responseCookie = _cookieWidget(widget.response.get()?.headers.get("Set-Cookie"));
    return ListView(children: [
      expansionTile("Request Cookies", requestCookie?.toList() ?? []),
      // const Divider(),
      const SizedBox(height: 20),
      expansionTile("Response Cookies", responseCookie?.toList() ?? []),
    ]);
  }

  Widget message(HttpMessage? message, String type) {
    var headers = <Widget>[];
    message?.headers.forEach((name, value) {
      headers.add(Row(children: [
        Expanded(flex: 2, child: SelectableText(name)),
        Expanded(flex: 4, child: SelectableText(value)),
        const SizedBox(height: 20),
      ]));
    });

    Widget? bodyWidgets = message == null ? null : getBody(type, message);

    return ListView(children: [
      ExpansionTile(
          title: Text("$type Headers", style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          shape: const Border(),
          childrenPadding: const EdgeInsets.only(left: 20, bottom: 20),
          children: headers),
      bodyWidgets ?? const SizedBox()
    ]);
  }

  Widget expansionTile(String title, List<Widget> content) {
    return ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        expandedAlignment: Alignment.topLeft,
        childrenPadding: const EdgeInsets.only(left: 20),
        initiallyExpanded: true,
        shape: const Border(),
        children: content);
  }

  Widget? getBody(String type, HttpMessage message) {
    if (message.body?.isNotEmpty == true) {
      if (message.contentType == ContentType.image) {
        return expansionTile("$type Body",
            [Image.memory(Uint8List.fromList(message.body ?? []), fit: BoxFit.cover, width: 200, height: 200)]);
      } else {
        try {
          if (message.contentType == ContentType.json) {
            // 格式化JSON字符串
            var jsonObject = json.decode(message.bodyAsString);
            var prettyJsonString = const JsonEncoder.withIndent('  ').convert(jsonObject);
            return expansionTile("$type Body", [SelectableText.rich(TextSpan(text: prettyJsonString))]);
          }
        } catch (e) {
          // ignore: avoid_print
          print(e);
        }

        return expansionTile("$type Body", [SelectableText.rich(TextSpan(text: message.bodyAsString))]);
      }
    }
    return null;
  }

  Iterable<Widget>? _cookieWidget(String? cookie) {
    return cookie?.split(";")
        .map((e) => Strings.splitFirst(e, "="))
        .where((element) => element != null)
        .map((e) => rowWidget(e!.key, e.value));
  }

  Widget rowWidget(final String name, String? value) {
    return Row(children: [
      Expanded(flex: 2, child: SelectableText(name)),
      Expanded(flex: 4, child: SelectableText(value ?? ''))
    ]);
  }
}
