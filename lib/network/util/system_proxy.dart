import 'dart:io';

import 'package:network_proxy/utils/ip.dart';
import 'package:proxy_manager/proxy_manager.dart';

/// @author wanghongen
/// 2023/7/26
class SystemProxy {
  static String? _hardwarePort;

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

  /// 设置系统代理 @param sslSetting 是否设置https代理只在mac中有效
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

  static Future<bool> setProxyEnableMacOS(bool proxyEnable, bool sslSetting) async {
    var proxyMode = proxyEnable ? 'on' : 'off';
    _hardwarePort ??= await hardwarePort();
    print('set proxyEnable: $proxyEnable, name: $_hardwarePort');

    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxystate $_hardwarePort $proxyMode',
        sslSetting ? 'networksetup -setsecurewebproxystate $_hardwarePort $proxyMode' : '',
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
          : 'networksetup -setsecurewebproxystate $name off',
    ]);
    return results.exitCode == 0;
  }

  static Future<String> hardwarePort() async {
    var name = await networkName();
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -listnetworkserviceorder |grep "Device: $name" -A 1 |grep "Hardware Port" |awk -F ": " \'{print \$2}\'',
      ])
    ]);
    return results.stdout.toString().split(", ")[0];
  }

  static Future<bool> _setProxyServerWindows(int proxyPort) async {
    print("setSystemProxy $proxyPort");

    ProxyManager manager = ProxyManager();
    await manager.setAsSystemProxy(ProxyTypes.https, "127.0.0.1", proxyPort);
    print("setSystemProxy end");
    var results = await Process.run('reg', [
      'add',
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
      '/v',
      'ProxyOverride',
      '/t',
      'REG_SZ',
      '/d',
      '192.168.0.*;10.0.0.*;172.16.0.*;127.0.0.1;localhost;*.local;<local>',
      '/f',
    ]);

    print('set proxyServer $proxyPort, exitCode: ${results.exitCode}, stdout: ${results.stderr}');
    return results.exitCode == 0;
  }

  static Future<bool> setProxyEnableWindows(bool proxyEnable) async {
    var results = await Process.run('reg', [
      'add',
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
      '/v',
      'ProxyEnable',
      '/t',
      'REG_DWORD',
      '/f',
      '/d',
      proxyEnable ? '1' : '0',
    ]);
    return results.exitCode == 0;
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
