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

/// 获取本机ip (en0 or WLAN)优先
Future<String> localIp() async {
  ip ??= await localAddress().then((value) => value.address);
  return ip!;
}

Future<InternetAddress> localAddress() async {
  return await NetworkInterface.list().then((interfaces) {
    return interfaces
        .firstWhere(primary, orElse: () => interfaces.first)
        .addresses
        .first;
  });
}

List<String>? ipList;

/// 获取本机所有ip
Future<List<String>> localIps() async {
  if (ipList != null) {
    return ipList!;
  }

  var list = await NetworkInterface.list();
  list.sort((a, b) {
    if (primary(a)) {
      return -1;
    }
    return 1;
  });
  ipList = list.map((it) => it.addresses.first.address).toList();
  return ipList!;
}

Future<String> networkName() {
  return NetworkInterface.list()
      .then((interfaces) => interfaces.firstWhere(primary, orElse: () => interfaces.first).name);
}

// en0(macos系统) or WLAN(widows设备名)优先
bool primary(NetworkInterface it) {
  return it.name == 'en0' || it.name == 'WLAN';
}
