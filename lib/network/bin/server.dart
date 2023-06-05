import 'dart:async';

import '../channel.dart';
import '../handler.dart';
import '../http/codec.dart';

Future<void> main() async {
  const port = 8888;
  Server server = Server(port)
    ..initChannel((channel) {
      channel.pipeline.handle(HttpRequestCodec(), HttpResponseCodec(), HttpChannelHandler());
    });
  await server.bind();
}
