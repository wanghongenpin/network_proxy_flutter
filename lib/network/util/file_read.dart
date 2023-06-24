import 'package:flutter/services.dart';

class FileRead {
  static Future<String> readAsString(String file) async {
    return rootBundle.loadString(file);
    // return File(file).readAsString();
  }

  static Future<Uint8List> read(String file) async {
    return rootBundle.load(file).then((bateData) => bateData.buffer.asUint8List());
    // return File(file).readAsBytes();
  }
}
