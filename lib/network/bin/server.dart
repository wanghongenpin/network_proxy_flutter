import 'dart:async';
import 'dart:io';

import '../channel.dart';
import '../handler.dart';
import '../http/codec.dart';
import '../util/logger.dart';

Future<void> main() async {
  start();
}

Future<void> start({EventListener? listener}) async {
  const port = 8888;
  Server server = Server(port)
    ..initChannel((channel) {
      channel.pipeline.handle(HttpRequestCodec(), HttpResponseCodec(), HttpChannelHandler(listener: listener));
    });
  log.i("listen on $port");
  await server.bind().then((value) => {setSystemProxy(port)});
}

void setSystemProxy(int port) {
  if (Platform.isMacOS) {

    // Process.run('networksetup', ['-getsecurewebproxy', 'Wi-Fi']).then((ProcessResult results) {
    //   print(results.stdout);
    // });
    // Process.run('networksetup', ['-setsecurewebproxy', 'Wi-Fi', '127.0.0.1', port.toString()])
    //     .then((ProcessResult results) {
    //   print(results.stdout);
    // });
    // Process.run('networksetup', ['-setwebproxy', 'Wi-Fi', '127.0.0.1', port.toString()]).then((ProcessResult results) {
    //   print(results.stdout);
    // });
  }
}
