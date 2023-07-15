import 'dart:io';

class Platforms {
  /// 判断是否是桌面端
  static bool isDesktop() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 判断是否是移动端
  static bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }
}
