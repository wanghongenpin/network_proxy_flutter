import 'dart:io';

void main() {
  var iso8601string = DateTime.now().toUtc().toIso8601String();
  var parse = DateTime.parse(iso8601string).toLocal();
  print(DateTime.now().toIso8601String());
  print(parse.hour);
  print(DateTime.parse(iso8601string));
  print(DateTime.now().toUtc().toIso8601String());
  print(Platform.version);
  print(Platform.localHostname);
  print(Platform.operatingSystem);
  print(Platform.localeName);
}
