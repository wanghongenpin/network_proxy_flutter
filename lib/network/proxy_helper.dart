import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/components/request_rewrite_manager.dart';
import 'package:network_proxy/network/components/script_manager.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/codec.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/network/util/file_read.dart';

import 'components/host_filter.dart';

class ProxyHelper {
  //请求本服务
  static localRequest(HttpRequest msg, Channel channel) async {
    //获取配置
    if (msg.path() == '/config') {
      final requestRewrites = await RequestRewrites.instance;
      var response = HttpResponse(HttpStatus.ok, protocolVersion: msg.protocolVersion);
      var body = {
        "requestRewrites": await requestRewrites.toFullJson(),
        'whitelist': HostFilter.whitelist.toJson(),
        'blacklist': HostFilter.blacklist.toJson(),
        'scripts': await ScriptManager.instance.then((script) {
          var list = script.list.map((e) async {
            return {'name': e.name, 'enabled': e.enabled, 'url': e.url, 'script': await script.getScript(e)};
          });
          return Future.wait(list);
        }),
      };
      response.body = utf8.encode(json.encode(body));
      channel.writeAndClose(response);
      return;
    }

    var response = HttpResponse(HttpStatus.ok, protocolVersion: msg.protocolVersion);
    response.body = utf8.encode('pong');
    response.headers.set("os", Platform.operatingSystem);
    response.headers.set("hostname", Platform.isAndroid ? Platform.operatingSystem : Platform.localHostname);
    channel.writeAndClose(response);
  }

  /// 下载证书
  static void crtDownload(Channel channel, HttpRequest request) async {
    const String fileMimeType = 'application/x-x509-ca-cert';
    var response = HttpResponse(HttpStatus.ok);
    response.headers.set(HttpHeaders.CONTENT_TYPE, fileMimeType);
    response.headers.set("Content-Disposition", 'inline;filename=ProxyPinCA.crt');
    response.headers.set("Connection", 'close');

    var body = await FileRead.read('assets/certs/ca.crt');
    response.headers.set("Content-Length", body.lengthInBytes.toString());

    if (request.method == HttpMethod.head) {
      channel.writeAndClose(response);
      return;
    }
    response.body = body.buffer.asUint8List();
    channel.writeAndClose(response);
  }

  ///异常处理
  static exceptionHandler(
      ChannelContext channelContext, Channel channel, EventListener? listener, HttpRequest? request, error) async {
    HostAndPort? hostAndPort = channelContext.host;
    hostAndPort ??= HostAndPort.host(
        scheme: HostAndPort.httpScheme, channel.remoteSocketAddress.host, channel.remoteSocketAddress.port);
    String message = error.toString();
    HttpStatus status = HttpStatus(-1, message);
    if (error is HandshakeException) {
      status = HttpStatus(-2, 'SSL握手失败');
    } else if (error is ParserException) {
      status = HttpStatus(-3, error.message);
    } else if (error is SocketException) {
      status = HttpStatus(-4, error.message);
    } else if (error is SignalException) {
      status.reason('执行脚本异常');
    }

    request ??= HttpRequest(HttpMethod.connect, hostAndPort.domain)
      ..body = message.codeUnits
      ..headers.contentLength = message.codeUnits.length
      ..hostAndPort = hostAndPort;
    request.processInfo ??= channelContext.processInfo;

    request.response ??= HttpResponse(status)
      ..headers.contentType = 'text/plain'
      ..headers.contentLength = message.codeUnits.length
      ..body = message.codeUnits;
    request.response?.request = request;

    channelContext.host = hostAndPort;

    listener?.onRequest(channel, request);
    listener?.onResponse(channelContext, request.response!);
  }
}
