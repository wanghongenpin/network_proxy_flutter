import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/utils/lang.dart';

class NetworkTabController extends StatefulWidget {
  final tabs = [
    'General',
    'Request',
    'Response',
    'Cookies',
  ];

  final ValueWrap<HttpRequest> request = ValueWrap();
  final ValueWrap<HttpResponse> response = ValueWrap();
  final Widget? title;
  final TextStyle? tabStyle;

  NetworkTabController({HttpRequest? httpRequest, HttpResponse? httpResponse, this.title, this.tabStyle})
      : super(key: GlobalKey<NetworkTabState>()) {
    request.set(httpRequest);
    response.set(httpResponse);
  }

  void change(HttpRequest? request, HttpResponse? response) {
    this.request.set(request);
    this.response.set(response);
    var state = key as GlobalKey<NetworkTabState>;
    state.currentState?.changeState();
  }

  @override
  State<StatefulWidget> createState() {
    return NetworkTabState();
  }
}

class NetworkTabState extends State<NetworkTabController> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void changeState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var tabBar = TabBar(
      controller: _tabController,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      tabs: widget.tabs.map((title) => Tab(child: Text(title, style: widget.tabStyle, maxLines: 1))).toList(),
    );

    Widget appBar = widget.title == null ? tabBar : AppBar(title: widget.title, bottom: tabBar);
    return Scaffold(
      appBar: appBar as PreferredSizeWidget?,
      body: TabBarView(
        controller: _tabController,
        children: [
          general(),
          request(),
          response(),
          cookies(),
        ],
      ),
    );
  }

  Widget general() {
    var request = widget.request.get();
    if (request == null) {
      return const SizedBox();
    }
    var response = widget.response.get();
    var content = [
      rowWidget("Request URL", request.requestUrl),
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
    return ListView(children: [
      Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, top: 20),
          child: rowWidget("Path", widget.request.get()?.path.toString())),
      ...message(widget.request.get(), "Request")
    ]);
  }

  Widget response() {
    return ListView(children: [
      Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, top: 20),
          child: rowWidget("StatusCode", widget.response.get()?.status.code.toString())),
      ...message(widget.response.get(), "Response")
    ]);
  }

  Widget cookies() {
    var requestCookie = _cookieWidget(widget.request.get()?.cookie);

    var responseCookie = widget.response.get()?.headers.getList("Set-Cookie")?.expand((e) => _cookieWidget(e)!);
    return ListView(children: [
      expansionTile("Request Cookies", requestCookie?.toList() ?? []),
      // const Divider(),
      const SizedBox(height: 20),
      expansionTile("Response Cookies", responseCookie?.toList() ?? []),
    ]);
  }

  List<Widget> message(HttpMessage? message, String type) {
    var headers = <Widget>[];
    message?.headers.forEach((name, values) {
      for (var v in values) {
        headers.add(Row(children: [
          Expanded(flex: 2, child: SelectableText(name)),
          Expanded(flex: 4, child: SelectableText(v)),
          const SizedBox(height: 20),
        ]));
      }
    });

    Widget? bodyWidgets = message == null ? null : getBody(type, message);

    Widget headerWidget = ExpansionTile(
        title: Text("$type Headers", style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,
        shape: const Border(),
        childrenPadding: const EdgeInsets.only(left: 20, bottom: 20),
        children: headers);

    return [headerWidget, bodyWidgets ?? const SizedBox()];
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
        return expansionTile("$type Body", [Image.memory(Uint8List.fromList(message.body ?? []), fit: BoxFit.cover)]);
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
    return cookie
        ?.split(";")
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
