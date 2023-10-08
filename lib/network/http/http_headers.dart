/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:collection';

class HttpHeaders {
  static const CONTENT_LENGTH = "Content-Length";
  static const CONTENT_ENCODING = "Content-Encoding";
  static const CONTENT_TYPE = "Content-Type";
  static const String HOST = "Host";
  static const String TRANSFER_ENCODING = "Transfer-Encoding";
  static const String Cookie = "Cookie";

  final LinkedHashMap<String, List<String>> _headers = LinkedHashMap<String, List<String>>();

  // 由小写标头名称键入的原始标头名称。
  final Map<String, List<String>> _originalHeaderNames = {};

  HttpHeaders();

  ///设置header。
  void set(String name, String value) {
    _headers[name.toLowerCase()] = [value];
    _originalHeaderNames[name] = [value];
  }

  ///添加header。
  void add(String name, String value) {
    if (!_headers.containsKey(name.toLowerCase())) {
      _headers[name.toLowerCase()] = [];
      _originalHeaderNames[name] = [];
    }

    _headers[name.toLowerCase()]?.add(value);
    _originalHeaderNames[name]?.add(value);
  }

  ///添加header。
  void addValues(String name, List<String> values) {
    if (!_headers.containsKey(name.toLowerCase())) {
      _headers[name.toLowerCase()] = [];
      _originalHeaderNames[name] = [];
    }

    _headers[name.toLowerCase()]?.addAll(values);
    _originalHeaderNames[name]?.addAll(values);
  }

  ///从headers中添加
  addAll(HttpHeaders? headers) {
    headers?.forEach((key, values) {
      for (var val in values) {
        add(key, val);
      }
    });
  }

  String? get(String name) {
    return _headers[name.toLowerCase()]?.first;
  }

  List<String>? getList(String name) {
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

  String? get contentEncoding => get(HttpHeaders.CONTENT_ENCODING);

  bool get isGzip => contentEncoding == "gzip";

  bool get isChunked => get(HttpHeaders.TRANSFER_ENCODING) == "chunked";

  String get cookie => get(Cookie) ?? "";

  void forEach(void Function(String name, List<String> values) f) {
    _originalHeaderNames.forEach(f);
  }

  Iterable<MapEntry<String, List<String>>> get entries => _originalHeaderNames.entries;

  set contentType(String contentType) => set(CONTENT_TYPE, contentType);

  String get contentType => get(CONTENT_TYPE) ?? "";

  String? get host => get(HOST);

  set host(String? host) {
    if (host != null) {
      set(HOST, host);
    }
  }

  //清空
  void clean() {
    _headers.clear();
    _originalHeaderNames.clear();
  }

  String headerLines() {
    StringBuffer sb = StringBuffer();
    forEach((name, values) {
      for (var value in values) {
        sb.writeln("$name: $value");
      }
    });

    return sb.toString();
  }

  ///转换json
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    forEach((name, values) {
      json[name] = values;
    });
    return json;
  }

  ///转换json
  Map<String, String> toMap() {
    Map<String, String> json = {};
    forEach((name, values) {
      json[name] = values.join(";");
    });
    return json;
  }

  ///从json解析
  factory HttpHeaders.fromJson(Map<String, dynamic> json) {
    HttpHeaders headers = HttpHeaders();
    json.forEach((key, values) {
      for (var element in (values as List)) {
        headers.add(key, element.toString());
      }
    });

    return headers;
  }

  @override
  String toString() {
    return 'HttpHeaders{$_originalHeaderNames}';
  }
}
