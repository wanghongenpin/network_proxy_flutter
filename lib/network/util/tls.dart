/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

import 'dart:typed_data';

class TLS {
  ///从TLS Client Hello 获取支持的协议
  static List<String>? supportProtocols(Uint8List data) {
    try {
      int sessionLength = data[43];
      int pos = 44 + sessionLength;
      if (data.length < pos + 2) return null;

      int cipherSuitesLength = data.buffer.asByteData().getUint16(pos);
      pos += 2 + cipherSuitesLength;
      if (data.length < pos + 1) return null;

      int compressionMethodsLength = data[pos];
      pos += 1 + compressionMethodsLength;
      if (data.length < pos + 2) return null;

      int extensionsLength = data.buffer.asByteData().getUint16(pos);
      pos += 2;
      if (data.length < pos + extensionsLength) return null;

      List<String> protocols = [];

      int end = pos + extensionsLength;
      while (pos + 4 <= end) {
        int extensionType = data.buffer.asByteData().getUint16(pos);
        int extensionLength = data.buffer.asByteData().getUint16(pos + 2);
        pos += 4;

        if (extensionType == 16 /* ALPN */) {
          if (pos + 2 > end) return protocols;
          int alpnExtensionLength = data.buffer.asByteData().getUint16(pos);
          pos += 2;
          if (pos + alpnExtensionLength > end) return protocols;

          int alpnEnd = pos + alpnExtensionLength;
          while (pos + 1 <= alpnEnd) {
            int protocolLength = data[pos];
            pos += 1;
            if (pos + protocolLength > alpnEnd) return protocols;

            String protocol = String.fromCharCodes(data.sublist(pos, pos + protocolLength));
            protocols.add(protocol);

            pos += protocolLength;
          }
        } else {
          pos += extensionLength;
        }
      }
      return protocols;
    } catch (_) {
      // Ignore errors, just return empty list
    }

    return null;
  }

  ///判断是否是TLS Client Hello
  static bool isTLSClientHello(Uint8List data) {
    if (data.length < 43) return false;
    if (data[0] != 0x16 /* handshake */) return false;
    if (data[1] != 0x03 || data[2] < 0x00 || data[2] > 0x03) return false;
    if (data[5] != 0x01 /* client_hello */) return false;
    if (data[9] != 0x03 || data[10] < 0x00 || data[10] > 0x03) return false;
    return true;
  }

  ///从TLS Client Hello 解析域名
  static String? getDomain(Uint8List data) {
    try {
      int sessionLength = data[43];
      int pos = 44 + sessionLength;
      if (data.length < pos + 2) return null;

      int cipherSuitesLength = data.buffer.asByteData().getUint16(pos);
      pos += 2 + cipherSuitesLength;
      if (data.length < pos + 1) return null;

      int compressionMethodsLength = data[pos];
      pos += 1 + compressionMethodsLength;
      if (data.length < pos + 2) return null;

      int extensionsLength = data.buffer.asByteData().getUint16(pos);
      pos += 2;
      if (data.length < pos + extensionsLength) return null;

      int end = pos + extensionsLength;
      while (pos + 4 <= end) {
        int extensionType = data.buffer.asByteData().getUint16(pos);
        int extensionLength = data.buffer.asByteData().getUint16(pos + 2);
        pos += 4;

        if (extensionType == 0 /* server_name */) {
          if (pos + 5 > end) return null;
          int serverNameListLength = data.buffer.asByteData().getUint16(pos);
          pos += 2;
          if (pos + serverNameListLength > end) return null;

          int serverNameType = data[pos];
          int serverNameLength = data.buffer.asByteData().getUint16(pos + 1);
          pos += 3;
          if (serverNameType != 0 /* host_name */) return null;
          if (pos + serverNameLength > end) return null;

          return String.fromCharCodes(data.sublist(pos, pos + serverNameLength));
        } else {
          pos += extensionLength;
        }
      }
    } catch (_) {
// Ignore errors, just return null
    }

    return null;
  }
}
