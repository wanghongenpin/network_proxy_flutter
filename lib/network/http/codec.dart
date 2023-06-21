import 'dart:math';
import 'dart:typed_data';

import 'package:network_proxy/network/http/body_reader.dart';

import '../../utils/compress.dart';
import '../channel.dart';
import '../util/logger.dart';
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

enum State {
  readInitial,
  readHeader,
  body,
  done,
}

/// http编解码
abstract class HttpCodec<T extends HttpMessage> implements Codec<T> {
  final HttpParse _httpParse = HttpParse();
  State _state = State.readInitial;

  late T message;

  BodyReader? bodyReader;

  T createMessage(List<String> reqLine);

  @override
  T? decode(Uint8List data) {
    _httpParse.index = 0;

    //请求行
    if (_state == State.readInitial) {
      init();
      try {
        var initialLine = _readInitialLine(data);
        message = createMessage(initialLine);
        _state = State.readHeader;
      } catch (e, cause) {
        logger.e("解析请求行失败 [${String.fromCharCodes(data)}]", e, cause);
        rethrow;
      }
    }

    //请求头
    if (_state == State.readHeader) {
      _readHeader(data, message);
      _state = State.body;
      bodyReader = BodyReader(message);
    }

    //请求体
    if (_state == State.body) {
      var result = bodyReader!.readBody(data.sublist(_httpParse.index));
      if (result.isDone) {
        _state = State.done;
        message.body = result.body;
      }
    }

    if (_state == State.done) {
      message.body = _convertBody(message.body);
      _state = State.readInitial;
      return message;
    }

    return null;
  }

  void init() {
    _httpParse.reset();
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
    message.headers.forEach((key, value) {
      builder
        ..add(key.codeUnits)
        ..addByte(HttpConstants.colon)
        ..addByte(HttpConstants.sp)
        ..add(value.codeUnits)
        ..addByte(HttpConstants.cr)
        ..addByte(HttpConstants.lf);
    });
    builder.addByte(HttpConstants.cr);
    builder.addByte(HttpConstants.lf);

    //请求体
    builder.add(body ?? Uint8List(0));
    return builder.toBytes();
  }

  //读取起始行
  List<String> _readInitialLine(Uint8List data) {
    int maxSize = min(data.length, Codec.defaultMaxInitialLineLength);
    return _httpParse.parseInitialLine(data, maxSize);
  }

  //读取请求头
  void _readHeader(Uint8List data, T message) {
    _httpParse.parseHeader(data, message.headers);
    message.contentLength = message.headers.contentLength;
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
    return HttpRequest(httpMethod, reqLine[1], reqLine[2]);
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
    return HttpResponse(reqLine[0], httpStatus);
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

/// http解析器
class HttpParse {
  int index = 0;

  /// 解析请求行
  List<String> parseInitialLine(Uint8List data, int size) {
    List<String> initialLine = [];
    for (int i = index; i < size; i++) {
      if (_isLineEnd(data, i)) {
        //请求行结束
        Uint8List requestLine = data.sublist(index, i - 1);
        initialLine = _splitLine(requestLine);
        index = i + 1;
        break;
      }
    }
    if (initialLine.length != 3) {
      throw Exception("parseLine error ${String.fromCharCodes(data)}");
    }

    return initialLine;
  }

  /// 解析请求头
  void parseHeader(Uint8List data, HttpHeaders headers) {
    while (true) {
      var line = parseLine(data);
      if (line.isEmpty) {
        break;
      }
      var header = _splitHeader(line);
      headers.set(header[0], header[1]);
    }
  }

  Uint8List parseLine(Uint8List data) {
    for (int i = index; i < data.length; i++) {
      if (_isLineEnd(data, i)) {
        var line = data.sublist(index, i - 1);
        index = i + 1;
        return line;
      }
    }
    return Uint8List(0);
  }

  void reset() {
    index = 0;
  }

  //是否行结束
  bool _isLineEnd(List<int> data, int index) {
    return index >= 1 && data[index] == HttpConstants.lf && data[index - 1] == HttpConstants.cr;
  }

  //分割行
  List<String> _splitLine(Uint8List data) {
    List<String> lines = [];
    int start = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i] == HttpConstants.sp) {
        lines.add(String.fromCharCodes(data.sublist(start, i)));
        start = i + 1;
        if (lines.length == 2) {
          break;
        }
      }
    }
    lines.add(String.fromCharCodes(data.sublist(start)));
    return lines;
  }

  //分割头
  List<String> _splitHeader(List<int> data) {
    List<String> headers = [];
    for (int i = 0; i < data.length; i++) {
      if (data[i] == HttpConstants.colon && data[i + 1] == HttpConstants.sp) {
        headers.add(String.fromCharCodes(data.sublist(0, i)));
        headers.add(String.fromCharCodes(data.sublist(i + 2)));
        break;
      }
    }
    return headers;
  }
}
