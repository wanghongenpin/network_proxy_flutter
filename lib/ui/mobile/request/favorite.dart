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

  const MobileFavorites({super.key, required this.proxyServer});

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
            builder: (BuildContext context, AsyncSnapshot<Queue<Favorite>> snapshot) {
              if (snapshot.hasData) {
                var favorites = snapshot.data ?? Queue();
                if (favorites.isEmpty) {
                  return const Center(child: Text("暂无收藏"));
                }

                return ListView.separated(
                  itemCount: favorites.length,
                  itemBuilder: (_, index) {
                    var favorite = favorites.elementAt(index);
                    return _FavoriteItem(
                      favorite,
                      index: index,
                      onRemove: (Favorite favorite) {
                        FavoriteStorage.removeFavorite(favorite);
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
  final Favorite favorite;
  final ProxyServer proxyServer;
  final Function(Favorite favorite)? onRemove;

  const _FavoriteItem(this.favorite, {Key? key, required this.onRemove, required this.proxyServer, required this.index})
      : super(key: key);

  @override
  State<_FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<_FavoriteItem> {
  late HttpRequest request;

  @override
  void initState() {
    super.initState();
    request = widget.favorite.request;
  }

  @override
  Widget build(BuildContext context) {
    var response = request.response;
    var title = '${request.method.name} ${request.requestUrl}';
    var time = formatDate(request.requestTime, [mm, '-', d, ' ', HH, ':', nn, ':', ss]);
    String subtitle =
        '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name.toUpperCase() ?? ''} ${response?.costTime() ?? ''} ';
    return ListTile(
        onLongPress: menu,
        minLeadingWidth: 25,
        leading: getIcon(response),
        title: Text(widget.favorite.name ?? title, overflow: TextOverflow.ellipsis, maxLines: 2),
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
      isScrollControlled: true,
      builder: (ctx) {
        return Wrap(alignment: WrapAlignment.center, children: [
          menuItem("复制请求链接", () => request.requestUrl),
          const Divider(thickness: 0.5),
          menuItem("复制 cURL 请求", () => curlRequest(request)),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("重命名", textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context).pop();
                rename(widget.favorite);
              }),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("请求重放", textAlign: TextAlign.center)),
              onPressed: () {
                var httpRequest = request.copy(uri: request.requestUrl);
                HttpClients.proxyRequest(
                    proxyInfo: widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null,
                    httpRequest);

                FlutterToastr.show('已重新发送请求', context);
                Navigator.of(context).pop();
              }),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("编辑请求重放", textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => MobileRequestEditor(request: request, proxyServer: widget.proxyServer)));
              }),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("删除收藏", textAlign: TextAlign.center)),
              onPressed: () {
                widget.onRemove?.call(widget.favorite);
                FlutterToastr.show('删除成功', context);
                Navigator.of(context).pop();
              }),
          Container(color: Theme.of(context).hoverColor, height: 8),
          TextButton(
            child: Container(
                height: 40,
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

  //重命名
  rename(Favorite item) {
    String? name = item.name;
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: TextFormField(
              initialValue: name,
              decoration: const InputDecoration(label: Text("名称")),
              onChanged: (val) => name = val,
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
              TextButton(
                child: const Text('保存'),
                onPressed: () {
                  Navigator.maybePop(context);
                  setState(() {
                    item.name = name?.isEmpty == true ? null : name;
                    FavoriteStorage.flushConfig();
                  });
                },
              ),
            ],
          );
        });
  }

  //点击事件
  void onClick() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return NetworkTabController(
          proxyServer: widget.proxyServer,
          httpRequest: request,
          httpResponse: request.response,
          title: const Text("抓包详情", style: TextStyle(fontSize: 16)));
    }));
  }
}
