import 'dart:async';
import 'dart:io';

import '../channel.dart';
import '../handler.dart';
import '../http/codec.dart';
import '../util/logger.dart';

Future<void> main() async {
  ProxyServer().start();
}

class ProxyServer {
  int port = 8888;

  EventListener? listener;
  Server? server;

  ProxyServer({this.listener});

  ///是否启用ssl
  bool get enableSsl => server?.enableSsl == true;

  set enableSsl(bool enableSsl) {
    server?.enableSsl = enableSsl;
    if (server?.isRunning == false) {
      return;
    }

    if (Platform.isMacOS) {
      setSslProxyEnableMacOS(enableSsl);
    }
  }

  /// 启动代理服务
  Future<Server> start() {
    Server server = Server(port)
      ..initChannel((channel) {
        channel.pipeline.handle(HttpRequestCodec(), HttpResponseCodec(), HttpChannelHandler(listener: listener));
      });

    return server.bind().then((serverSocket) {
      log.i("listen on $port");
      _setSystemProxy(port);
      this.server = server;
      return server;
    });
  }

  /// 停止代理服务
  Future<Server?> stop() async {
    log.i("stop on ${server?.port}");
    if (Platform.isMacOS) {
      await setProxyEnableMacOS(false);
    } else if (Platform.isWindows) {
      await _setProxyEnableWindows(false);
    }
    await server?.stop();
    return server;
  }

  /// 设置系统代理
  void _setSystemProxy(int port) async {
    if (Platform.isMacOS) {
      _setProxyServerMacOS("127.0.0.1:$port");
    } else if (Platform.isWindows) {
      _setProxyServerWindows("127.0.0.1:$port");
      _setProxyEnableWindows(true);
    }
  }

  Future<bool> _setProxyServerMacOS(String proxyServer) async {
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
        enableSsl ? 'networksetup -setsecurewebproxy wi-fi $host $port' : '',
        'networksetup -setproxybypassdomains wi-fi 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 127.0.0.1, localhost, *.local, timestamp.apple.com, sequoia.apple.com, seed-sequoia.siri.apple.com',
      ])
    ]);
    print('set proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
    return results.exitCode == 0;
  }

  Future<bool> setProxyEnableMacOS(bool proxyEnable) async {
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

  Future<bool> setSslProxyEnableMacOS(bool proxyEnable) async {
    var results = await Process.run('bash', [
      '-c',
      _concatCommands([
        proxyEnable
            ? 'networksetup -setsecurewebproxy wi-fi 127.0.0.1 ${server?.port}'
            : 'networksetup -setsecurewebproxystate wi-fi off',
      ])
    ]);
    return results.exitCode == 0;
  }

  Future<bool> _setProxyEnableWindows(bool proxyEnable) async {
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

  Future<bool> _setProxyServerWindows(String proxyServer) async {
    var results = await Process.run('reg', [
      'add',
      'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
      '/v',
      'ProxyServer',
      '/f',
      '/d',
      proxyServer,
    ]);
    print('set proxyServer, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
    return results.exitCode == 0;
  }
}

_concatCommands(List<String> commands) {
  return commands.where((element) => element.isNotEmpty).join(' && ');
}
