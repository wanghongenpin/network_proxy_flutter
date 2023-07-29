import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/utils/curl.dart';
import 'package:network_proxy/utils/lang.dart';
import 'package:window_manager/window_manager.dart';

///请求 URI
class PathRow extends StatefulWidget {
  final Color? color;
  final HttpRequest request;
  final ValueWrap<HttpResponse> response = ValueWrap();

  final NetworkTabController panel;
  final ProxyServer proxyServer;

  PathRow(this.request, this.panel, {Key? key, this.color = Colors.green, required this.proxyServer})
      : super(key: GlobalKey<_PathRowState>());

  @override
  State<PathRow> createState() => _PathRowState();

  void add(HttpResponse response) {
    this.response.set(response);
    var state = key as GlobalKey<_PathRowState>;
    state.currentState?.changeState();
  }
}

class _PathRowState extends State<PathRow> {
  //选择的节点
  static _PathRowState? selectedState;

  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var request = widget.request;
    var response = widget.response.get();
    var title = '${request.method.name} ${Uri.parse(request.uri).path}';
    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    return GestureDetector(
        onSecondaryLongPressDown: menu,
        child: ListTile(
            minLeadingWidth: 25,
            leading: Icon(getIcon(widget.response.get()), size: 16, color: widget.color),
            title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
            subtitle: Text(
                '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name.toUpperCase() ?? ''} ${response?.costTime() ?? ''} ',
                maxLines: 1),
            selected: selected,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 50.0),
            onTap: onClick));
  }

  void changeState() {
    setState(() {});
  }

  ///右键菜单
  menu(LongPressDownDetails details) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: <PopupMenuEntry>[
        PopupMenuItem(
            height: 38,
            child: const Text("复制请求链接", style: TextStyle(fontSize: 14)),
            onTap: () {
              var requestUrl = widget.request.requestUrl;
              Clipboard.setData(ClipboardData(text: requestUrl))
                  .then((value) => FlutterToastr.show('已复制到剪切板', context));
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("复制请求和响应", style: TextStyle(fontSize: 14)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyRequest(widget.request, widget.response.get())))
                  .then((value) => FlutterToastr.show('已复制到剪切板', context));
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("复制 cURL 请求", style: TextStyle(fontSize: 14)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: curlRequest(widget.request)))
                  .then((value) => FlutterToastr.show('已复制到剪切板', context));
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("重放请求", style: TextStyle(fontSize: 14)),
            onTap: () {
              if (!widget.proxyServer.isRunning) {
                FlutterToastr.show('代理服务未启动', context);
                return;
              }
              var request = widget.request.copy(uri: widget.request.requestUrl);
              HttpClients.proxyRequest("127.0.0.1", widget.proxyServer.port, request);

              FlutterToastr.show('已重新发送请求', context);
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("编辑重放请求", style: TextStyle(fontSize: 14)),
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                requestEdit();
              });
            }),
      ],
    );
  }

  requestEdit() async {
    var size = MediaQuery.of(context).size;
    var ratio = 1.0;
    if (Platform.isWindows) {
      ratio = WindowManager.instance.getDevicePixelRatio();
    }

    final window = await DesktopMultiWindow.createWindow(jsonEncode(
      {'name': 'RequestEditor', 'request': widget.request, 'proxyPort': widget.proxyServer.port},
    ));
    window.setTitle('请求编辑');
    window
      ..setFrame(const Offset(100, 100) & Size(860 * ratio, size.height * ratio))
      ..center()
      ..show();
  }

  //点击事件
  void onClick() {
    if (selected) {
      return;
    }
    setState(() {
      selected = true;
    });

    //切换选中的节点
    if (selectedState?.mounted == true && selectedState != this) {
      selectedState?.setState(() {
        selectedState?.selected = false;
      });
    }
    selectedState = this;
    widget.panel.change(widget.request, widget.response.get());
  }
}
