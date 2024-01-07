import 'package:flutter/services.dart';

class Vpn {
  static const MethodChannel proxyVpnChannel = MethodChannel('com.proxy/proxyVpn');

  static bool isVpnStarted = false; //vpn是否已经启动

  static startVpn(String host, int port, {List<String>? appList, bool? backgroundAudioEnable = true}) {
    proxyVpnChannel.invokeMethod("startVpn",
        {"proxyHost": host, "proxyPort": port, "allowApps": appList, "backgroundAudioEnable": backgroundAudioEnable});
    isVpnStarted = true;
  }

  static stopVpn() {
    proxyVpnChannel.invokeMethod("stopVpn");
    isVpnStarted = false;
  }

  //重启vpn
  static restartVpn(String host, int port, {List<String>? appList, bool? backgroundAudioEnable = true}) {
    proxyVpnChannel.invokeMethod("restartVpn",
        {"proxyHost": host, "proxyPort": port, "allowApps": appList, "backgroundAudioEnable": backgroundAudioEnable});

    isVpnStarted = true;
  }

  static Future<bool> isRunning() async {
    return await proxyVpnChannel.invokeMethod("isRunning");
  }
}
