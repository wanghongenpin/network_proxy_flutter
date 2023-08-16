import 'package:flutter/services.dart';

class Vpn {
  static const MethodChannel proxyVpnChannel = MethodChannel('com.proxy/proxyVpn');

  static startVpn(String host, int port, [List<String>? appList]) {
    proxyVpnChannel.invokeMethod("startVpn", {"proxyHost": host, "proxyPort": port, "allowApps": appList});
  }

  static stopVpn() {
    proxyVpnChannel.invokeMethod("stopVpn");
  }

  //重启vpn
  static restartVpn(String host, int port, [List<String>? appList]) {
    proxyVpnChannel.invokeMethod("restartVpn", {"proxyHost": host, "proxyPort": port, "allowApps": appList});
  }
}
