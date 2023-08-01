
import 'dart:io';

import 'package:network_proxy/network/http/codec.dart';
import 'package:network_proxy/network/http/http.dart';

main() async {
  var connect = await Socket.connect("127.0.0.1", 7890);
  var httpRequest = HttpRequest(HttpMethod.connect, "https://www.baidu.com");
  var codec = HttpRequestCodec();
  connect.add(codec.encode(httpRequest));


  await connect.flush();
  var first = await connect.first;
  print(String.fromCharCodes(first));
  await Future.delayed(const Duration(seconds: 1));
   httpRequest = HttpRequest(HttpMethod.get, "https://www.baidu.com");
   codec = HttpRequestCodec();
  connect.add(codec.encode(httpRequest));
   // var httpClient = HttpClient();
   // httpClient .findProxy = (uri) =>  "PROXY 127.0.0.1:7890";
   // httpClient.getUrl(Uri.parse("https://www.youtube.com:443"));
  SecurityContext.defaultContext.allowLegacyUnsafeRenegotiation = true;
  await SecureSocket.secure(connect);
}

