import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_viewer_new/flutter_json_viewer.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class HttpBodyWidget extends StatefulWidget {
  final HttpMessage? httpMessage;
  final bool inNewWindow; //是否在新窗口
  final WindowController? windowController;

  const HttpBodyWidget({super.key, required this.httpMessage, this.inNewWindow = false, this.windowController});

  @override
  State<StatefulWidget> createState() {
    return HttpBodyState();
  }
}

class HttpBodyState extends State<HttpBodyWidget> {
  ValueNotifier<int> tabIndex = ValueNotifier(0);
  String? body;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(onKeyEvent);
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
    tabIndex.dispose();
    RawKeyboard.instance.removeListener(onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.httpMessage?.body == null || widget.httpMessage?.body?.isEmpty == true) {
      return const SizedBox();
    }

    var tabs = Tabs.of(widget.httpMessage?.contentType);
    body = widget.httpMessage?.bodyAsString;

    if (tabIndex.value >= tabs.list.length) tabIndex.value = 0;

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

    var tabController = DefaultTabController(
        length: tabs.list.length,
        child: widget.inNewWindow
            ? ListView(children: list)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: list));

    if (widget.inNewWindow) {
      return Scaffold(
          appBar: AppBar(title: titleWidget(inNewWindow: true), toolbarHeight: Platform.isWindows ? 36 : null),
          body: tabController);
    }
    return tabController;
  }

  Widget titleWidget({inNewWindow = false}) {
    var type = widget.httpMessage is HttpRequest ? "Request" : "Response";

    return Row(
      mainAxisAlignment: widget.inNewWindow ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Text('$type Body', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 15),
        IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制',
            onPressed: () {
              if (body == null || body?.isEmpty == true) {
                return;
              }
              Clipboard.setData(ClipboardData(text: body!)).then((value) => FlutterToastr.show("已复制到剪切板", context));
            }),
        const SizedBox(width: 5),
        inNewWindow
            ? const SizedBox()
            : IconButton(icon: const Icon(Icons.open_in_new), tooltip: '新窗口打开', onPressed: () => openNew())
      ],
    );
  }

  void openNew() async {
    if (Platforms.isDesktop()) {
      var size = MediaQuery.of(context).size;
      var ratio = 1.0;
      if (Platform.isWindows) {
        WindowManager.instance.getDevicePixelRatio();
      }
      final window = await DesktopMultiWindow.createWindow(jsonEncode(
        {'name': 'HttpBodyWidget', 'httpMessage': widget.httpMessage, 'inNewWindow': true},
      ));
      window
        ..setTitle(widget.httpMessage is HttpRequest ? '请求体' : '响应体')
        ..setFrame(const Offset(100, 100) & Size(800 * ratio, size.height * ratio))
        ..center()
        ..show();
      return;
    }

    Navigator.push(
        context, MaterialPageRoute(builder: (_) => HttpBodyWidget(httpMessage: widget.httpMessage, inNewWindow: true)));
  }

  Widget getBody(ViewType type) {
    var message = widget.httpMessage;
    if (message == null || body == null) {
      return const SizedBox();
    }

    try {
      if (type == ViewType.json) {
        return JsonViewer(json.decode(body!));
      }

      if (type == ViewType.jsonText) {
        var jsonObject = json.decode(body!);
        var prettyJsonString = const JsonEncoder.withIndent('  ').convert(jsonObject);
        return SelectableText(prettyJsonString, contextMenuBuilder: contextMenu);
      }

      if (type == ViewType.formUrl) {
        return SelectableText(Uri.decodeFull(body!));
      }
      if (type == ViewType.image) {
        return Image.memory(Uint8List.fromList(message.body ?? []), fit: BoxFit.none);
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
    return SelectableText.rich(TextSpan(text: body), contextMenuBuilder: contextMenu);
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
    if (contentType == ContentType.formUrl || contentType == ContentType.json) {
      tabs.list.add(ViewType.text);
    }
    return tabs;
  }

  List<Tab> tabList() {
    return list.map((e) => Tab(text: e.title)).toList();
  }
}

enum ViewType {
  text("Text"),
  formUrl("URL 解码"),
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
