import 'dart:io';

void main() {
  print(RegExp('http://dddd/hello\$').hasMatch("http://dddd/hello/world"));
  print(Platform.version);
  print(Platform.localHostname);
  print(Platform.operatingSystem);
  print(Platform.localeName);
  print(Platform.script);
}
