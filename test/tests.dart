

import 'dart:io';

void main() async {
  // print(RegExp('^www.baidu.com').hasMatch("https://www.baidu.com/wqeqweqe"));
  // String text = "http://dddd/hello/world?name=dad&val=12a";
  // print("mame=\$1123".replaceAll(RegExp('\\\$\\d'), "123"));
  // print("app: ddd".split(": "));
  // print(text.replaceAllMapped(RegExp("name=(dad)"), (match) {
  //   var replaceAll = "mame=\$1-123".replaceAll("\$1", match.group(1)!);
  //
  //   print(replaceAll);
  //   return replaceAll;
  // }));
  // print(Platform.version);
  print(Platform.localHostname);
  print(Platform.operatingSystem);
  // print(Platform.localeName);
  print(Platform.script);
}
