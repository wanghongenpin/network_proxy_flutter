import 'dart:typed_data';

///类似于netty ByteBuf
class ByteBuf {
  final BytesBuilder _buffer = BytesBuilder();
  int readerIndex = 0;

  Uint8List get bytes => _buffer.toBytes();

  int get length => _buffer.length;

  ByteBuf([List<int>? bytes]) {
    if (bytes != null) _buffer.add(bytes);
  }

  ///添加
  void add(List<int> bytes) {
    _buffer.add(bytes);
  }

  ///清空
  clear() {
    _buffer.clear();
    readerIndex = 0;
  }

  ///释放
  clearRead() {
    var takeBytes = _buffer.takeBytes();
    _buffer.add(Uint8List.sublistView(takeBytes, readerIndex, takeBytes.length));
    readerIndex = 0;
  }

  bool isReadable() => readerIndex < _buffer.length;

  ///可读字节数
  int readableBytes() {
    return _buffer.length - readerIndex;
  }

  ///读取所有可用字节
  Uint8List readAvailableBytes() {
    return readBytes(readableBytes());
  }

  ///读取字节
  Uint8List readBytes(int length) {
    Uint8List list = bytes.sublist(readerIndex, readerIndex + length);
    readerIndex += length;
    return list;
  }

  ///跳过
  skipBytes(int length) {
    readerIndex += length;
  }

  ///读取字节
  int read() {
    return bytes[readerIndex++];
  }

  ///读取字节
  int readByte() {
    return bytes[readerIndex++];
  }

  int readShort() {
    int value = bytes[readerIndex++] << 8 | bytes[readerIndex++];
    return value;
  }

  int readInt() {
    int value =
        bytes[readerIndex++] << 24 | bytes[readerIndex++] << 16 | bytes[readerIndex++] << 8 | bytes[readerIndex++];
    return value;
  }

  int get(int index) {
    return bytes[index];
  }
}
