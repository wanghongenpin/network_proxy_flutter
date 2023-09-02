import 'dart:io';

import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:network_proxy/utils/lang.dart';
import 'package:proxy_manager/proxy_manager.dart';

/// @author wanghongen
/// 2023/7/26
class SystemProxy {
  static String? _hardwarePort;

  ///获取系统代理
  static Future<ProxyInfo?> getSystemProxy(ProxyTypes types) async {
    if (Platform.isWindows) {
      return await _getSystemProxyWindows();
    } else if (Platform.isMacOS) {
      return await _getSystemProxyMacOS(types);
    } else if (Platform.isLinux) {
      return await _getLinuxProxyServer(types);
    } else {
      return null;
    }
  }

  /// 设置系统代理
  static Future<void> setSystemProxy(int port, bool sslSetting) async {
    if (Platform.isMacOS) {
      await _setProxyServerMacOS(port, sslSetting);
    } else if (Platform.isWindows) {
      await _setProxyServerWindows(port);
    } else {
      ProxyManager manager = ProxyManager();
      manager.setAsSystemProxy(ProxyTypes.http, "127.0.0.1", port);
      if (sslSetting) {
        await manager.setAsSystemProxy(ProxyTypes.https, "127.0.0.1", port);
      }
    }
  }

  /// 设置系统代理
  /// @param sslSetting 是否设置https代理只在mac中有效
  static Future<void> setSystemProxyEnable(int port, bool enable, bool sslSetting) async {
    //启用系统代理
    if (enable) {
      await setSystemProxy(port, sslSetting);
      return;
    }

    if (Platform.isMacOS) {
      await setProxyEnableMacOS(enable, sslSetting);
    } else if (Platform.isWindows) {
      await setProxyEnableWindows(enable);
    } else {
      ProxyManager manager = ProxyManager();
      await manager.cleanSystemProxy();
    }
  }

  static Future<bool> _setProxyServerMacOS(int port, bool sslSetting) async {
    _hardwarePort = await hardwarePort();
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxy $_hardwarePort 127.0.0.1 $port',
        sslSetting == true ? 'networksetup -setsecurewebproxy $_hardwarePort 127.0.0.1 $port' : '',
        'networksetup -setproxybypassdomains $_hardwarePort 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 127.0.0.1 localhost *.local timestamp.apple.com',
      ])
    ]);
    print('set proxyServer, name: $_hardwarePort, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
    return results.exitCode == 0;
  }

  static Future<bool> getProxyEnable() async {
    _hardwarePort ??= await hardwarePort();
    try {
      var results = await Process.run('bash', ['-c', 'networksetup -getwebproxy $_hardwarePort']);
      var proxyEnableLine =
          (results.stdout as String).split('\n').where((item) => item.contains('Enabled')).first.trim();
      return proxyEnableLine.endsWith('Yes');
    } catch (e) {
      print(e);
      return false;
    }
  }

  ///获取系统代理
  static Future<ProxyInfo?> _getSystemProxyMacOS(ProxyTypes proxyTypes) async {
    _hardwarePort = await hardwarePort();
    var result = await Process.run('bash', [
      '-c',
      'networksetup ${proxyTypes == ProxyTypes.http ? '-getwebproxy' : '-getsecurewebproxy'} $_hardwarePort'
    ]).then((results) => results.stdout.toString().split('\n'));

    var proxyEnable = result.firstWhere((item) => item.contains('Enabled')).trim().split(": ")[1];
    if (proxyEnable == 'No') {
      return null;
    }

    var proxyServer = result.firstWhere((item) => item.contains('Server')).trim().split(": ")[1];
    var proxyPort = result.firstWhere((item) => item.contains('Port')).trim().split(": ")[1];
    if (proxyEnable == 'Yes' && proxyServer.isNotEmpty) {
      return ProxyInfo.of(proxyServer, int.parse(proxyPort));
    }
    return null;
  }

  static Future<bool> setProxyEnableMacOS(bool proxyEnable, bool sslSetting) async {
    var proxyMode = proxyEnable ? 'on' : 'off';
    _hardwarePort ??= await hardwarePort();
    print('set proxyEnable: $proxyEnable, name: $_hardwarePort');

    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxystate $_hardwarePort $proxyMode',
        sslSetting ? 'networksetup -setsecurewebproxystate $_hardwarePort $proxyMode' : ''
      ])
    ]);
    return results.exitCode == 0;
  }

  static Future<bool> setSslProxyEnableMacOS(bool proxyEnable, port) async {
    var name = await hardwarePort();

    var results = await Process.run('bash', [
      '-c',
      proxyEnable
          ? 'networksetup -setsecurewebproxy $name 127.0.0.1 $port'
          : 'networksetup -setsecurewebproxystate $name off'
    ]);
    return results.exitCode == 0;
  }

  static Future<String> hardwarePort() async {
    var name = await networkName();
    var results = await Process.run('bash', [
      '-c',
      'networksetup -listnetworkserviceorder |grep "Device: $name" -A 1 |grep "Hardware Port" |awk -F ": " \'{print \$2}\''
    ]);
    return results.stdout.toString().split(", ")[0];
  }

  static Future<void> _setProxyServerWindows(int proxyPort) async {
    ProxyManager manager = ProxyManager();
    await manager.setAsSystemProxy(ProxyTypes.https, "127.0.0.1", proxyPort);
    var results = await _internetSettings('add', [
      'ProxyOverride',
      '/t',
      'REG_SZ',
      '/d',
      '192.168.0.*;10.0.0.*;172.16.0.*;127.0.0.1;localhost;*.local;<local>',
      '/f'
    ]);

    print('set proxyServer $proxyPort, result: $results');
  }

  static Future<void> setProxyEnableWindows(bool proxyEnable) async {
    await _internetSettings('add', ['ProxyEnable', '/t', 'REG_DWORD', '/f', '/d', proxyEnable ? '1' : '0']);
  }

  /// 获取系统代理
  static Future<ProxyInfo?> _getSystemProxyWindows() async {
    var results = await _internetSettings('query', ['ProxyEnable']);

    var proxyEnableLine = results.split('\r\n').where((item) => item.contains('ProxyEnable')).first.trim();
    if (proxyEnableLine.substring(proxyEnableLine.length - 1) != '1') {
      return null;
    }

    return _internetSettings('query', ['ProxyServer']).then((results) {
      var proxyServerLine = results.split('\r\n').where((item) => item.contains('ProxyServer')).firstOrNull;
      var proxyServerLineSplits = proxyServerLine?.split(RegExp(r"\s+"));

      if (proxyServerLineSplits == null || proxyServerLineSplits.length < 2) {
        return null;
      }

      var proxyLine = proxyServerLineSplits[proxyServerLineSplits.length - 1];
      if (proxyLine.startsWith("http://") || proxyLine.startsWith("https:///")) {
        proxyLine = proxyLine.replaceFirst("http://", "").replaceFirst("https:///", "");
      }

      var proxyServer = proxyLine.split(":")[0];
      var proxyPort = proxyLine.split(":")[1];
      print("$proxyServer:$proxyPort");
      return ProxyInfo.of(proxyServer, int.parse(proxyPort));
    }).catchError((e) {
      print(e);
      return null;
    });
  }

  static Future<String> _internetSettings(String cmd, List<String> args) async {
    return Process.run('reg', [
      cmd,
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
      '/v',
      ...args,
    ]).then((results) => results.stdout.toString());
  }

  static Future<ProxyInfo?> _getLinuxProxyServer(ProxyTypes types) async {
    ///linux 获取代理
    var mode = await Process.run("gsettings", ["get", "org.gnome.system.proxy", "mode"])
        .then((value) => value.stdout.toString().trim());
    if (mode.contains("manual")) {
      var hostFuture = Process.run("gsettings", ["get", "org.gnome.system.proxy.${types.name}", "host"])
          .then((value) => value.stdout.toString().trim());
      var portFuture = Process.run("gsettings", ["get", "org.gnome.system.proxy.${types.name}", "port"])
          .then((value) => value.stdout.toString().trim());

      return Future.wait([hostFuture, portFuture]).then((value) {
        var host = Strings.trimWrap(value[0], "'");
        var port = Strings.trimWrap(value[1], "'");
        print("$host:$port");
        if (host.isNotEmpty && port.isNotEmpty) {
          return ProxyInfo.of(host, int.parse(port));
        }
        return null;
      });
    }
    return null;
  }

  static _concatCommands(List<String> commands) {
    return commands.where((element) => element.isNotEmpty).join(' && ');
  }
}

void main() async {
  // single instance
  ProxyManager manager = ProxyManager();
// set a http proxy
  await manager.setAsSystemProxy(ProxyTypes.http, "127.0.0.1", 1087);
}
