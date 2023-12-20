import 'dart:io';

import 'package:flutter/services.dart';

///画中画
class PictureInPicture {
  static const MethodChannel _channel = MethodChannel('com.proxy/pictureInPicture');

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
