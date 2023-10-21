

import 'dart:io';

class Files {
  //获取文件名称

  static String getName(String path) {
    var index = path.lastIndexOf(Platform.pathSeparator);
    return path.substring(index + 1);
  }
}
