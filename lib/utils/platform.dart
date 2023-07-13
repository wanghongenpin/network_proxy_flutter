import 'dart:io';

class Platforms {
  static bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }
}
