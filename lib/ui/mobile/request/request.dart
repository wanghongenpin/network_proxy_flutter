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
    var title = '${request.method.name} ${widget.displayDomain ? request.requestUrl : request.path()}';

    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    var contentType = response?.contentType.name.toUpperCase() ?? '';
    var packagesSize = getPackagesSize(request, response);

    var subTitle =
        '$time - [${response?.status.code ?? ''}] $contentType $packagesSize ${response?.costTime() ?? ''}';

    return ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        minLeadingWidth: 5,
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
        onLongPress: menu,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            settings: const RouteSettings(name: "NetworkTabController"),
              builder: (context) {
            return NetworkTabController(
                proxyServer: widget.proxyServer,
                httpRequest: request,
                httpResponse: response,
                title: const Text("抓包详情", style: TextStyle(fontSize: 16)));
          }));
        });
  }

  ///菜单
  menu() {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      builder: (ctx) {
        return Wrap(alignment: WrapAlignment.center, children: [
          menuItem("复制请求链接", () => widget.request.requestUrl),
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
              child: const SizedBox(width: double.infinity, child: Text("收藏请求", textAlign: TextAlign.center)),
              onPressed: () {
                FavoriteStorage.addFavorite(widget.request);
                FlutterToastr.show('收藏成功', context);
                Navigator.of(context).pop();
              }),
          const Divider(thickness: 0.5),
          TextButton(
              child: const SizedBox(width: double.infinity, child: Text("删除", textAlign: TextAlign.center)),
              onPressed: () {
                widget.onRemove?.call(request);
                FlutterToastr.show("删除成功", context);
                Navigator.of(context).pop();
              }),
          Container(
            color: Theme.of(context).hoverColor,
            height: 8,
          ),
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
}
