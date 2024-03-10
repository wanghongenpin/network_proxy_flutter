import 'package:flutter/services.dart';
import 'package:network_proxy/native/installed_apps.dart';

class ProcessInfoPlugin {
  static const MethodChannel _methodChannel = MethodChannel('com.proxy/processInfo');

  static Future<AppInfo?> getProcessByPort(String host, int port) {
    return _methodChannel.invokeMethod<Map>('getProcessByPort', {"host": host, "port": port}).then(
        (value) => value == null ? null : AppInfo.formJson(value));
  }
}
