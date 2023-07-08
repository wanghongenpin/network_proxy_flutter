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

String? ip;

Future<String> localIp() async {
  ip ??= await NetworkInterface.list().then((interfaces) {
    return interfaces.firstWhere((it) => it.name == "en0", orElse: () => interfaces.first).addresses.first.address;
  });
  return ip!;
}

Future<String> networkName() {
  return NetworkInterface.list().then((interfaces) => interfaces.first.name);
}
