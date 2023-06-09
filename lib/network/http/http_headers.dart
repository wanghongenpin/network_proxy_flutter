import 'dart:collection';

class HttpHeaders {
  static const CONTENT_LENGTH = "Content-Length";
  static const CONTENT_ENCODING = "Content-Encoding";
  static const CONTENT_TYPE = "Content-Type";
  static const String HOST = "Host";
  static const String TRANSFER_ENCODING = "Transfer-Encoding";
  static const String Cookie = "Cookie";

  final LinkedHashMap<String, String> _headers = LinkedHashMap<String, String>();

  // 由小写标头名称键入的原始标头名称。
  final Map<String, String> _originalHeaderNames = {};

  ///设置header。
  void set(String name, String value) {
    _headers[name.toLowerCase()] = value;
    _originalHeaderNames[name] = value;
  }

  String? get(String name) {
    return _headers[name.toLowerCase()];
  }

  void remove(String name) {
    _headers.remove(name.toLowerCase());
    _originalHeaderNames.remove(name);
    _originalHeaderNames.remove(name.toLowerCase());
  }

  int? getInt(String name) {
    final value = get(name);
    if (value == null) {
      return null;
    }
    return int.parse(value);
  }

  bool getBool(String name) {
    final value = get(name);
    if (value == null) {
      return false;
    }
    return value.toLowerCase() == "true";
  }

  int get contentLength => getInt(CONTENT_LENGTH) ?? -1;

  set contentLength(int contentLength) => set(CONTENT_LENGTH, contentLength.toString());

  bool get isGzip => get(HttpHeaders.CONTENT_ENCODING) == "gzip";

  bool get isChunked => get(HttpHeaders.TRANSFER_ENCODING) == "chunked";
  String get cookie => get(Cookie) ?? "";

  void forEach(void Function(String name, String value) f) {
    _originalHeaderNames.forEach(f);
  }

  set contentType(String contentType) => set(CONTENT_TYPE, contentType);
  String get contentType => get(CONTENT_TYPE) ?? "";

  @override
  String toString() {
    return 'HttpHeaders{$_originalHeaderNames}';
  }
}
