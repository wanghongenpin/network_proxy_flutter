import 'dart:typed_data';

class TLS {
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
