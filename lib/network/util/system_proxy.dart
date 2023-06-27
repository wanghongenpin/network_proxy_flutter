import 'dart:io';

import 'package:network_proxy/utils/ip.dart';

class SystemProxy {
  /// 设置系统代理
  static void setSystemProxy(int port, bool enableSsl) async {
    if (Platform.isMacOS) {
      _setProxyServerMacOS("127.0.0.1:$port", enableSsl);
    } else if (Platform.isWindows) {
      _setProxyServerWindows("127.0.0.1:$port").then((value) => setProxyEnableWindows(true));
    }
  }

  static Future<bool> _setProxyServerMacOS(String proxyServer, bool enableSsl) async {
    var match = RegExp(r"^(?:http://)?(?<host>.+):(?<port>\d+)$").firstMatch(proxyServer);
    if (match == null) {
      print('proxyServer parse error!');
      return false;
    }
    var host = match.namedGroup('host');
    var port = match.namedGroup('port');
    var name = await hardwarePort();
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxy $name $host $port',
        enableSsl == true ? 'networksetup -setsecurewebproxy $name $host $port' : '',
        'networksetup -setproxybypassdomains $name 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 127.0.0.1 localhost *.local timestamp.apple.com sequoia.apple.com seed-sequoia.siri.apple.com *.google.com',
      ])
    ]);
    print('set proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
    return results.exitCode == 0;
  }

  static Future<bool> setProxyEnableMacOS(bool proxyEnable, bool enableSsl) async {
    var proxyMode = proxyEnable ? 'on' : 'off';
    var name = await hardwarePort();
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxystate $name $proxyMode',
        enableSsl ? 'networksetup -setsecurewebproxystate $name $proxyMode' : '',
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

  static Future<bool> _setProxyServerWindows(String proxyServer) async {
    var results = await Process.run('reg', [
      'add',
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
      '/v',
      'ProxyServer',
      '/f',
      '/d',
      proxyServer,
    ]);

    Process.run('reg', [
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

    print('set proxyServer $proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stderr}');
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
  var r = await SystemProxy.hardwarePort();
  print(r);
}
