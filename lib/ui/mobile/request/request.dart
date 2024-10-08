/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/components/request_block_manager.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/network/util/cache.dart';
import 'package:network_proxy/storage/favorites.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/mobile/request/repeat.dart';
import 'package:network_proxy/ui/mobile/request/request_editor.dart';
import 'package:network_proxy/ui/mobile/widgets/highlight.dart';
import 'package:network_proxy/utils/curl.dart';
import 'package:network_proxy/utils/lang.dart';
import 'package:network_proxy/utils/navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';

///请求行
class RequestRow extends StatefulWidget {
  final int index;
  final HttpRequest request;
  final ProxyServer proxyServer;
  final bool displayDomain;
  final Function(HttpRequest)? onRemove;

  const RequestRow(
      {super.key,
      required this.request,
      required this.proxyServer,
      this.displayDomain = true,
      this.onRemove,
      required this.index});

  @override
  State<StatefulWidget> createState() {
    return RequestRowState();
  }
}

class RequestRowState extends State<RequestRow> {
  static ExpiringCache<String, Image> imageCache = ExpiringCache<String, Image>(const Duration(minutes: 5));

  late HttpRequest request;
  HttpResponse? response;
  bool selected = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  change(HttpResponse response) {
    setState(() {
      this.response = response;
    });
  }

  @override
  void initState() {
    request = widget.request;
    response = request.response;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String url = widget.displayDomain ? request.requestUrl : request.path();

    var title = Strings.autoLineString('${request.method.name} $url');

    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    var contentType = response?.contentType.name.toUpperCase() ?? '';
    var packagesSize = getPackagesSize(request, response);

    var subTitle = '$time - [${response?.status.code ?? ''}] $contentType $packagesSize ${response?.costTime() ?? ''}';

    var highlightColor = KeywordHighlight.getHighlightColor(url);

    return ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        minLeadingWidth: 5,
        selected: selected,
        textColor: highlightColor,
        selectedColor: highlightColor,
        leading: appIcon(),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 2, style: const TextStyle(fontSize: 14)),
        subtitle: Text.rich(
            maxLines: 1,
            TextSpan(children: [
              TextSpan(text: '#${widget.index} ', style: const TextStyle(fontSize: 11, color: Colors.teal)),
              TextSpan(text: subTitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
        trailing: getIcon(response),
        contentPadding:
            Platform.isIOS ? const EdgeInsets.symmetric(horizontal: 8) : const EdgeInsets.only(left: 3, right: 5),
        onLongPress: menu,
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) {
            return NetworkTabController(
                proxyServer: widget.proxyServer,
                httpRequest: request,
                httpResponse: response,
                title: Text(localizations.captureDetail, style: const TextStyle(fontSize: 16)));
          }));
        });
  }

  Widget? appIcon() {
    if (Platform.isIOS) {
      return null;
    }
    if (request.processInfo == null) {
      return const Icon(Icons.question_mark, size: 38);
    }

    //如果有缓存图标直接返回图标
    if (request.processInfo!.hasCacheIcon) {
      return imageCache.putIfAbsent(request.processInfo!.id, () {
        return Image.memory(request.processInfo!.cacheIcon!, width: 40, gaplessPlayback: true);
      });
    }

    return FutureBuilder(
        future: request.processInfo!.getIcon(),
        builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, width: 40);
          }
          return const SizedBox(width: 40);
        });
  }

  ///菜单
  menu() {
    setState(() {
      selected = true;
    });

    showModalBottomSheet(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      builder: (ctx) {
        return Wrap(alignment: WrapAlignment.center, children: [
          menuCopyItem(localizations.copyUrl, () => widget.request.requestUrl),
          const Divider(thickness: 0.5, height: 5),
          menuCopyItem(localizations.copyCurl, () => curlRequest(widget.request)),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(width: double.infinity, child: Text(localizations.repeat, textAlign: TextAlign.center)),
              onPressed: () {
                onRepeat(widget.request);
                Navigator.maybePop(context);
              }),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(
                  width: double.infinity, child: Text(localizations.customRepeat, textAlign: TextAlign.center)),
              onPressed: () => showCustomRepeat(widget.request)),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child:
                  SizedBox(width: double.infinity, child: Text(localizations.editRequest, textAlign: TextAlign.center)),
              onPressed: () {
                Navigator.maybePop(context);
                var pageRoute = MaterialPageRoute(
                    builder: (context) =>
                        MobileRequestEditor(request: widget.request, proxyServer: widget.proxyServer));
                if (mounted) {
                  Navigator.push(context, pageRoute);
                } else {
                  NavigatorHelper.push(pageRoute);
                }
              }),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(width: double.infinity, child: Text(localizations.favorite, textAlign: TextAlign.center)),
              onPressed: () {
                FavoriteStorage.addFavorite(widget.request);
                FlutterToastr.show(localizations.addSuccess, context);
                Navigator.maybePop(context);
              }),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
            onPressed: () async {
              var requestBlockManager = await RequestBlockManager.instance;
              requestBlockManager.addBlockRequest(RequestBlockItem(true, widget.request.requestUrl, BlockType.blockRequest));
              if (mounted) {
                FlutterToastr.show(localizations.requestUrlBlocked, context);
                Navigator.maybePop(context);
              }
            },
            child: SizedBox(width: double.infinity, child: Text(localizations.blockRequestUrl, textAlign: TextAlign.center)),
          ),
          const Divider(thickness: 0.5, height: 5),
          TextButton(
              child: SizedBox(width: double.infinity, child: Text(localizations.delete, textAlign: TextAlign.center)),
              onPressed: () {
                widget.onRemove?.call(request);
                FlutterToastr.show(localizations.deleteSuccess, context);
                Navigator.maybePop(context);
              }),
          Container(color: Theme.of(context).hoverColor, height: 8),
          TextButton(
            child: Container(
                height: 45,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 10),
                child: Text(localizations.cancel, textAlign: TextAlign.center)),
            onPressed: () {
              Navigator.maybePop(context);
            },
          ),
        ]);
      },
    ).then((value) {
      selected = false;
      if (mounted) setState(() {});
    });
  }

  //显示高级重发
  showCustomRepeat(HttpRequest request) {
    Navigator.maybePop(context);
    var pageRoute = MaterialPageRoute(
        builder: (context) => futureWidget(SharedPreferences.getInstance(),
            (prefs) => MobileCustomRepeat(onRepeat: () => onRepeat(request), prefs: prefs)));
    if (mounted) {
      Navigator.push(context, pageRoute);
    } else {
      NavigatorHelper.push(pageRoute);
    }
  }

  onRepeat(HttpRequest request) {
    var httpRequest = request.copy(uri: request.requestUrl);
    var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
    HttpClients.proxyRequest(httpRequest, proxyInfo: proxyInfo);

    if (mounted) {
      FlutterToastr.show(localizations.reSendRequest, context);
    }
  }

  Widget menuCopyItem(String title, String Function() callback) {
    return TextButton(
        child: SizedBox(width: double.infinity, child: Text(title, textAlign: TextAlign.center)),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: callback.call())).then((value) {
            if (mounted) {
              FlutterToastr.show(localizations.copied, context);
              Navigator.maybePop(context);
            }
          });
        });
  }
}
