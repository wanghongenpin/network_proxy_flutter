import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:network_proxy/network/util/socket_address.dart';

import 'cache.dart';

void main() async {
  var processInfo = await ProcessInfoUtils.getProcess(512);
  print(await processInfo!.getIconPath());
  // await ProcessInfoUtils.getMacIcon(processInfo!.path);
  // print(await ProcessInfoUtils.getProcessByPort(63194));
  print((await ProcessInfoUtils.getProcess(30025))?.getIconPath());
}

class ProcessInfoUtils {
  static var processInfoCache = ExpiringCache<String, ProcessInfo>(const Duration(minutes: 5));

  static Future<ProcessInfo?> getProcessByPort(InetSocketAddress socketAddress, String cacheKeyPre) async {
    if (Platform.isAndroid) {
      // var app = await ProcessInfoPlugin.getProcessByPort(socketAddress.host, socketAddress.port);
      // print(app);
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
            return ProcessInfo(name, "$path.app");
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
  // final String id; //应用包名
  final String name; //应用名称
  final String path;

  Uint8List? icon;

  ProcessInfo(this.name, this.path);

  Future<String> getIconPath() async {
    return getMacIcon(path);
  }

  Future<Uint8List> getIcon() async {
    if (icon != null) return icon!;
    try {
      var macIcon = await getIconPath();
      icon = await File(macIcon).readAsBytes();
    } catch (e) {
      icon = Uint8List(0);
    }
    return icon!;
  }

  static Future<String> getMacIcon(String path) async {
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
    return {'name': name, 'path': path};
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
