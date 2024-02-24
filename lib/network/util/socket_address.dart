import 'dart:io';

class InetSocketAddress {
  final InternetAddress address;
  final int port;

  InetSocketAddress(this.address, this.port);

  String get host => address.host;

  @override
  String toString() {
    return "InetSocketAddress($address:$port)";
  }
}
