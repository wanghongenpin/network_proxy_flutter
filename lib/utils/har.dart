import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';

class Har {
  static int maxBodyLength = 1024 * 1024 * 4;

  static List<Map> _entries(List<HttpRequest> list) {
    return list.map((e) => toHar(e)).toList();
  }

  static Map toHar(HttpRequest request) {
    bool isImage = request.response?.contentType == ContentType.image;
    Map har = {
      "startedDateTime": request.requestTime.toIso8601String(), // 请求发出的时间(ISO 8601)
      "time": request.response?.responseTime.difference(request.requestTime).inMilliseconds,
      "request": {
        "method": request.method.name, // 请求方法
        "url": request.requestUrl, // 请求地址
        "httpVersion": request.protocolVersion, // HTTP协议版本
        "cookies": [], // 请求携带的cookie
        "headers": _headers(request), // 请求头
        "queryString": [], // 请求参数
        "postData": {
          "mimeType": request.headers.contentType, // 请求体类型
          "text": request.bodyAsString, // 请求体内容
        },
        "headersSize": -1, // 请求头大小
        "bodySize": request.body?.length ?? -1, // 请求体大小
      },

      "cache": {},
      'timings': {
        'send': 0,
        'wait': request.response?.responseTime.difference(request.requestTime).inMilliseconds,
        'receive': 0,
      },
      'serverIPAddress': request.response?.remoteAddress
    };

    if (request.response != null) {
      har['response'] = {
        "status": request.response?.status.code, // 响应状态码
        "statusText": request.response?.status.reasonPhrase, // 响应状态码描述
        "httpVersion": request.response?.protocolVersion, // HTTP协议版本
        "cookies": [], // 响应携带的cookie
        "headers": _headers(request.response), // 响应头
        "content": {
          "size": isImage ? 0 : request.response?.body?.length, // 响应体大小
          "mimeType": request.response?.headers.contentType, // 响应体类型
          "text": isImage ? '' : request.response?.bodyAsString, // 响应体内容
        },
        "redirectURL": '', // 重定向地址
        "headersSize": -1, // 响应头大小
        "bodySize": request.response?.body?.length ?? -1, // 响应体大小
      };
    }
    return har;
  }

  static Future<File> writeFile(List<HttpRequest> list, File file) async {
    var entries = _entries(list);
    Map har = {};
    har["log"] = {
      "version": "1.2",
      "creator": {"name": "ProxyPin", "version": "1.0.2"},
      "entries": entries,
    };
    var json = jsonEncode(har);
    return file.writeAsString(json);
  }

  //读取文件
  static Future<List<HttpRequest>> readFile(File file) async {
    var lines = await file.readAsLines();
    List<HttpRequest> list = [];

    for (var value in lines) {
      var har = jsonDecode(value.substring(0, value.length - 1));
      var request = _toRequest(har);
      list.add(request);
    }
    return list;
  }

  static List<Map> _headers(HttpMessage? message) {
    var headers = <Map<String, String>>[];
    message?.headers.forEach((name, values) {
      for (var element in values) {
        headers.add({'name': name, 'value': element});
      }
    });
    return headers;
  }

  static HttpRequest _toRequest(Map har) {
    var request = har['request'];
    var method = request['method'];
    List headers = request['headers'];

    var httpRequest = HttpRequest(HttpMethod.valueOf(method), request['url'], protocolVersion: request['httpVersion']);
    httpRequest.body = request['postData']['text']?.toString().codeUnits;
    for (var element in headers) {
      httpRequest.headers.add(element['name'], element['value']);
    }
    var response = har['response'];
    HttpResponse? httpResponse;
    if (response != null && response['status'] != null) {
      httpResponse = HttpResponse(HttpStatus.newStatus(response['status'], response['statusText']),
          protocolVersion: response['httpVersion']);
      httpResponse.body = response['content']['text']?.toString().codeUnits;
      List responseHeaders = response['headers'];
      for (var element in responseHeaders) {
        httpResponse.headers.add(element['name'], element['value']);
      }
    }

    httpRequest.response = httpResponse;
    httpResponse?.request = httpRequest;
    httpRequest.hostAndPort = HostAndPort.of(httpRequest.requestUrl);
    return httpRequest;
  }
}
