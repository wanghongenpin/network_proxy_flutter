import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter_js/extensions/xhr.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:network_proxy/network/components/js/md5.dart';

// Convert JS request
// Map<String, dynamic> convertJsRequest(HttpRequest request) {
//   return {
//     'url': request.requestUrl,
//     'path': request.path(),
//     'headers': request.headers.toMap(),
//     'method': request.method.name,
//     'body': request.bodyAsString
//   };
// }

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var flutterJs = getJavascriptRuntime();
  JsMd5Bridge.registerMd5(flutterJs);

  // var httpRequest = HttpRequest(HttpMethod.get, "https://www.v2ex.com");
  // httpRequest.headers.set('user-agent', 'Dart/3.0 (dart:io)');

  const code = """
    var context ='test';
    var d = md5('value');
    console.log(d);
    console.log(md5('你阿红asd'));
    console.log('Hello, World!');
  """;

  // var jsRequest = jsonEncode(convertJsRequest(httpRequest));

  var evaluate = await flutterJs.evaluateAsync(code);
  print(evaluate.stringResult);
  flutterJs.dartContext.clear();
  flutterJs.localContext.clear();
  flutterJs.evaluate('console.log("Hello, World!", d)');
  flutterJs.evaluate('console.log(context)');
}
