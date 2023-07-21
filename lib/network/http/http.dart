import 'dart:convert';

import 'package:network_proxy/network/channel.dart';

import 'http_headers.dart';

///定义HTTP消息的接口，为HttpRequest和HttpResponse提供公共属性。
abstract class HttpMessage {
  ///内容类型
  static final Map<String, ContentType> contentTypes = {
    "javascript": ContentType.js,
    "text/css": ContentType.css,
    "font-woff": ContentType.font,
    "text/html": ContentType.html,
    "text/plain": ContentType.text,
    "application/x-www-form-urlencoded": ContentType.formUrl,
    "image": ContentType.image,
    "application/json": ContentType.json
  };

  final String protocolVersion;

  final HttpHeaders headers = HttpHeaders();
  int contentLength = -1;

  List<int>? body;
  String? remoteAddress;

  HttpMessage(this.protocolVersion);

  //json序列化
  factory HttpMessage.fromJson(Map<String, dynamic> json) {
    if (json["_class"] == "HttpRequest") {
      return HttpRequest.fromJson(json);
    }

    return HttpResponse.fromJson(json);
  }

  Map<String, dynamic> toJson();

  ContentType get contentType => contentTypes.entries
      .firstWhere((element) => headers.contentType.contains(element.key),
          orElse: () => const MapEntry("unknown", ContentType.http))
      .value;

  String get bodyAsString {
    if (body == null || body?.isEmpty == true) {
      return "";
    }
    try {
      return utf8.decode(body!);
    } catch (e) {
      return String.fromCharCodes(body!);
    }
  }

  String get cookie => headers.cookie;
}

///HTTP请求。
class HttpRequest extends HttpMessage {
  final String uri;
  late HttpMethod method;

  HostAndPort? hostAndPort;
  final DateTime requestTime = DateTime.now();
  HttpResponse? response;

  HttpRequest(this.method, this.uri, {String protocolVersion = "HTTP/1.1"}) : super(protocolVersion);

  String? remoteDomain() => hostAndPort?.domain;

  String get requestUrl => uri.startsWith("/") ? '${remoteDomain()}$uri' : uri;

  String? path() {
    try {
      return hostAndPort?.isSsl() == true ? uri : Uri.parse(requestUrl).path;
    } catch (e) {
      return null;
    }
  }

  ///复制请求
  HttpRequest copy({String? uri}) {
    var request = HttpRequest(method, uri ?? this.uri, protocolVersion: protocolVersion);
    request.headers.addAll(headers);
    request.contentLength = contentLength;
    request.body = body;
    return request;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_class': 'HttpRequest',
      'uri': requestUrl,
      'method': method.name,
      'headers': headers.toJson(),
      'body': bodyAsString,
    };
  }

  factory HttpRequest.fromJson(Map<String, dynamic> json) {
    var request = HttpRequest(HttpMethod.valueOf(json['method']), json['uri']);
    request.headers.addAll(HttpHeaders.fromJson(json['headers']));
    request.body = utf8.encode(json['body']);
    return request;
  }

  @override
  String toString() {
    return 'HttpReqeust{version: $protocolVersion, url: $uri, method: ${method.name}, headers: $headers, contentLength: $contentLength, bodyLength: ${body?.length}}';
  }
}

enum ContentType { json, formUrl, js, html, text, css, font, image, http }

///HTTP响应。
class HttpResponse extends HttpMessage {
  final HttpStatus status;
  final DateTime responseTime = DateTime.now();
  HttpRequest? request;

  HttpResponse(String protocolVersion, this.status) : super(protocolVersion);

  String costTime() {
    if (request == null) {
      return '';
    }
    return '${responseTime.difference(request!.requestTime).inMilliseconds}ms';
  }

  factory HttpResponse.fromJson(Map<String, dynamic> json) {
    return HttpResponse(json['protocolVersion'], HttpStatus(json['status']['code'], json['status']['reasonPhrase']))
      ..headers.addAll(HttpHeaders.fromJson(json['headers']))
      ..body = utf8.encode(json['body']);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      '_class': 'HttpResponse',
      'protocolVersion': protocolVersion,
      'status': {
        'code': status.code,
        'reasonPhrase': status.reasonPhrase,
      },
      'headers': headers.toJson(),
      'body': bodyAsString,
    };
  }

  @override
  String toString() {
    return 'HttpResponse{status: ${status.code}, headers: $headers, contentLength: $contentLength, bodyLength: ${body?.length}}';
  }
}

///HTTP请求方法。
enum HttpMethod {
  get("GET"),
  post("POST"),
  put("PUT"),
  patch("PATCH"),
  delete("DELETE"),
  options("OPTIONS"),
  head("HEAD"),
  trace("TRACE"),
  connect("CONNECT"),
  propfind("PROPFIND"),
  ;

  final String name;

  const HttpMethod(this.name);

  static HttpMethod valueOf(String name) {
    try {
      return HttpMethod.values.firstWhere((element) => element.name == name.toUpperCase());
    } catch (error) {
      print("$name :$error");
      rethrow;
    }
  }
}

///HTTP响应状态。
class HttpStatus {
  /// 200 OK
  static final HttpStatus ok = newStatus(200, "OK");

  /// 400 Bad Request
  static final HttpStatus badRequest = newStatus(400, "Bad Request");

  /// 401 Unauthorized
  static final HttpStatus unauthorized = newStatus(401, "Unauthorized");

  /// 403 Forbidden
  static final HttpStatus forbidden = newStatus(403, "Forbidden");

  /// 404 Not Found
  static final HttpStatus notFound = newStatus(404, "Not Found");

  /// 500 Internal Server Error
  static final HttpStatus internalServerError = newStatus(500, "Internal Server Error");

  /// 502 Bad Gateway
  static final HttpStatus badGateway = newStatus(502, "Bad Gateway");

  /// 503 Service Unavailable
  static final HttpStatus serviceUnavailable = newStatus(503, "Service Unavailable");

  /// 504 Gateway Timeout
  static final HttpStatus gatewayTimeout = newStatus(504, "Gateway Timeout");

  static HttpStatus newStatus(int statusCode, String reasonPhrase) {
    return HttpStatus(statusCode, reasonPhrase);
  }

  static HttpStatus? valueOf(int code) {
    switch (code) {
      case 200:
        return ok;
      case 400:
        return badRequest;
      case 401:
        return unauthorized;
      case 403:
        return forbidden;
      case 404:
        return notFound;
      case 500:
        return internalServerError;
      case 502:
        return badGateway;
      case 503:
        return serviceUnavailable;
      case 504:
        return gatewayTimeout;
    }
    return null;
  }

  final int code;
  final String reasonPhrase;

  HttpStatus(this.code, this.reasonPhrase);

  bool isSuccessful() {
    return code >= 200 && code < 300;
  }

  @override
  String toString() {
    return 'HttpResponseStatus{code: $code, reasonPhrase: $reasonPhrase}';
  }
}
