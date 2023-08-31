import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/ui/component/encoder.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

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
  window.setTitle('编码');
  window
    ..setFrame(const Offset(80, 80) & Size(900 * ratio, 600 * ratio))
    ..center()
    ..show();
}
