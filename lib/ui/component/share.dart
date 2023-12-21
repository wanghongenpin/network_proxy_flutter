import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/mobile/request/request_editor.dart';
import 'package:network_proxy/utils/curl.dart';
import 'package:share_plus/share_plus.dart';

///分享按钮
class ShareWidget extends StatelessWidget {
  final ProxyServer proxyServer;
  final HttpRequest? request;
  final HttpResponse? response;

  const ShareWidget({super.key, required this.proxyServer, this.request, this.response});

  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.share),
        onPressed: () {
          showMenu(context: context, position: menuPosition(context), items: [
            PopupMenuItem(
              child: const Text('分享请求链接'),
              onTap: () {
                if (request == null) {
                  FlutterToastr.show("请求为空", context);
                  return;
                }
                Share.share(request!.requestUrl, subject: "ProxyPin全平台抓包软件");
              },
            ),
            PopupMenuItem(
                child: const Text('分享请求和响应'),
                onTap: () {
                  if (request == null) {
                    FlutterToastr.show("请求为空", context);
                    return;
                  }
                  var file = XFile.fromData(utf8.encode(copyRequest(request!, response)),
                      name: "抓包详情", mimeType: "txt");
                  Share.shareXFiles([file], text: "ProxyPin全平台抓包软件");
                }),
            PopupMenuItem(
                child: const Text('分享 cURL 请求'),
                onTap: () {
                  if (request == null) {
                    return;
                  }
                  var file = XFile.fromData(utf8.encode(curlRequest(request!)),
                      name: "cURL.txt", mimeType: "txt");
                  Share.shareXFiles([file], text: "ProxyPin全平台抓包软件");
                }),
            PopupMenuItem(
                child: const Text('编辑请求重放'),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => MobileRequestEditor(request: request, proxyServer: proxyServer)));
                  });
                }),
          ]);
        });
  }
}
