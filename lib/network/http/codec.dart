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

import 'dart:math';
import 'dart:typed_data';

import 'package:network_proxy/network/http/body_reader.dart';
import 'package:network_proxy/network/http/http_parser.dart';

import '../../utils/compress.dart';
import 'http.dart';
import 'http_headers.dart';

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

class ParserException implements Exception {
  final String message;
  final String? source;

  ParserException(this.message, [this.source]);

  @override
  String toString() {
    return 'ParserException{message: $message source: $source}';
  }
}

enum State {
  readInitial,
  readHeader,
  body,
  done,
}

///类似于netty ByteBuf
class ByteBuf {
  final BytesBuilder _buffer = BytesBuilder();

  int _readerIndex = 0;

  Uint8List get buffer => _buffer.toBytes();

  int get length => _buffer.length;

  ///添加
  void add(List<int> bytes) {
    _buffer.add(bytes);
  }

  ///清空
  clear() {
    _buffer.clear();
    _readerIndex = 0;
  }

  ///读取索引
  int get readerIndex => _readerIndex;

  bool isReadable() => _readerIndex < _buffer.length;

  ///可读字节数
  int readableBytes() {
    return _buffer.length - _readerIndex;
  }

  ///读取字节
  Uint8List readBytes(int length) {
    Uint8List bytes = buffer.sublist(_readerIndex, _readerIndex + length);
    _readerIndex += length;
    return bytes;
  }

  ///跳过
  skipBytes(int length) {
    _readerIndex += length;
  }

  ///读取字节
  int read() {
    return buffer[_readerIndex++];
  }

  int get(int index) {
    return buffer[index];
  }
}

/// 解码
abstract interface class Decoder<T> {
  /// 解码 如果返回null说明数据不完整
  T? decode(ByteBuf byteBuf, {bool resolveBody = true});
}

/// 编码
abstract interface class Encoder<T> {
  List<int> encode(T data);
}

/// 编解码器
abstract class Codec<T> implements Decoder<T>, Encoder<T> {
  static const int defaultMaxInitialLineLength = 409600;
  static const int maxBodyLength = 4096000;
}

/// http编解码
abstract class HttpCodec<T extends HttpMessage> implements Codec<T> {
  final HttpParse _httpParse = HttpParse();
  State _state = State.readInitial;

  late T message;

  BodyReader? bodyReader;

  T createMessage(List<String> reqLine);

  @override
  T? decode(ByteBuf data, {bool resolveBody = true}) {
    //请求行
    if (_state == State.readInitial) {
      init();
      var initialLine = _readInitialLine(data);
      message = createMessage(initialLine);
      _state = State.readHeader;
    }

    //请求头
    try {
      if (_state == State.readHeader) {
        _readHeader(data, message);
      }

      //请求体
      if (_state == State.body) {
        var result = resolveBody ? bodyReader!.readBody(data.readBytes(data.readableBytes())) : null;
        if (!resolveBody || result?.isDone == true) {
          _state = State.done;
          message.body = result?.body;
        }
      }

      if (_state == State.done) {
        message.body = _convertBody(message.body);
        _state = State.readInitial;
        return message;
      }
    } catch (e) {
      _state = State.readInitial;
      rethrow;
    }

    return null;
  }

  void init() {
    bodyReader = null;
  }

  void initialLine(BytesBuilder buffer, T message);

  @override
  List<int> encode(T message) {
    BytesBuilder builder = BytesBuilder();
    //请求行
    initialLine(builder, message);

    List<int>? body = message.body;
    if (message.headers.isGzip) {
      body = gzipEncode(body!);
    }

    //请求头
    message.headers.remove(HttpHeaders.TRANSFER_ENCODING);
    if (body != null && body.isNotEmpty) {
      message.headers.contentLength = body.length;
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

  //读取起始行
  List<String> _readInitialLine(ByteBuf data) {
    int maxSize = min(data.readableBytes(), Codec.defaultMaxInitialLineLength);
    return _httpParse.parseInitialLine(data, maxSize);
  }

  //读取请求头
  void _readHeader(ByteBuf data, T message) {
    if (_httpParse.parseHeaders(data, message.headers)) {
      message.contentLength = message.headers.contentLength;
      _state = State.body;
      bodyReader = BodyReader(message);
    }
  }

  //转换body
  List<int>? _convertBody(List<int>? bytes) {
    if (bytes == null) {
      return null;
    }
    if (message.headers.isGzip) {
      bytes = gzipDecode(bytes);
    }
    return bytes;
  }
}

/// http请求编解码
class HttpRequestCodec extends HttpCodec<HttpRequest> {
  @override
  HttpRequest createMessage(List<String> reqLine) {
    HttpMethod httpMethod = HttpMethod.valueOf(reqLine[0]);
    return HttpRequest(httpMethod, reqLine[1], protocolVersion: reqLine[2]);
  }

  @override
  void initialLine(BytesBuilder buffer, HttpRequest message) {
    //请求行
    buffer
      ..add(message.method.name.codeUnits)
      ..addByte(HttpConstants.sp)
      ..add(message.uri.codeUnits)
      ..addByte(HttpConstants.sp)
      ..add(message.protocolVersion.codeUnits)
      ..addByte(HttpConstants.cr)
      ..addByte(HttpConstants.lf);
  }
}

/// http响应编解码
class HttpResponseCodec extends HttpCodec<HttpResponse> {
  @override
  HttpResponse createMessage(List<String> reqLine) {
    var httpStatus = HttpStatus(int.parse(reqLine[1]), reqLine[2]);
    return HttpResponse(httpStatus, protocolVersion: reqLine[0]);
  }

  @override
  void initialLine(BytesBuilder buffer, HttpResponse message) {
    //状态行
    buffer.add(message.protocolVersion.codeUnits);
    buffer.addByte(HttpConstants.sp);
    buffer.add(message.status.code.toString().codeUnits);
    buffer.addByte(HttpConstants.sp);
    buffer.add(message.status.reasonPhrase.codeUnits);
    buffer.addByte(HttpConstants.cr);
    buffer.addByte(HttpConstants.lf);
  }
}
