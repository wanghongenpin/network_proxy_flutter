import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_viewer_new/flutter_json_viewer.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/http/http.dart';

class HttpBodyWidget extends StatefulWidget {
  final HttpMessage? httpMessage;
  final bool inNewWindow; //是否在新窗口

  const HttpBodyWidget({super.key, required this.httpMessage, this.inNewWindow = false});

  @override
  State<StatefulWidget> createState() {
    return HttpBodyState();
  }
}

class HttpBodyState extends State<HttpBodyWidget> with SingleTickerProviderStateMixin {
  ValueNotifier<int> tabIndex = ValueNotifier(0);

  @override
  void dispose() {
    tabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var tabs = Tabs.of(widget.httpMessage?.contentType);
    if (widget.httpMessage?.body == null || widget.httpMessage?.body?.isEmpty == true) {
      return const SizedBox();
    }

    tabIndex.value = 0;

    List<Widget> list = [
      widget.inNewWindow ? const SizedBox() : titleWidget(),
      TabBar(tabs: tabs.tabList(), onTap: (index) => tabIndex.value = index),
      Padding(
        padding: const EdgeInsets.all(10),
        child: ValueListenableBuilder(
            valueListenable: tabIndex,
            builder: (_, value, __) {
              return getBody(tabs.list[value]);
            }),
      ) //body
    ];

    return DefaultTabController(
        length: tabs.list.length,
        child: widget.inNewWindow
            ? ListView(children: list)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: list));
  }

  Widget titleWidget({inNewWindow = false}) {
    var type = widget.httpMessage is HttpRequest ? "Request" : "Response";

    return Row(
      children: [
        Text('$type Body', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 15),
        IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制',
            onPressed: () {
              var body = widget.httpMessage?.bodyAsString;
              if (body == null || body.isEmpty) {
                return;
              }
              Clipboard.setData(ClipboardData(text: body)).then((value) => FlutterToastr.show("复制成功", context));
            }),
        const SizedBox(width: 5),
        inNewWindow
            ? const SizedBox()
            : IconButton(icon: const Icon(Icons.open_in_new), tooltip: '新窗口打开', onPressed: () => openNew()),
      ],
    );
  }

  void openNew() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                appBar: AppBar(title: titleWidget(inNewWindow: true)),
                body: HttpBodyWidget(httpMessage: widget.httpMessage, inNewWindow: true))));
  }

  Widget getBody(ViewType type) {
    var message = widget.httpMessage;
    if (message == null) {
      return const SizedBox();
    }

    try {
      if (type == ViewType.json) {
        return JsonViewer(json.decode(message.bodyAsString));
      }

      if (type == ViewType.jsonText) {
        var jsonObject = json.decode(message.bodyAsString);
        var prettyJsonString = const JsonEncoder.withIndent('  ').convert(jsonObject);
        return SelectableText(prettyJsonString);
      }

      if (type == ViewType.image) {
        return Image.memory(Uint8List.fromList(message.body ?? []), fit: BoxFit.none);
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
    return SelectableText.rich(TextSpan(text: message.bodyAsString));
  }
}

class Tabs {
  final List<ViewType> list = [];

  static Tabs of(ContentType? contentType) {
    var tabs = Tabs();
    if (contentType == null) {
      return tabs;
    }

    if (contentType == ContentType.json) {
      tabs.list.add(ViewType.jsonText);
    }

    tabs.list.add(ViewType.of(contentType) ?? ViewType.text);

    if (contentType == ContentType.text) {
      tabs.list.add(ViewType.jsonText);
    }
    return tabs;
  }

  List<Tab> tabList() {
    return list.map((e) => Tab(text: e.title)).toList();
  }
}

enum ViewType {
  text("Text"),
  json("JSON"),
  jsonText("JSON Text"),
  html("HTML"),
  image("Image"),
  css("CSS"),
  js("JavaScript"),
  ;

  final String title;

  const ViewType(this.title);

  static ViewType? of(ContentType contentType) {
    for (var value in values) {
      if (value.name == contentType.name) {
        return value;
      }
    }
    return null;
  }
}
