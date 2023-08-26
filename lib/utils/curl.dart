import 'package:network_proxy/network/http/http.dart';

///复制cURL请求
String curlRequest(HttpRequest request) {
  List<String> headers = [];
  request.headers.forEach((key, values) {
    for (var val in values) {
      headers.add("  -H '$key: $val' ");
    }
  });

  String body = '';
  if (request.bodyAsString.isNotEmpty) {
    body = "  --data '${request.bodyAsString}' \\\n";
  }
  return "curl -X ${request.method.name} '${request.requestUrl}' \\\n"
      "${headers.join('\\\n')} $body \\\n --compressed";
}
