import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_desktop_context_menu/flutter_desktop_context_menu.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/storage/favorites.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/repeat.dart';
import 'package:network_proxy/utils/curl.dart';
import 'package:network_proxy/utils/lang.dart';
import 'package:window_manager/window_manager.dart';

/// 请求 URI
/// @author wanghongen
/// 2023/10/8
class RequestWidget extends StatefulWidget {
  final Color? color;
  final HttpRequest request;
  final ValueWrap<HttpResponse> response = ValueWrap();

  final ProxyServer proxyServer;
  final Function(RequestWidget)? remove;

  RequestWidget(this.request, {Key? key, this.color = Colors.green, required this.proxyServer, this.remove})
      : super(key: GlobalKey<_RequestWidgetState>());

  @override
  State<RequestWidget> createState() => _RequestWidgetState();

  void setResponse(HttpResponse response) {
    this.response.set(response);
    var state = key as GlobalKey<_RequestWidgetState>;
    state.currentState?.changeState();
  }
}

class _RequestWidgetState extends State<RequestWidget> {
  //选择的节点
  static _RequestWidgetState? selectedState;

  bool selected = false;

  Color? highlightColor; //高亮颜色

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
        onSecondaryTap: contextualMenu,
        child: ListTile(
            minLeadingWidth: 5,
            textColor: highlightColor,
            selectedColor: highlightColor,
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

  contextualMenu() {
    Menu menu = Menu(items: [
      MenuItem(
        label: localizations.copyUrl,
        onClick: (_) {
          var requestUrl = widget.request.requestUrl;
          Clipboard.setData(ClipboardData(text: requestUrl))
              .then((value) => FlutterToastr.show(localizations.copied, context));
        },
      ),
      MenuItem(
        label: localizations.copyRequestResponse,
        onClick: (_) {
          Clipboard.setData(ClipboardData(text: copyRequest(widget.request, widget.response.get())))
              .then((value) => FlutterToastr.show(localizations.copied, context));
        },
      ),
      MenuItem(
        label: localizations.copyCurl,
        onClick: (_) {
          Clipboard.setData(ClipboardData(text: curlRequest(widget.request)))
              .then((value) => FlutterToastr.show(localizations.copied, context));
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: localizations.repeat,
        onClick: (_) => onRepeat(widget.request),
      ),
      MenuItem(
        label: localizations.customRepeat,
        onClick: (_) => showCustomRepeat(widget.request),
      ),
      MenuItem(
        label: localizations.editRequest,
        onClick: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            requestEdit();
          });
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: localizations.favorite,
        onClick: (_) {
          FavoriteStorage.addFavorite(widget.request);
          FlutterToastr.show(localizations.operationSuccess, context);
        },
      ),
      MenuItem(
        label: localizations.highlight,
        type: 'submenu',
        submenu: highlightMenu(),
        onClick: (_) {
          setState(() {
            highlightColor = Colors.red;
          });
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: localizations.delete,
        onClick: (_) {
          widget.remove?.call(widget);
        },
      ),
    ]);

    popUpContextMenu(menu);
  }

  ///高亮
  Menu highlightMenu() {
    return Menu(
      items: [
        MenuItem(
            label: localizations.red,
            onClick: (_) {
              setState(() {
                highlightColor = Colors.red;
              });
            }),
        MenuItem(
            label: localizations.yellow,
            onClick: (_) {
              setState(() {
                highlightColor = Colors.yellow.shade600;
              });
            }),
        MenuItem(
            label: localizations.blue,
            onClick: (_) {
              setState(() {
                highlightColor = Colors.blue;
              });
            }),
        MenuItem(
            label: localizations.green,
            onClick: (_) {
              setState(() {
                highlightColor = Colors.green;
              });
            }),
        MenuItem(
            label: localizations.gray,
            onClick: (_) {
              setState(() {
                highlightColor = Colors.grey;
              });
            }),
        MenuItem.separator(),
        MenuItem(
            label: localizations.reset,
            onClick: (_) {
              setState(() {
                highlightColor = null;
              });
            }),
      ],
    );
  }

  //显示高级重发
  showCustomRepeat(HttpRequest request) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return CustomRepeatDialog(onRepeat: () => onRepeat(request));
        });
  }

  onRepeat(HttpRequest httpRequest) {
    var request = httpRequest.copy(uri: httpRequest.requestUrl);
    var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
    HttpClients.proxyRequest(request, proxyInfo: proxyInfo);

    FlutterToastr.show(localizations.reSendRequest, context);
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

    window.setTitle(localizations.requestEdit);
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
    NetworkTabController.current?.change(widget.request, widget.response.get() ?? widget.request.response);
  }
}
