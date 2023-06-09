import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:network/network/http/http.dart';
import 'package:network/utils/lang.dart';

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
    if (widget.request.isNull()) {
      return const SizedBox();
    }

    return DefaultTabController(
        length: widget.tabs.length,
        child: Scaffold(
          appBar: AppBar(title: TabBar(tabs: widget.tabs)),
          body: TabBarView(
            children: [
              general(),
              request(),
              response(),
              const Center(child: Text('Cookies')),
            ],
          ),
        ));
  }

  Widget general() {
    var request = widget.request.get();
    var response = widget.response.get();

    return ListView(children: [
      ExpansionTile(
          title: const Text("General", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          initiallyExpanded: true,
          childrenPadding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Request URL:")),
              Expanded(flex: 4, child: SelectableText(request?.uri ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Request Method:")),
              Expanded(flex: 4, child: SelectableText(request?.method.name ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Status Code:")),
              Expanded(flex: 4, child: SelectableText(response?.status.code.toString() ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Remote Address:")),
              Expanded(flex: 4, child: SelectableText(response?.remoteAddress ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Request Time:")),
              Expanded(flex: 4, child: SelectableText(request?.requestTime.toString() ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Cost Time:")),
              Expanded(flex: 4, child: SelectableText(response?.costTime() ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Request Content-Type:")),
              Expanded(flex: 4, child: SelectableText(request?.headers.contentType ?? ''))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(flex: 2, child: SelectableText("Response Content-Type:")),
              Expanded(flex: 4, child: SelectableText(response?.headers.contentType ?? ''))
            ]),
            const SizedBox(height: 20)
          ])
    ]);
  }

  Widget request() {
    return message(widget.request.get(), "Request");
  }

  Widget response() {
    return message(widget.response.get(), "Response");
  }

  Widget cookie() {
    var requestCookie = widget.request.get()?.cookie.split(";").map((e) => e.split("=")).map((e) => Row(
        children: [Expanded(flex: 2, child: SelectableText(e.elementAt(0))), Expanded(flex: 4, child: SelectableText(e.elementAt(1)))]));
    var responseCookie = widget.response.get()?.cookie.split(";").map((element) => element.split("=")).map((e) => Row(
        children: [Expanded(flex: 2, child: SelectableText(e[0])), Expanded(flex: 4, child: SelectableText(e[1]))]));
    return ListView(children: [
      expansionTile("RequestCookie", requestCookie?.toList() ?? []),
      const Divider(),
      const SizedBox(height: 20),
      expansionTile("ResponseCookie", responseCookie?.toList() ?? []),
    ]);
  }

  Widget message(HttpMessage? message, String type) {
    var headers = <Widget>[];
    message?.headers.forEach((name, value) {
      headers.add(Row(children: [
        Expanded(flex: 2, child: SelectableText('$name:')),
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
      const Divider(),
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
        return expansionTile("$type Body",
            [SelectableText.rich(TextSpan(text: message.bodyAsString, style: const TextStyle(color: Colors.black)))]);
      }
    }
    return null;
  }
}
