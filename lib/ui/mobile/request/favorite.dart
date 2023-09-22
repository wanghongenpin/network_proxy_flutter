import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/storage/favorites.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/mobile/request/request_editor.dart';
import 'package:network_proxy/utils/curl.dart';

class MobileFavorites extends StatefulWidget {
  final ProxyServer proxyServer;

  const MobileFavorites({Key? key, required this.proxyServer}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _FavoritesState();
  }
}

class _FavoritesState extends State<MobileFavorites> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("收藏请求", style: TextStyle(fontSize: 16)), centerTitle: true),
        body: FutureBuilder(
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
                      index: index,
                      onRemove: (HttpRequest request) {
                        FavoriteStorage.removeFavorite(request);
                        FlutterToastr.show('已删除收藏', context);
                        setState(() {});
                      },
                      proxyServer: widget.proxyServer,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.3),
                );
              } else {
                return const SizedBox();
              }
            }));
  }
}

class _FavoriteItem extends StatefulWidget {
  final int index;
  final ProxyServer proxyServer;
  final HttpRequest request;
  final Function(HttpRequest request)? onRemove;

  const _FavoriteItem(this.request, {Key? key, required this.onRemove, required this.proxyServer, required this.index})
      : super(key: key);

  @override
  State<_FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<_FavoriteItem> {
  @override
  Widget build(BuildContext context) {
    var request = widget.request;
    var response = request.response;
    var title = '${request.method.name} ${request.requestUrl}';
    var time = formatDate(request.requestTime, [mm, '-', d, ' ', HH, ':', nn, ':', ss]);
    String subtitle =
        '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name.toUpperCase() ?? ''} ${response?.costTime() ?? ''} ';
    return ListTile(
        onLongPress: menu,
        minLeadingWidth: 25,
        leading: getIcon(response),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 2),
        subtitle: Text.rich(
            maxLines: 1,
            TextSpan(children: [
              TextSpan(text: '#${widget.index} ', style: const TextStyle(fontSize: 12, color: Colors.teal)),
              TextSpan(text: subtitle, style: const TextStyle(fontSize: 12)),
            ])),
        dense: true,
        onTap: onClick);
  }

  ///右键菜单
  menu() {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      builder: (ctx) {
        return Wrap(alignment: WrapAlignment.center, children: [
          menuItem("复制请求链接", () => widget.request.requestUrl),
          const Divider(thickness: 0.5),
          menuItem("复制请求和响应", () => copyRequest(widget.request, widget.request.response)),
          const Divider(thickness: 0.5),
          menuItem("复制 cURL 请求", () => curlRequest(widget.request)),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("请求重放", textAlign: TextAlign.center)),
              onPressed: () {
                var request = widget.request.copy(uri: widget.request.requestUrl);
                HttpClients.proxyRequest(
                    proxyInfo: widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null,
                    request);

                FlutterToastr.show('已重新发送请求', context);
                Navigator.of(context).pop();
              }),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("编辑请求重放", textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        MobileRequestEditor(request: widget.request, proxyServer: widget.proxyServer)));
              }),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("删除收藏", textAlign: TextAlign.center)),
              onPressed: () {
                widget.onRemove?.call(widget.request);
                FlutterToastr.show('删除成功', context);
                Navigator.of(context).pop();
              }),
          Container(
            color: Theme.of(context).hoverColor,
            height: 8,
          ),
          TextButton(
            child: Container(
                height: 60,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10),
                child: const Text("取消", textAlign: TextAlign.center)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ]);
      },
    );
  }

  Widget menuItem(String title, String Function() callback) {
    return TextButton(
        child: SizedBox(width: double.infinity, child: Text(title, textAlign: TextAlign.center)),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: callback.call())).then((value) {
            FlutterToastr.show('已复制到剪切板', context);
            Navigator.of(context).pop();
          });
        });
  }

  //点击事件
  void onClick() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return NetworkTabController(
          proxyServer: widget.proxyServer,
          httpRequest: widget.request,
          httpResponse: widget.request.response,
          title: const Text("抓包详情", style: TextStyle(fontSize: 16)));
    }));
  }
}
