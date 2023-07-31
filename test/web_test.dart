import 'dart:io';
import 'dart:typed_data';

main() async {
  var connect = await Socket.connect("127.0.0.1", 7890);
  var httpRequest = HttpRequest("CONNECT", "https://www.google.com:443");
  connect.add(encode(httpRequest));

  // var httpClient = HttpClient();
  // httpClient .findProxy = (uri) =>  "PROXY 127.0.0.1:7890";
  // httpClient.getUrl(Uri.parse("https://www.youtube.com:443"));
  await connect.flush();
  // var first = await connect.first;
  // print(String.fromCharCodes(first));
  await Future.delayed(const Duration(seconds: 1));

  SecurityContext.defaultContext.allowLegacyUnsafeRenegotiation = true;
  await SecureSocket.secure(connect);
}

class HttpConstants {
  /// Line feed character /n
  static const int lf = 10;

  /// Carriage return /r
  static const int cr = 13;

  /// Horizontal space
  static const int sp = 32;

  /// Colon ':'
  static const int colon = 58;
}

///HTTP请求。
class HttpRequest {
  final String protocolVersion;

  final Map headers = {};
  int contentLength = -1;

  List<int>? body;
  final String uri;
  late String method;

  final DateTime requestTime = DateTime.now();
  HttpResponse? response;

  HttpRequest(this.method, this.uri, {this.protocolVersion = "HTTP/1.1"});

  @override
  String toString() {
    return 'HttpRequest{version: $protocolVersion, url: $uri, method: ${method}, headers: $headers, contentLength: $contentLength, bodyLength: ${body?.length}}';
  }
}

List<int> encode(HttpRequest message) {
  BytesBuilder builder = BytesBuilder();
  builder
    ..add(message.method.codeUnits)
    ..addByte(HttpConstants.sp)
    ..add(message.uri.codeUnits)
    ..addByte(HttpConstants.sp)
    ..add(message.protocolVersion.codeUnits)
    ..addByte(HttpConstants.cr)
    ..addByte(HttpConstants.lf);
  List<int>? body = message.body;

  //请求头
  if (body != null && body.isNotEmpty) {
    message.headers['Content-Length'] = body.length;
  }
  message.headers.forEach((key, values) {
    for (var v in values) {
      builder
        ..add(key.codeUnits)
        ..addByte(HttpConstants.colon)
        ..addByte(HttpConstants.sp)
        ..add(v.codeUnits)
        ..addByte(HttpConstants.cr)
        ..addByte(HttpConstants.lf);
    }
  });
  builder.addByte(HttpConstants.cr);
  builder.addByte(HttpConstants.lf);

  //请求体
  builder.add(body ?? Uint8List(0));
  return builder.toBytes();
}
