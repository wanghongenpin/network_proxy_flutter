import 'dart:math';
import 'dart:typed_data';

import '../../utils/num.dart';
import 'codec.dart';

///一个ChunkedInput，它逐块获取数据，用于HTTP分块传输。
/// 请确保您的HTTP响应标头包含传输编码：chunked。
class ChunkedInput {
  final BytesBuilder _buffer = BytesBuilder();

  ///chunked编码 剩余未读取的chunk大小
  int _chunkReadableSize = 0;

  int _offset = 0;
  ChunkedState _state = ChunkedState.readChunkSize;

  ///读取chunk
  ChunkedContent readChunked(Uint8List data) {
    _offset = 0;

    while (_offset < data.length) {
      //读取chunk length
      if (_state == ChunkedState.readChunkSize) {
        _chunkReadableSize = _readChunkSize(data);

        if (_chunkReadableSize == 0) {
          //chunked编码结束
          _state = ChunkedState.done;
          break;
        }

        if (_chunkReadableSize == -1) {
          continue;
        }
        _state = ChunkedState.readChunkedContent;
      }

      //读取chunk内容
      if (_state == ChunkedState.readChunkedContent) {
        int end = min(data.length, _offset + _chunkReadableSize);
        _buffer.add(data.sublist(_offset, end));

        //可读大小
        _chunkReadableSize -= (end - _offset);
        _offset = end;
        if (_chunkReadableSize == 0) {
          _state = ChunkedState.readChunkSize;
          _offset += 2; //内容结尾\r\n
        }
      }
    }

    return ChunkedContent(_state, _buffer.toBytes());
  }

  int _readChunkSize(Uint8List data) {
    var line = parseLine(data);
    if (line.isEmpty) {
      return -1;
    }

    return hexToInt(String.fromCharCodes(line));
  }

  Uint8List parseLine(Uint8List data) {
    if (_offset >= data.length) {
      return Uint8List(0);
    }

    for (int i = _offset; i < data.length; i++) {
      if (_isLineEnd(data, i)) {
        var line = data.sublist(_offset, i - 1);
        _offset = i + 1;
        return line;
      }
    }

    throw Exception('Invalid chunked encoding line: ${String.fromCharCodes(data)}');
  }

  bool _isLineEnd(List<int> data, int index) {
    return data[index] == HttpConstants.lf && data[index - 1] == HttpConstants.cr;
  }
}

enum ChunkedState { readChunkSize, readChunkedContent, done }

class ChunkedContent {
  final ChunkedState state;
  final Uint8List content;

  ChunkedContent(this.state, this.content);
}
