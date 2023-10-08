import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:network_proxy/network/http/http.dart';

//转换js request
Map<String, dynamic> convertJsRequest(HttpRequest request) {
  return {
    'url': request.requestUrl,
    'path': request.path(),
    'headers': request.headers.toMap(),
    'method': request.method.name,
    'body': request.bodyAsString
  };
}

main() {
  var flutterJs = getJavascriptRuntime();
  var httpRequest = HttpRequest(HttpMethod.get, "https://www.v2ex.com");
  httpRequest.headers.set('user-agent', 'Dart/3.0 (dart:io)');

  const code = """
  function httpRequest(request) {
    console.log(request);
    request.headers['heelo']='world';
    request.url = 'https://www.baidu.com';
    return null;
  }
  """;
  var jsRequest = jsonEncode(convertJsRequest(httpRequest));

  var evaluate = flutterJs.evaluate("""$code\n httpRequest($jsRequest);""");
  print(flutterJs.convertValue(evaluate));
}
