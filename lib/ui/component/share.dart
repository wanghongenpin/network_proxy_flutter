import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/components/script_manager.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/mobile/request/request_editor.dart';
import 'package:network_proxy/ui/mobile/setting/script.dart';
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
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return IconButton(
        icon: const Icon(Icons.share),
        onPressed: () {
          showMenu(context: context, position: menuPosition(context), items: [
            PopupMenuItem(
              child: Text(localizations.shareUrl),
              onTap: () {
                if (request == null) {
                  FlutterToastr.show("Request is empty", context);
                  return;
                }
                Share.share(request!.requestUrl, subject: localizations.proxyPinSoftware);
              },
            ),
            PopupMenuItem(
                child: Text(localizations.shareRequestResponse),
                onTap: () {
                  if (request == null) {
                    FlutterToastr.show("Request is empty", context);
                    return;
                  }
                  var file = XFile.fromData(utf8.encode(copyRequest(request!, response)),
                      name: localizations.captureDetail, mimeType: "txt");
                  Share.shareXFiles([file], fileNameOverrides: ['request.txt'], text: localizations.proxyPinSoftware);
                }),
            PopupMenuItem(
                child: Text(localizations.shareCurl),
                onTap: () {
                  if (request == null) {
                    return;
                  }
                  var text = curlRequest(request!);
                  var file = XFile.fromData(utf8.encode(text), name: "cURL.txt", mimeType: "txt");
                  Share.shareXFiles([file], fileNameOverrides: ["cURL.txt"], text: localizations.proxyPinSoftware);
                }),
            PopupMenuItem(
                child: Text(localizations.requestEdit),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => MobileRequestEditor(request: request, proxyServer: proxyServer)));
                  });
                }),
            PopupMenuItem(
                child: Text(localizations.script),
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    var scriptManager = await ScriptManager.instance;

                    var url = '${request?.remoteDomain()}${request?.path()}';
                    var scriptItem = (scriptManager).list.firstWhereOrNull((it) => it.url == url);
                    String? script = scriptItem == null ? null : await scriptManager.getScript(scriptItem);

                    if (!context.mounted) return;

                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            ScriptEdit(scriptItem: scriptItem, script: script, url: scriptItem?.url ?? url)));
                  });
                }),
          ]);
        });
  }
}
