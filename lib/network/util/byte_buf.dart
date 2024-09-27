/*
 * Copyright 2023 Hongen Wang All rights reserved.
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

  void truncate(int len) {
    if (len > readableBytes()) throw Exception("insufficient data");
    var takeBytes = _buffer.takeBytes();
    _buffer.add(takeBytes.sublist(0, readerIndex + len));
  }

  ByteBuf dup() {
    ByteBuf buf = ByteBuf();
    buf.add(bytes);
    buf.readerIndex = readerIndex;
    return buf;
  }
}
