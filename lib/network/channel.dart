import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/crts.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/network/util/logger.dart';

import 'handler.dart';

///处理I/O事件或截获I/O操作
abstract class ChannelHandler<T> {
  var log = logger;

  void channelActive(Channel channel) {}

  void channelRead(Channel channel, T msg) {}

  void channelInactive(Channel channel) {
    // log.i("close $channel");
  }

  void exceptionCaught(Channel channel, dynamic cause, {StackTrace? trace}) {
    HostAndPort? attribute = channel.getAttribute(AttributeKeys.host);
    log.e("error $attribute $channel", cause, trace);
    channel.close();
  }
}

///与网络套接字或组件的连接，能够进行读、写、连接和绑定等I/O操作。
class Channel {
  final int _id;
  final ChannelPipeline pipeline = ChannelPipeline();
  Socket _socket;
  final Map<String, Object> _attributes = {};

  //是否打开
  bool isOpen = true;

  //此通道连接到的远程地址
  final InternetAddress remoteAddress;
  final int remotePort;

  //是否写入中
  bool isWriting = false;

  Channel(this._socket)
      : _id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(999999),
        remoteAddress = _socket.remoteAddress,
        remotePort = _socket.remotePort;

  ///返回此channel的全局唯一标识符。
  String get id => _id.toRadixString(16);

  Socket get socket => _socket;

  set secureSocket(SecureSocket secureSocket) => _socket = secureSocket;

  Future<void> write(Object obj) async {
    if (isClosed) {
      logger.w("channel is closed $obj");
      return;
    }
    isWriting = true;
    try {
      var data = pipeline._encoder.encode(obj);
      _socket.add(data);
      await _socket.flush();
    } finally {
      isWriting = false;
    }
  }

  ///写入并关闭此channel
  Future<void> writeAndClose(Object obj) async {
    await write(obj);
    close();
  }

  ///关闭此channel
  void close() async {
    if (isClosed) {
      return;
    }

    //写入中，延迟关闭
    int retry = 0;
    while (isWriting && retry++ < 10) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _socket.destroy();
    isOpen = false;
  }

  ///返回此channel是否打开
  bool get isClosed => !isOpen;

  T? getAttribute<T>(String key) {
    if (!_attributes.containsKey(key)) {
      return null;
    }
    return _attributes[key] as T;
  }

  void putAttribute(String key, Object value) {
    _attributes[key] = value;
  }

  @override
  String toString() {
    return 'Channel($id ${remoteAddress.host}:$remotePort)';
  }
}

class ChannelPipeline extends ChannelHandler<Uint8List> {
  late Decoder _decoder;
  late Encoder _encoder;
  late ChannelHandler _handler;

  handle(Decoder decoder, Encoder encoder, ChannelHandler handler) {
    _encoder = encoder;
    _decoder = decoder;
    _handler = handler;
  }

  void listen(Channel channel) {
    channel.socket.listen((data) => channel.pipeline.channelRead(channel, data),
        onError: (error, trace) => channel.pipeline.exceptionCaught(channel, error, trace: trace),
        onDone: () => channel.pipeline.channelInactive(channel));
  }

  @override
  void channelActive(Channel channel) {
    _handler.channelActive(channel);
  }

  /// 转发请求
  void relay(Channel clientChannel, Channel remoteChannel) {
    var rawCodec = RawCodec();
    clientChannel.pipeline.handle(rawCodec, rawCodec, RelayHandler(remoteChannel));
    remoteChannel.pipeline.handle(rawCodec, rawCodec, RelayHandler(clientChannel));
  }

  @override
  void channelRead(Channel channel, Uint8List msg) {
    try {
      HostAndPort? remote = channel.getAttribute(AttributeKeys.remote);
      if (remote != null && channel.getAttribute(channel.id) != null) {
        relay(channel, channel.getAttribute(channel.id));
        _handler.channelRead(channel, msg);
        return;
      }

      var data = _decoder.decode(msg);
      if (data == null) {
        return;
      }

      if (data is HttpRequest) {
        data.hostAndPort = channel.getAttribute(AttributeKeys.host) ?? getHostAndPort(data);
        if (data.headers.host() != null && data.headers.host()?.contains(":") == false) {
          data.hostAndPort?.host = data.headers.host()!;
        }

        //websocket协议
        if (data.headers.get("Upgrade") == 'websocket' && channel.getAttribute(channel.id) != null) {
          relay(channel, channel.getAttribute(channel.id));
          channel.pipeline.channelRead(channel, msg);
          return;
        }
      }

      if (data is HttpResponse) {
        data.remoteAddress = '${channel.remoteAddress.host}:${channel.remotePort}';
      }
      _handler.channelRead(channel, data!);
    } catch (error, trace) {
      exceptionCaught(channel, error, trace: trace);
    }
  }

  @override
  exceptionCaught(Channel channel, dynamic cause, {StackTrace? trace}) {
    _handler.exceptionCaught(channel, cause, trace: trace);
  }

  @override
  channelInactive(Channel channel) {
    _handler.channelInactive(channel);
  }
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

/// 解码
abstract interface class Decoder<T> {
  /// 解码 如果返回null说明数据不完整
  T? decode(Uint8List data);
}

/// 编码
abstract interface class Encoder<T> {
  List<int> encode(T data);
}

/// 编解码器
abstract class Codec<T> implements Decoder<T>, Encoder<T> {
  static const int defaultMaxInitialLineLength = 10240;
  static const int maxBodyLength = 1024000;
}

class RawCodec extends Codec<Object> {
  @override
  Object? decode(Uint8List data) {
    return data;
  }

  @override
  List<int> encode(Object data) {
    return data as List<int>;
  }
}

abstract interface class ChannelInitializer {
  void initChannel(Channel channel);
}

class Network {
  late Function _channelInitializer;
  String? remoteHost;
  Configuration? configuration;

  Network initChannel(void Function(Channel channel) initializer) {
    _channelInitializer = initializer;
    return this;
  }

  Channel listen(Socket socket) {
    var channel = Channel(socket);
    _channelInitializer.call(channel);
    channel.pipeline.channelActive(channel);
    socket.listen((data) => _onEvent(data, channel),
        onError: (error, StackTrace trace) => channel.pipeline.exceptionCaught(channel, error, trace: trace),
        onDone: () => channel.pipeline.channelInactive(channel));
    return channel;
  }

  _onEvent(Uint8List data, Channel channel) async {
    if (remoteHost != null) {
      channel.putAttribute(AttributeKeys.remote, HostAndPort.of(remoteHost!));
    }

    //代理信息
    if (configuration?.externalProxy?.enable == true) {
      channel.putAttribute(AttributeKeys.proxyInfo, configuration!.externalProxy!);
    }

    HostAndPort? hostAndPort = channel.getAttribute(AttributeKeys.host);

    //黑名单 或 没开启https 直接转发
    if (HostFilter.filter(hostAndPort?.host) || (hostAndPort?.isSsl() == true && configuration?.enableSsl == false)) {
      relay(channel, channel.getAttribute(channel.id));
      channel.pipeline.channelRead(channel, data);
      return;
    }

    //ssl握手
    if (hostAndPort?.isSsl() == true) {
      ssl(channel, hostAndPort!, data);
      return;
    }

    channel.pipeline.channelRead(channel, data);
  }

  void ssl(Channel channel, HostAndPort hostAndPort, Uint8List data) async {
    try {
      //客户端ssl握手
      Channel remoteChannel = channel.getAttribute(channel.id);
      remoteChannel.secureSocket =
          await SecureSocket.secure(remoteChannel.socket, onBadCertificate: (certificate) => true);

      remoteChannel.pipeline.listen(remoteChannel);

      //ssl自签证书
      var certificate = await CertificateManager.getCertificateContext(hostAndPort.host);

      SecureSocket secureSocket = await SecureSocket.secureServer(channel.socket, certificate, bufferedData: data);
      channel.secureSocket = secureSocket;
      channel.pipeline.listen(channel);
    } catch (error, trace) {
      channel.pipeline._handler.exceptionCaught(channel, error, trace: trace);
    }
  }

  /// 转发请求
  void relay(Channel clientChannel, Channel remoteChannel) {
    var rawCodec = RawCodec();
    clientChannel.pipeline.handle(rawCodec, rawCodec, RelayHandler(remoteChannel));
    remoteChannel.pipeline.handle(rawCodec, rawCodec, RelayHandler(clientChannel));
  }
}

class Server extends Network {
  late ServerSocket serverSocket;
  bool isRunning = false;

  Server(Configuration configuration) {
    super.configuration = configuration;
  }

  Future<ServerSocket> bind(int port) async {
    serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    serverSocket.listen((socket) {
      listen(socket);
    });
    isRunning = true;
    return serverSocket;
  }

  Future<ServerSocket> stop() async {
    if (!isRunning) return serverSocket;
    isRunning = false;
    await serverSocket.close();
    return serverSocket;
  }
}

class Client extends Network {
  Future<Channel> connect(HostAndPort hostAndPort) async {
    String host = hostAndPort.host;
    //说明支持ipv6
    if (host.startsWith("[") && host.endsWith(']')) {
      host = host.substring(host.lastIndexOf(":") + 1, host.length - 1);
    }

    return Socket.connect(host, hostAndPort.port, timeout: const Duration(seconds: 3)).then((socket) => listen(socket));
  }

  /// ssl连接
  Future<Channel> secureConnect(HostAndPort hostAndPort) async {
    return SecureSocket.connect(hostAndPort.host, hostAndPort.port,
        timeout: const Duration(seconds: 3), onBadCertificate: (certificate) => true).then((socket) => listen(socket));
  }
}
