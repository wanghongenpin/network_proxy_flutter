import 'package:network_proxy/network/http/http.dart';

class Hae {
  List<Map> entries = [];

  void addEntry(HttpRequest request) {
    entries.add({
      "startedDateTime": request.requestTime, // 请求发出的时间(ISO 8601)
      "time": request.response?.responseTime.difference(request.requestTime).inMilliseconds, // 请求耗时(ms)
      "request": {
        "method": request.method.name, // 请求方法
        "url": request.requestUrl, // 请求地址
        "httpVersion": request.protocolVersion, // HTTP协议版本
        "cookies": [], // 请求携带的cookie
        "headers": _headers(request), // 请求头
        "queryString": [], // 请求参数
        "postData": {
          "mimeType": request.contentType, // 请求体类型
          "text": request.bodyAsString, // 请求体内容
        },
        "headersSize": -1, // 请求头大小
        "bodySize": request.body?.length ?? -1, // 请求体大小
      },
      'response': {
        "status": request.response?.status.code, // 响应状态码
        "statusText": request.response?.status.reasonPhrase, // 响应状态码描述
        "httpVersion": request.response?.protocolVersion, // HTTP协议版本
        "cookies": [], // 响应携带的cookie
        "headers": _headers(request.response), // 响应头
        "content": {
          "size": request.response?.body?.length, // 响应体大小
          "mimeType": request.response?.contentType, // 响应体类型
          "text": request.response?.bodyAsString, // 响应体内容
        },
        "redirectURL": '', // 重定向地址
        "headersSize": -1, // 响应头大小
        "bodySize": request.response?.body?.length ?? -1, // 响应体大小
      },
      "cache": {},
      'timings': {
        'send': 0,
        'wait': request.response?.responseTime.difference(request.requestTime).inMilliseconds,
        'receive': 0,
      },
      'serverIPAddress': request.response?.remoteAddress
    });
  }

  void toFile() {
    Map har = {};
    har["log"] = {
      "version": "1.2",
      "creator": {"name": "ProxyPin", "version": "1.0.1"},
      "entries": entries,
    };
  }

  List<Map> _headers(HttpMessage? message) {
    var headers = <Map<String, String>>[];
    message?.headers.forEach((name, values) {
      for (var element in values) {
        headers.add({'name': name, 'value': element});
      }
    });
    return headers;
  }
}
