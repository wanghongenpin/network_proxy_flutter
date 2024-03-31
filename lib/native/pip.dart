import 'dart:io';

import 'package:flutter/services.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/launch/launch.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/utils/lang.dart';

///画中画
class PictureInPicture {
  static bool inPip = false;

  static final MethodChannel _channel = const MethodChannel('com.proxy/pictureInPicture')
    ..setMethodCallHandler((call) async {
      logger.d("pictureInPicture MethodCallHandler ${call.method}");
      if (call.method == 'cleanSession') {
        MobileHomeState.requestStateKey.currentState?.clean();
      } else if (call.method == 'exitPictureInPictureMode') {
        inPip = false;
        Vpn.isRunning().then((value) {
          Vpn.isVpnStarted = value;
          SocketLaunch.startStatus.value = ValueWrap.of(value);
        });
      }

      return Future.value();
    });

  ///进入画中画模式
  static Future<bool> enterPictureInPictureMode(String host, int port,
      {List<String>? appList, List<String>? disallowApps}) async {
    final bool enterPictureInPictureMode = await _channel.invokeMethod('enterPictureInPictureMode',
        {"proxyHost": host, "proxyPort": port, "allowApps": appList, "disallowApps": disallowApps});
    inPip = true;

    return enterPictureInPictureMode;
  }

  ///退出画中画模式
  static Future<bool> exitPictureInPictureMode() async {
    final bool exitPictureInPictureMode = await _channel.invokeMethod('exitPictureInPictureMode');
    return exitPictureInPictureMode;
  }

  ///发送数据
  static Future<bool> addData(String text) async {
    if (Platform.isIOS && inPip) {
      _channel.invokeMethod('addData', text.fixAutoLines());
    }
    return false;
  }
}
