import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/storage/favorites.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/utils/curl.dart';
import 'package:window_manager/window_manager.dart';

class Favorites extends StatefulWidget {
  final NetworkTabController panel;

  const Favorites({Key? key, required this.panel}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _FavoritesState();
  }
}

class _FavoritesState extends State<Favorites> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: FavoriteStorage.favorites,
        builder: (BuildContext context, AsyncSnapshot<Queue<HttpRequest>> snapshot) {
          if (snapshot.hasData) {
            var favorites = snapshot.data ?? Queue();
            if (favorites.isEmpty) {
              return const Center(child: Text("暂无收藏"));
            }

            return ListView.separated(
              itemCount: favorites.length,
              itemBuilder: (_, index) {
                var request = favorites.elementAt(index);
                return _FavoriteItem(
                  request,
                  panel: widget.panel,
                  onRemove: (HttpRequest request) {
                    FavoriteStorage.removeFavorite(request);
                    FlutterToastr.show('已删除收藏', context);
                    setState(() {});
                  },
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.3),
            );
          } else {
            return const SizedBox();
          }
        });
  }
}

class _FavoriteItem extends StatefulWidget {
  final HttpRequest request;
  final NetworkTabController panel;
  final Function(HttpRequest request)? onRemove;

  const _FavoriteItem(this.request, {Key? key, required this.panel, required this.onRemove}) : super(key: key);

  @override
  State<_FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<_FavoriteItem> {
  //选择的节点
  static _FavoriteItemState? selectedState;

  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var request = widget.request;
    var response = request.response;
    var title = '${request.method.name} ${request.requestUrl}';
    var time = formatDate(request.requestTime, [mm, '-', d, ' ', HH, ':', nn, ':', ss]);
    return GestureDetector(
        onSecondaryLongPressDown: menu,
        child: ListTile(
            minLeadingWidth: 25,
            leading: getIcon(response),
            title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 2),
            subtitle: Text(
                '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name.toUpperCase() ?? ''} ${response?.costTime() ?? ''} ',
                maxLines: 1),
            selected: selected,
            dense: true,
            onTap: onClick));
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
        popupItem("复制请求链接", onTap: () {
          var requestUrl = widget.request.requestUrl;
          Clipboard.setData(ClipboardData(text: requestUrl)).then((value) => FlutterToastr.show('已复制到剪切板', context));
        }),
        popupItem("复制请求和响应", onTap: () {
          Clipboard.setData(ClipboardData(text: copyRequest(widget.request, widget.request.response)))
              .then((value) => FlutterToastr.show('已复制到剪切板', context));
        }),
        popupItem("复制 cURL 请求", onTap: () {
          Clipboard.setData(ClipboardData(text: curlRequest(widget.request)))
              .then((value) => FlutterToastr.show('已复制到剪切板', context));
        }),
        popupItem("重放请求", onTap: () {
          var request = widget.request.copy(uri: widget.request.requestUrl);
          HttpClients.proxyRequest(request);

          FlutterToastr.show('已重新发送请求', context);
        }),
        popupItem("编辑请求重放", onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            requestEdit();
          });
        }),
        popupItem("删除收藏", onTap: () {
          widget.onRemove?.call(widget.request);
        })
      ],
    );
  }

  PopupMenuItem popupItem(String text, {VoidCallback? onTap}) {
    return PopupMenuItem(height: 38, onTap: onTap, child: Text(text, style: const TextStyle(fontSize: 14)));
  }

  ///请求编辑
  requestEdit() async {
    var size = MediaQuery.of(context).size;
    var ratio = 1.0;
    if (Platform.isWindows) {
      ratio = WindowManager.instance.getDevicePixelRatio();
    }

    final window = await DesktopMultiWindow.createWindow(jsonEncode(
      {'name': 'RequestEditor', 'request': widget.request},
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
    widget.panel.change(widget.request, widget.request.response);
  }
}
