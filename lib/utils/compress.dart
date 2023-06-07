import 'dart:io';

///GZIP 解压缩
List<int> gzipDecode(List<int> byteBuffer) {
  GZipCodec gzipCodec = GZipCodec();
  return gzipCodec.decode(byteBuffer);
}

///GZIP 解压缩
List<int> gzipEncode(List<int> input) {
  return GZipCodec().encode(input);
}
