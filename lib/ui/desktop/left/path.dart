import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/storage/favorites.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
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
  final Function(PathRow)? remove;

  PathRow(this.request, this.panel, {Key? key, this.color = Colors.green, required this.proxyServer, this.remove})
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
    var response = widget.response.get() ?? request.response;
    String title = '${request.method.name} ${request.uri}';
    try {
      title = '${request.method.name} ${Uri.parse(request.uri).path}';
    } catch (_) {}

    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    String contentType = response?.contentType.name.toUpperCase() ?? '';
    var packagesSize = getPackagesSize(request, response);

    return GestureDetector(
        onSecondaryTapDown: menu,
        child: ListTile(
            minLeadingWidth: 5,
            leading: getIcon(widget.response.get() ?? widget.request.response),
            title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
            subtitle: Text(
                '$time - [${response?.status.code ?? ''}]  $contentType $packagesSize ${response?.costTime() ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.visible),
            subtitleTextStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            selected: selected,
            dense: true,
            visualDensity: const VisualDensity(vertical: -4),
            contentPadding: const EdgeInsets.only(left: 35),
            onTap: onClick));
  }

  void changeState() {
    setState(() {});
  }

  ///右键菜单
  menu(TapDownDetails details) {
    showContextMenu(
      context,
      details.globalPosition,
      items: <PopupMenuEntry>[
        popupItem("复制请求链接", onTap: () {
          var requestUrl = widget.request.requestUrl;
          Clipboard.setData(ClipboardData(text: requestUrl)).then((value) => FlutterToastr.show('已复制到剪切板', context));
        }),
        popupItem("复制请求和响应", onTap: () {
          Clipboard.setData(ClipboardData(text: copyRequest(widget.request, widget.response.get())))
              .then((value) => FlutterToastr.show('已复制到剪切板', context));
        }),
        popupItem("复制 cURL 请求", onTap: () {
          Clipboard.setData(ClipboardData(text: curlRequest(widget.request)))
              .then((value) => FlutterToastr.show('已复制到剪切板', context));
        }),
        const PopupMenuDivider(height: 0.3),
        popupItem("重放请求", onTap: () {
          var request = widget.request.copy(uri: widget.request.requestUrl);
          var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
          HttpClients.proxyRequest(request, proxyInfo: proxyInfo);

          FlutterToastr.show('已重新发送请求', context);
        }),
        popupItem("编辑请求重放", onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            requestEdit();
          });
        }),
        popupItem("收藏请求", onTap: () {
          FavoriteStorage.addFavorite(widget.request);
          FlutterToastr.show('收藏成功', context);
        }),
        const PopupMenuDivider(height: 0.3),
        popupItem("删除", onTap: () {
          widget.remove?.call(widget);
        }),
      ],
    );
  }

  PopupMenuItem popupItem(String text, {VoidCallback? onTap}) {
    return CustomPopupMenuItem(height: 32, onTap: onTap, child: Text(text, style: const TextStyle(fontSize: 13)));
  }

  ///请求编辑
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
      ..setFrame(const Offset(100, 100) & Size(960 * ratio, size.height * ratio))
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
    widget.panel.change(widget.request, widget.response.get() ?? widget.request.response);
  }
}
