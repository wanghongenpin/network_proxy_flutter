import 'dart:io';

void main() {
  NetworkInterface.list().then((interfaces) => interfaces.forEach((interface) {
        print(interface.name);
        for (var address in interface.addresses) {
          print("  ${address.address}");
          print("  ${address.host}");
          print("  ${address.type}");
        }
      }));
}

Future<String> localIp() async {
  String ip = await NetworkInterface.list().then((interfaces) => interfaces.first.addresses.first.address);
  return ip;
}
