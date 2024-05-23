import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/components/script_manager.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/component/device.dart';
import 'package:network_proxy/ui/component/encoder.dart';
import 'package:network_proxy/ui/component/js_run.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/content/body.dart';
import 'package:network_proxy/ui/desktop/left/request_editor.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/request_rewrite.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/script.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

bool isMultiWindow = false;

///多窗口
Widget multiWindow(int windowId, Map<dynamic, dynamic> argument) {
  isMultiWindow = true;
  //请求编辑器
  if (argument['name'] == 'RequestEditor') {
    return RequestEditor(
        windowController: WindowController.fromWindowId(windowId),
        request: argument['request'] == null ? null : HttpRequest.fromJson(argument['request']));
  }
  //请求体
  if (argument['name'] == 'HttpBodyWidget') {
    return HttpBodyWidget(
        windowController: WindowController.fromWindowId(windowId),
        httpMessage: HttpMessage.fromJson(argument['httpMessage']),
        inNewWindow: true,
        hideRequestRewrite: true);
  }
  //编码
  if (argument['name'] == 'EncoderWidget') {
    return EncoderWidget(
        type: EncoderType.nameOf(argument['type']),
        text: argument['text'],
        windowController: WindowController.fromWindowId(windowId));
  }
  //脚本
  if (argument['name'] == 'ScriptWidget') {
    return ScriptWidget(windowId: windowId);
  }
  //请求重写
  if (argument['name'] == 'RequestRewriteWidget') {
    return futureWidget(
        RequestRewrites.instance, (data) => RequestRewriteWidget(windowId: windowId, requestRewrites: data));
  }

  //脚本日志
  if (argument['name'] == 'ScriptConsoleWidget') {
    return ScriptConsoleWidget(windowId: windowId);
  }

  if (argument['name'] == 'JavaScript') {
    return const JavaScript();
  }

  return const SizedBox();
}

enum Operation {
  add,
  update,
  delete,
  enabled,
  refresh;

  static Operation of(String name) {
    return values.firstWhere((element) => element.name == name);
  }
}

class MultiWindow {
  /// 刷新请求重写
  static Future<void> invokeRefreshRewrite(Operation operation,
      {int? index, RequestRewriteRule? rule, List<RewriteItem>? items, bool? enabled}) async {
    await DesktopMultiWindow.invokeMethod(0, "refreshRequestRewrite", {
      "enabled": enabled,
      "operation": operation.name,
      'index': index,
      'rule': rule?.toJson(),
      'items': items?.map((e) => e.toJson()).toList()
    });
  }

  static bool _refreshRewrite = false;

  static Future<void> _handleRefreshRewrite(Operation operation, Map<dynamic, dynamic> arguments) async {
    RequestRewrites requestRewrites = await RequestRewrites.instance;

    switch (operation) {
      case Operation.add:
      case Operation.update:
        var rule = RequestRewriteRule.formJson(arguments['rule']);
        List<dynamic>? list = arguments['items'] as List<dynamic>?;
        List<RewriteItem>? items = list?.map((e) => RewriteItem.fromJson(e)).toList();

        if (operation == Operation.add) {
          await requestRewrites.addRule(rule, items!);
        } else {
          await requestRewrites.updateRule(arguments['index'], rule, items);
        }
        break;
      case Operation.delete:
        var rule = requestRewrites.rules.removeAt(arguments['index']);
        requestRewrites.rewriteItemsCache.remove(rule); //删除缓存
        break;
      case Operation.enabled:
        requestRewrites.enabled = arguments['enabled'];
        break;
      default:
        break;
    }

    if (_refreshRewrite) return;
    _refreshRewrite = true;
    Future.delayed(const Duration(milliseconds: 1000), () async {
      _refreshRewrite = false;
      requestRewrites.flushRequestRewriteConfig();
    });
  }
}

bool _registerHandler = false;

/// 桌面端多窗口 注册方法处理器
void registerMethodHandler() {
  if (_registerHandler) {
    return;
  }
  _registerHandler = true;
  DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
    logger.d('${call.method} $fromWindowId ${call.arguments}');

    if (call.method == 'refreshScript') {
      await ScriptManager.instance.then((value) {
        return value.reloadScript();
      });
      return 'done';
    }

    if (call.method == 'refreshRequestRewrite') {
      await MultiWindow._handleRefreshRewrite(Operation.of(call.arguments['operation']), call.arguments);
      return 'done';
    }

    if (call.method == 'getApplicationSupportDirectory') {
      return getApplicationSupportDirectory().then((it) => it.path);
    }

    if (call.method == 'getSaveLocation') {
      String? path = (await getSaveLocation(suggestedName: call.arguments))?.path;
      if (Platform.isWindows) windowManager.blur();
      return path;
    }

    if (call.method == 'openFile') {
      XTypeGroup typeGroup = XTypeGroup(
          extensions: <String>[call.arguments],
          uniformTypeIdentifiers: Platform.isMacOS ? const ['public.item'] : null);
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (Platform.isWindows) windowManager.blur();
      return file?.path;
    }

    if (call.method == 'launchUrl') {
      return launchUrl(Uri.parse(call.arguments));
    }

    if (call.method == 'registerConsoleLog') {
      ScriptManager.registerConsoleLog(fromWindowId);
      return "done";
    }

    if (call.method == 'deviceId') {
      return await DeviceUtils.desktopDeviceId();
    }

    return 'done';
  });
}

///打开编码窗口
encodeWindow(EncoderType type, BuildContext context, [String? text]) async {
  if (Platforms.isMobile()) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => EncoderWidget(type: type, text: text)));
    return;
  }

  var ratio = 1.0;
  if (Platform.isWindows) {
    ratio = WindowManager.instance.getDevicePixelRatio();
  }
  final window = await DesktopMultiWindow.createWindow(jsonEncode(
    {'name': 'EncoderWidget', 'type': type.name, 'text': text},
  ));
  if (!context.mounted) return;
  window.setTitle(AppLocalizations.of(context)!.encode);
  window
    ..setFrame(const Offset(80, 80) & Size(900 * ratio, 600 * ratio))
    ..center()
    ..show();
}

///打开脚本窗口
openScriptWindow() async {
  var ratio = 1.0;
  if (Platform.isWindows) {
    ratio = WindowManager.instance.getDevicePixelRatio();
  }
  registerMethodHandler();
  final window = await DesktopMultiWindow.createWindow(jsonEncode(
    {'name': 'ScriptWidget'},
  ));

  // window.setTitle('script');
  window.setTitle('Script');
  window
    ..setFrame(const Offset(30, 0) & Size(800 * ratio, 690 * ratio))
    ..center()
    ..show();
}

///打开请求重写窗口
openRequestRewriteWindow() async {
  var ratio = 1.0;
  if (Platform.isWindows) {
    ratio = WindowManager.instance.getDevicePixelRatio();
  }
  registerMethodHandler();
  final window = await DesktopMultiWindow.createWindow(jsonEncode(
    {'name': 'RequestRewriteWidget'},
  ));
  // window.setTitle('请求重写');
  window.setTitle('Request Rewrite');
  window
    ..setFrame(const Offset(50, 0) & Size(800 * ratio, 650 * ratio))
    ..center();
  window.show();
}

openScriptConsoleWindow() async {
  var ratio = 1.0;
  if (Platform.isWindows) {
    ratio = WindowManager.instance.getDevicePixelRatio();
  }
  final window = await DesktopMultiWindow.createWindow(jsonEncode(
    {'name': 'ScriptConsoleWidget'},
  ));
  window.setTitle('Script Console');
  window
    ..setFrame(const Offset(50, 0) & Size(900 * ratio, 650 * ratio))
    ..center();
  window.show();
}
