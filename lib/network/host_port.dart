import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';

/// 获取主机和端口
HostAndPort getHostAndPort(HttpRequest request) {
  String requestUri = request.uri;
  //有些请求直接是路径 /xxx, 从header取host
  if (request.uri.startsWith("/")) {
    requestUri = request.headers.get(HttpHeaders.HOST)!;
  }

  return HostAndPort.of(requestUri, ssl: request.method == HttpMethod.connect ? true : null);
}

class HostAndPort {
  static const String httpScheme = "http://";
  static const String httpsScheme = "https://";
  final String scheme;
  String host;
  final int port;

  HostAndPort(this.scheme, this.host, this.port);

  factory HostAndPort.host(String host, int port) {
    return HostAndPort(port == 443 ? httpsScheme : httpScheme, host, port);
  }

  bool isSsl() {
    return httpsScheme.startsWith(scheme);
  }

  /// 根据url构建
  static HostAndPort of(String url, {bool? ssl}) {
    String domain = url;
    String? scheme;
    //域名格式 直接解析
    if (url.startsWith(httpScheme) || url.startsWith(httpsScheme)) {
      //httpScheme
      scheme = url.startsWith(httpsScheme) ? httpsScheme : httpScheme;
      domain = url.substring(scheme.length).split("/")[0];
      //说明支持ipv6
      if (domain.startsWith('[') && domain.endsWith(']')) {
        return HostAndPort(scheme, domain, scheme == httpScheme ? 80 : 443);
      }
    }
    //ip格式 host:port
    List<String> hostAndPort = domain.split(":");
    if (hostAndPort.length == 2) {
      bool isSsl = ssl ?? hostAndPort[1] == "443";
      scheme = isSsl ? httpsScheme : httpScheme;
      return HostAndPort(scheme, hostAndPort[0], int.parse(hostAndPort[1]));
    }
    scheme ??= (ssl == true ? httpsScheme : httpScheme);
    return HostAndPort(scheme, hostAndPort[0], scheme == httpScheme ? 80 : 443);
  }

  String get domain {
    return '$scheme$host${(port == 80 || port == 443) ? "" : ":$port"}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostAndPort &&
          runtimeType == other.runtimeType &&
          scheme == other.scheme &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => scheme.hashCode ^ host.hashCode ^ port.hashCode;

  @override
  String toString() {
    return domain;
  }
}
