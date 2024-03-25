import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:network_proxy/native/installed_apps.dart';
import 'package:network_proxy/native/process_info.dart';
import 'package:network_proxy/network/util/socket_address.dart';

import 'cache.dart';

void main() async {
  var processInfo = await ProcessInfoUtils.getProcess(512);
  print(await processInfo!._getIconPath());
  // await ProcessInfoUtils.getMacIcon(processInfo!.path);
  // print(await ProcessInfoUtils.getProcessByPort(63194));
  print((await ProcessInfoUtils.getProcess(30025))?._getIconPath());
}

class ProcessInfoUtils {
  static final processInfoCache = ExpiringCache<String, ProcessInfo>(const Duration(minutes: 5));

  static Future<ProcessInfo?> getProcessByPort(InetSocketAddress socketAddress, String cacheKeyPre) async {
    if (Platform.isAndroid) {
      var app = await ProcessInfoPlugin.getProcessByPort(socketAddress.host, socketAddress.port);
      if (app != null) {
        return ProcessInfo(app.packageName ?? '', app.name ?? '', app.name ?? '', icon: app.icon);
      }
      if (socketAddress.host == '127.0.0.1') return ProcessInfo('com.network.proxy', "ProxyPin", '');
      return null;
    }

    if (Platform.isMacOS) {
      var results = await Process.run('bash', [
        '-c',
        _concatCommands(['lsof -nP -iTCP:${socketAddress.port} |grep "${socketAddress.port}->"'])
      ]);

      if (results.exitCode == 0) {
        var lines = LineSplitter.split(results.stdout);

        for (var line in lines) {
          var parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 9) {
            var pid = int.tryParse(parts[1]);
            if (pid != null) {
              String cacheKey = "$cacheKeyPre:$pid";
              var processInfo = processInfoCache.get(cacheKey);
              if (processInfo != null) return processInfo;

              processInfo = await getProcess(pid);
              processInfoCache.set(cacheKey, processInfo!);
              return processInfo;
            }
          }
        }
      }
    }
    return null;
  }

  static Future<ProcessInfo?> getProcess(int pid) async {
    if (Platform.isMacOS) {
      var results = await Process.run('bash', [
        '-c',
        _concatCommands(['ps -p $pid -o pid= -o comm='])
      ]);
      if (results.exitCode == 0) {
        var lines = LineSplitter.split(results.stdout);
        for (var line in lines) {
          var parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            parts.removeAt(0).trim();
            var path = parts.join(" ").split(".app/")[0];
            String name = path.substring(path.lastIndexOf('/') + 1);
            return ProcessInfo(name, name, "$path.app");
          }
        }
      }
    }

    return null;
  }

  static _concatCommands(List<String> commands) {
    return commands.where((element) => element.isNotEmpty).join(' && ');
  }
}

class ProcessInfo {
  static final _iconCache = ExpiringCache<String, Uint8List?>(const Duration(minutes: 5));

  final String id; //应用包名
  final String name; //应用名称
  final String path;

  Uint8List? icon;

  ProcessInfo(this.id, this.name, this.path, {this.icon});

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(json['id'], json['name'], json['path']);
  }

  Future<String> _getIconPath() async {
    return _getMacIcon(path);
  }

  Future<Uint8List> getIcon() async {
    if (icon != null) return icon!;
    if (_iconCache.get(id) != null) return _iconCache.get(id)!;

    try {
      if (Platform.isAndroid) {
        icon = (await InstalledApps.getAppInfo(id)).icon;
      }

      if (Platform.isMacOS) {
        var macIcon = await _getIconPath();
        icon = await File(macIcon).readAsBytes();
      }
      icon = icon ?? Uint8List(0);
      _iconCache.set(id, icon);
    } catch (e) {
      icon = Uint8List(0);
    }
    return icon!;
  }

  static Future<String> _getMacIcon(String path) async {
    var xml = await File('$path/Contents/Info.plist').readAsString();
    var key = "<key>CFBundleIconFile</key>";
    var indexOf = xml.indexOf(key);
    var iconName = xml.substring(indexOf + key.length, xml.indexOf("</string>", indexOf));
    iconName = iconName.trim().replaceAll("<string>", "");
    var icon = iconName.endsWith(".icns") ? iconName : "$iconName.icns";
    String iconPath = "$path/Contents/Resources/$icon";
    return iconPath;
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'path': path};
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
