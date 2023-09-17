import 'dart:io';

void main() {
  print(DateTime.now().toIso8601String());
  print(DateTime.now().toString());
  print(DateTime.now().toUtc().toString());
  print(Platform.version);
  print(Platform.localHostname);
  print(Platform.operatingSystem);
  print(Platform.localeName);
}
