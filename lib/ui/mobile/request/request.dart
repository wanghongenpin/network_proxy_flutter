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
import 'package:network_proxy/utils/lang.dart';

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
  late HttpRequest request;
  HttpResponse? response;

  bool selected = false;

  Color? highlightColor; //高亮颜色

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
    var title =
        Strings.autoLineString('${request.method.name} ${widget.displayDomain ? request.requestUrl : request.path()}');

    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    var contentType = response?.contentType.name.toUpperCase() ?? '';
    var packagesSize = getPackagesSize(request, response);

    var subTitle = '$time - [${response?.status.code ?? ''}] $contentType $packagesSize ${response?.costTime() ?? ''}';

    return ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        minLeadingWidth: 5,
        selected: selected,
        textColor: highlightColor,
        selectedColor: highlightColor,
        leading: getIcon(response),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 2, style: const TextStyle(fontSize: 14)),
        subtitle: Text.rich(
            maxLines: 1,
            TextSpan(children: [
              TextSpan(text: '#${widget.index} ', style: const TextStyle(fontSize: 12, color: Colors.teal)),
              TextSpan(text: subTitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
        trailing: const Icon(Icons.chevron_right, size: 22),
        dense: true,
        contentPadding: const EdgeInsets.only(left: 3),
        onLongPress: showMenu,
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  settings: const RouteSettings(name: "NetworkTabController"),
                  builder: (context) {
                    return NetworkTabController(
                        proxyServer: widget.proxyServer,
                        httpRequest: request,
                        httpResponse: response,
                        title: Text(localizations.captureDetail, style: const TextStyle(fontSize: 16)));
                  }));
        });
  }

  showMenu() {
    setState(() {
      selected = true;
    });
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        builder: (ctx) {
          return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                children: [
                  copyItem(),
                  const Divider(thickness: 0.3, height: 3),
                  repeatItem(),
                  const Divider(thickness: 0.3, height: 5),
                  ListTile(
                      dense: true,
                      title: Text(localizations.highlight, textAlign: TextAlign.center),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        //显示高亮菜单
                        Navigator.of(context).pop();
                        showHighlightMenu();
                      }),
                  ListTile(
                    dense: true,
                    title: Text(localizations.favorite, textAlign: TextAlign.center),
                    trailing: const Icon(Icons.favorite),
                    onTap: () {
                      FavoriteStorage.addFavorite(widget.request);
                      FlutterToastr.show(localizations.addSuccess, context);
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                      onTap: () {
                        widget.onRemove?.call(request);
                        FlutterToastr.show(localizations.deleteSuccess, context);
                        Navigator.of(context).pop();
                      },
                      dense: true,
                      title: Text(localizations.delete, textAlign: TextAlign.center),
                      trailing: const Icon(Icons.remove)),
                  Container(
                    color: Theme.of(context).hoverColor,
                    height: 8,
                  ),
                  ListTile(
                      dense: true,
                      onTap: () => Navigator.of(context).pop(),
                      title: Container(
                          height: 50,
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(localizations.cancel, textAlign: TextAlign.center)),
                      trailing: const Icon(Icons.cancel_presentation)),
                ],
              ));
        }).then((value) => setState(() {
          selected = false;
        }));
  }

  Widget copyItem() {
    var dividerColor = Theme.of(context).dividerColor;
    var styleFrom = OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14),
        side: BorderSide(width: 0.3, color: dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)));

    return Wrap(alignment: WrapAlignment.center, children: [
      Container(
          padding: const EdgeInsets.only(left: 15, top: 10, bottom: 5),
          width: double.infinity,
          child: Text(localizations.copy, textAlign: TextAlign.left, style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: double.infinity,
          child: Wrap(alignment: WrapAlignment.spaceAround, spacing: 15, children: [
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.request.requestUrl)).then((value) {
                  FlutterToastr.show(localizations.copied, context);
                  Navigator.of(context).pop();
                });
              },
              style: styleFrom,
              child: Text(localizations.copyUrl),
            ),
            OutlinedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: curlRequest(widget.request))).then((value) {
                    FlutterToastr.show(localizations.copied, context);
                    Navigator.of(context).pop();
                  });
                },
                style: styleFrom,
                child: Text(localizations.copyCurl))
          ]))
    ]);
  }

  Widget repeatItem() {
    var dividerColor = Theme.of(context).dividerColor;
    var styleFrom = OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14),
        side: BorderSide(width: 0.3, color: dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)));

    return Wrap(alignment: WrapAlignment.center, children: [
      Container(
          padding: const EdgeInsets.only(left: 15, top: 5, bottom: 5),
          width: double.infinity,
          child: Text(localizations.repeat, textAlign: TextAlign.left, style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: double.infinity,
          child: Wrap(alignment: WrapAlignment.spaceAround, spacing: 15, children: [
            OutlinedButton(
              onPressed: () {
                onRepeat(widget.request);
                Navigator.of(context).pop();
              },
              style: styleFrom,
              child: Text(localizations.repeat),
            ),
            OutlinedButton(
                onPressed: () => showCustomRepeat(widget.request),
                style: styleFrom,
                child: Text(localizations.customRepeat)),
            OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          MobileRequestEditor(request: widget.request, proxyServer: widget.proxyServer)));
                },
                style: styleFrom,
                child: Text(localizations.editRequest))
          ]))
    ]);
  }

  //显示高级重发
  showCustomRepeat(HttpRequest request) {
    Navigator.of(context).pop();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => MobileCustomRepeat(onRepeat: () => onRepeat(request))));
  }

  onRepeat(HttpRequest request) {
    var httpRequest = request.copy(uri: request.requestUrl);
    var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
    HttpClients.proxyRequest(httpRequest, proxyInfo: proxyInfo);

    if (mounted) {
      FlutterToastr.show(localizations.reSendRequest, context);
    }
  }

  void showHighlightMenu() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        enableDrag: true,
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.red),
                  title: Text(localizations.red),
                  onTap: () {
                    setState(() {
                      highlightColor = Colors.red;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.yellow),
                  title: Text(localizations.yellow),
                  onTap: () {
                    setState(() {
                      highlightColor = Colors.yellow.shade600;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.blue),
                  title: Text(localizations.blue),
                  onTap: () {
                    setState(() {
                      highlightColor = Colors.blue;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.green),
                  title: Text(localizations.green),
                  onTap: () {
                    setState(() {
                      highlightColor = Colors.green;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.circle, color: Colors.grey),
                  title: Text(localizations.gray),
                  onTap: () {
                    setState(() {
                      highlightColor = Colors.grey;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: Text(localizations.reset),
                  onTap: () {
                    setState(() {
                      highlightColor = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 10)
              ],
            ),
          );
        });
  }
}
