import 'dart:typed_data';

import 'package:pointycastle/pointycastle.dart';

class KeyUsage {
  static const int digitalSignature = (1 << 7);
  static const int nonRepudiation = (1 << 6);
  static const int keyEncipherment = (1 << 5);
  static const int dataEncipherment = (1 << 4);
  static const int keyAgreement = (1 << 3);
  static const int keyCertSign = (1 << 2);
  static const int cRLSign = (1 << 1);
  static const int encipherOnly = (1 << 0);
  static const int decipherOnly = (1 << 15);

  final ASN1BitString bitString;
  final bool critical;

  KeyUsage(int usage, {this.critical = true}) : bitString = ASN1BitString.fromBytes(keyUsageBytes(usage));

  static Uint8List keyUsageBytes(int valueBytes) {
    var bytes = [valueBytes];
    if (valueBytes > 0xFF) {
      final int firstValueByte = (valueBytes & int.parse("ff00", radix: 16)) >> 8;
      final int secondValueByte = (valueBytes & int.parse("00ff", radix: 16));
      bytes = [firstValueByte, secondValueByte];
    }

    return Uint8List.fromList(<int>[
      // BitString identifier
      3,
      // Length
      bytes.length + 1,
      // Unused bytes at the end
      1,
      ...bytes
    ]);
  }
}
