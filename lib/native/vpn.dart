import 'package:flutter/services.dart';

class Vpn {
  static const MethodChannel proxyVpnChannel = MethodChannel('com.proxy/proxyVpn');

  static bool isVpnStarted = false; //vpn是否已经启动

  static startVpn(String host, int port, [List<String>? appList]) {
    proxyVpnChannel.invokeMethod("startVpn", {"proxyHost": host, "proxyPort": port, "allowApps": appList});
    isVpnStarted = true;
  }

  static stopVpn() {
    proxyVpnChannel.invokeMethod("stopVpn");
    isVpnStarted = false;
  }

  //重启vpn
  static restartVpn(String host, int port, [List<String>? appList]) {
    proxyVpnChannel.invokeMethod("restartVpn", {"proxyHost": host, "proxyPort": port, "allowApps": appList});
    isVpnStarted = true;
  }
}
