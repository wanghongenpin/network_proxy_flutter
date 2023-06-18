import 'dart:io';

///GZIP 解压缩
List<int> gzipDecode(List<int> byteBuffer) {
  GZipCodec gzipCodec = GZipCodec();
  try {
    return gzipCodec.decode(byteBuffer);
  } catch (e) {
    print("gzipDecode error: $e");
    return byteBuffer;
  }
}

///GZIP 解压缩
List<int> gzipEncode(List<int> input) {
  return GZipCodec().encode(input);
}
