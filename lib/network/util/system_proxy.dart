import 'dart:io';

class SystemProxy {
  /// 设置系统代理
  static void setSystemProxy(int port, bool enableSsl) async {
    if (Platform.isMacOS) {
      _setProxyServerMacOS("127.0.0.1:$port", enableSsl);
    } else if (Platform.isWindows) {
      _setProxyServerWindows("127.0.0.1:$port");
      setProxyEnableWindows(true);
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
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxy wi-fi $host $port',
        enableSsl == true ? 'networksetup -setsecurewebproxy wi-fi $host $port' : '',
        'networksetup -setproxybypassdomains wi-fi 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 127.0.0.1, localhost, *.local, timestamp.apple.com, sequoia.apple.com, seed-sequoia.siri.apple.com, *.google.com, *.googleapis.com',
      ])
    ]);
    print('set proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
    return results.exitCode == 0;
  }

  static Future<bool> setProxyEnableMacOS(bool proxyEnable, bool enableSsl) async {
    var proxyMode = proxyEnable ? 'on' : 'off';
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        'networksetup -setwebproxystate wi-fi $proxyMode',
        enableSsl ? 'networksetup -setsecurewebproxystate wi-fi $proxyMode' : '',
      ])
    ]);
    return results.exitCode == 0;
  }

  static Future<bool> setSslProxyEnableMacOS(bool proxyEnable, port) async {
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        proxyEnable
            ? 'networksetup -setsecurewebproxy wi-fi 127.0.0.1 $port'
            : 'networksetup -setsecurewebproxystate wi-fi off',
      ])
    ]);
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
    print('set proxyServer $proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stderr}');
    return results.exitCode == 0;
  }

  static _concatCommands(List<String> commands) {
    return commands.where((element) => element.isNotEmpty).join(' && ');
  }
}
