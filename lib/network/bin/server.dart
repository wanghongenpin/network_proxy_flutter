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
  EventListener? listener;
  ServerSocket? serverSocket;

  ProxyServer({this.listener});

  Future<ServerSocket> start() {
    const port = 8888;
    Server server = Server(port)
      ..initChannel((channel) {
        channel.pipeline.handle(HttpRequestCodec(), HttpResponseCodec(), HttpChannelHandler(listener: listener));
      });

    return server.bind().then((serverSocket) {
      log.i("listen on $port");
      _setSystemProxy(port);
      this.serverSocket = serverSocket;

      return serverSocket;
    });
  }

  Future<ServerSocket?> stop() async {
    log.i("stop on ${serverSocket?.port}");
    if (Platform.isMacOS) {
      await _setProxyEnableMacOS(false);
    } else if (Platform.isWindows) {
      await _setProxyEnableWindows(false);
    }
    return serverSocket?.close();
  }

  void _setSystemProxy(int port) async {
    if (Platform.isMacOS) {
      _setProxyServerMacOS("127.0.0.1:$port");
    } else if (Platform.isWindows) {
      _setProxyServerWindows("127.0.0.1:$port");
      _setProxyEnableWindows(true);
    }
  }

  Future<bool> _setProxyServerMacOS(String proxyServer) async {
    try {
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
          // 'networksetup -setsecurewebproxy wi-fi $host $port',
          'networksetup -setproxybypassdomains wi-fi 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 127.0.0.1, localhost, *.local, timestamp.apple.com, sequoia.apple.com, seed-sequoia.siri.apple.com',
        ])
      ]);
      return results.exitCode == 0;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> _setProxyEnableMacOS(bool proxyEnable) async {
    try {
      var proxyMode = proxyEnable ? 'on' : 'off';
      var results = await Process.run('bash', [
        '-c',
        _concatCommands([
          'networksetup -setwebproxystate wi-fi $proxyMode',
          // 'networksetup -setsecurewebproxystate wi-fi $proxyMode',
        ])
      ]);
      return results.exitCode == 0;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> _setProxyEnableWindows(bool proxyEnable) async {
    try {
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
      print('set proxyEnable, exitCode: ${results.exitCode}, stdout: ${results.stdout}');
      return results.exitCode == 0;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> _setProxyServerWindows(String proxyServer) async {
    try {
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
    } catch (e) {
      print(e);
      return false;
    }
  }

  _concatCommands(List<String> commands) {
    return commands.join(' && ');
  }
}
