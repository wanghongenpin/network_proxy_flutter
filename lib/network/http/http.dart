import 'http_headers.dart';

///定义HTTP消息的接口，为HttpRequest和HttpResponse提供公共属性。
abstract class HttpMessage {
  final String protocolVersion;

  final HttpHeaders headers = HttpHeaders();
  int contentLength = -1;

  List<int>? body;

  HttpMessage(this.protocolVersion);

  String get bodyAsString {
    if (body == null) {
      return "";
    }
    return String.fromCharCodes(body!);
  }
}

///HTTP请求。
class HttpRequest extends HttpMessage {
  final String uri;
  late HttpMethod method;

  HttpRequest(this.method, this.uri, String protocolVersion) : super(protocolVersion);

  @override
  String toString() {
    return 'HttpReqeust{version: $protocolVersion, url: $uri, method: ${method.name}, headers: $headers, contentLength: $contentLength, bodyLength: ${body?.length}}';
  }
}

///HTTP响应。
class HttpResponse extends HttpMessage {
  final HttpStatus status;

  HttpResponse(String protocolVersion, this.status) : super(protocolVersion);

  @override
  String toString() {
    return 'HttpResponse{status: ${status.code}, headers: $headers, contentLength: $contentLength, bodyLength: ${body?.length}}';
  }
}

///HTTP请求方法。
enum HttpMethod {
  options("OPTIONS"),
  get("GET"),
  head("HEAD"),
  post("POST"),
  put("PUT"),
  patch("PATCH"),
  delete("DELETE"),
  trace("TRACE"),
  connect("CONNECT");

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

  @override
  String toString() {
    return 'HttpResponseStatus{code: $code, reasonPhrase: $reasonPhrase}';
  }
}
