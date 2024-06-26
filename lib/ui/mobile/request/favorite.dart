import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/storage/favorites.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/mobile/request/repeat.dart';
import 'package:network_proxy/ui/mobile/request/request_editor.dart';
import 'package:network_proxy/utils/curl.dart';
import 'package:network_proxy/utils/python.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileFavorites extends StatefulWidget {
  final ProxyServer proxyServer;

  const MobileFavorites({super.key, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _FavoritesState();
  }
}

class _FavoritesState extends State<MobileFavorites> {
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(localizations.favorites, style: const TextStyle(fontSize: 16)), centerTitle: true),
        body: FutureBuilder(
            future: FavoriteStorage.favorites,
            builder: (BuildContext context, AsyncSnapshot<Queue<Favorite>> snapshot) {
              if (snapshot.hasData) {
                var favorites = snapshot.data ?? Queue();
                if (favorites.isEmpty) {
                  return Center(child: Text(localizations.emptyFavorite));
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

  const _FavoriteItem(this.favorite, {required this.onRemove, required this.proxyServer, required this.index});

  @override
  State<_FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<_FavoriteItem> {
  late HttpRequest request;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Wrap(alignment: WrapAlignment.center, children: [
          menuItem(localizations.copyUrl, () => request.requestUrl),
          const Divider(thickness: 0.5, height: 5),
          menuItem(localizations.copyCurl, () => curlRequest(request)),
          const Divider(thickness: 0.5, height: 5),
          menuItem(localizations.copyAsPythonRequests, () => copyAsPythonRequests(request)),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(width: double.infinity, child: Text(localizations.rename, textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context).pop();
                rename(widget.favorite);
              }),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(width: double.infinity, child: Text(localizations.repeat, textAlign: TextAlign.center)),
              onPressed: () {
                onRepeat(request);
                Navigator.of(context).pop();
              }),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(
                  width: double.infinity, child: Text(localizations.customRepeat, textAlign: TextAlign.center)),
              onPressed: () => showCustomRepeat(request)),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child:
                  SizedBox(width: double.infinity, child: Text(localizations.editRequest, textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => MobileRequestEditor(request: request, proxyServer: widget.proxyServer)));
              }),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(
                  width: double.infinity, child: Text(localizations.deleteFavorite, textAlign: TextAlign.center)),
              onPressed: () {
                widget.onRemove?.call(widget.favorite);
                FlutterToastr.show(localizations.deleteSuccess, context);
                Navigator.of(context).pop();
              }),
          Container(color: Theme.of(context).hoverColor, height: 8),
          TextButton(
            child: Container(
                height: 50,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10),
                child: Text(localizations.cancel, textAlign: TextAlign.center)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ]);
      },
    );
  }

  //显示高级重发
  showCustomRepeat(HttpRequest request) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => futureWidget(SharedPreferences.getInstance(),
            (prefs) => MobileCustomRepeat(onRepeat: () => onRepeat(request), prefs: prefs))));
  }

  onRepeat(HttpRequest request) {
    var httpRequest = request.copy(uri: request.requestUrl);
    var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
    HttpClients.proxyRequest(httpRequest, proxyInfo: proxyInfo);

    if (mounted) {
      FlutterToastr.show(localizations.reSendRequest, context);
    }
  }

  Widget menuItem(String title, String Function() callback) {
    return TextButton(
        child: SizedBox(width: double.infinity, child: Text(title, textAlign: TextAlign.center)),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: callback.call())).then((value) {
            FlutterToastr.show(localizations.copied, context);
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
              decoration: InputDecoration(label: Text(localizations.name)),
              onChanged: (val) => name = val,
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(context), child: Text(localizations.cancel)),
              TextButton(
                child: Text(localizations.save),
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
          title: Text(localizations.captureDetail, style: const TextStyle(fontSize: 16)));
    }));
  }
}
