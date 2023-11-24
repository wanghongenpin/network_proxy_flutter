import 'dart:io';

import 'package:flutter/services.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:path_provider/path_provider.dart';

class FileRead {
  static String? userHome;

  static Future<File> homeDir() async {
    if (userHome != null) {
      return File("${userHome!}${Platform.pathSeparator}.proxypin");
    }
    if (Platforms.isDesktop()) {
      userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    } else {
      userHome = (await getApplicationSupportDirectory()).path;
    }

    var separator = Platform.pathSeparator;
    return File("${userHome!}$separator.proxypin");
  }

  static Future<String> readAsString(String file) async {
    return rootBundle.loadString(file);
    // return File(file).readAsString();
  }

  static Future<Uint8List> read(String file) async {
    return rootBundle.load(file).then((bateData) => bateData.buffer.asUint8List());
    // return File(file).readAsBytes();
  }
}
