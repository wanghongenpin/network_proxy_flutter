import 'dart:io';

import 'package:flutter/services.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';

///画中画
class PictureInPicture {
  static final MethodChannel _channel = const MethodChannel('com.proxy/pictureInPicture')
    ..setMethodCallHandler((call) async {
      logger.d("pictureInPicture MethodCallHandler ${call.method}");
      if (call.method == 'cleanSession') {
        MobileHomeState.requestStateKey.currentState?.clean();
      }
      return Future.value();
    });

  ///进入画中画模式
  static Future<bool> enterPictureInPictureMode() async {
    if (Platform.isAndroid) {
      final bool enterPictureInPictureMode = await _channel.invokeMethod('enterPictureInPictureMode');
      return enterPictureInPictureMode;
    }
    return false;
  }

  ///退出画中画模式
  static Future<bool> exitPictureInPictureMode() async {
    final bool exitPictureInPictureMode = await _channel.invokeMethod('exitPictureInPictureMode');
    return exitPictureInPictureMode;
  }
}
