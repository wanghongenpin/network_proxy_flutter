import 'package:flutter/services.dart';

class Vpn {
  static const MethodChannel proxyVpnChannel = MethodChannel('com.proxy/proxyVpn');

  static startVpn(String host, int port) {
    proxyVpnChannel.invokeMethod("startVpn", {"proxyHost": host, "proxyPort": port});
  }

  static stopVpn() {
    proxyVpnChannel.invokeMethod("stopVpn");
  }
}
