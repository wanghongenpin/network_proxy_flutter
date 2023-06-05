import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:network/network/util/AttributeKeys.dart';
import 'package:network/network/util/CertificateManager.dart';


///处理I/O事件或截获I/O操作
abstract class ChannelHandler<T> {
  var log = Logger(
      printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: false,
    excludeBox: {Level.info: true, Level.debug: true},
  ));

  void channelActive(Channel channel) {}

  void channelRead(Channel channel, T msg) {}

  void channelInactive(Channel channel) {
    log.i("close $channel");
  }

  void exceptionCaught(Channel channel, Object cause, {StackTrace? trace}) {
    var attribute = channel.getAttribute(AttributeKeys.HOST_KEY);
    log.e("error $attribute $channel", cause, trace);
  }
}

///与网络套接字或组件的连接，能够进行读、写、连接和绑定等I/O操作。
class Channel {
  final int _id;
  final ChannelPipeline pipeline = ChannelPipeline();
  Socket _socket;
  final Map<String, Object> _attributes = {};
  bool isOpen = true;

  //此通道连接到的远程地址
  final InternetAddress remoteAddress;
  final int remotePort;

  Channel(this._socket)
      : _id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(9999),
        remoteAddress = _socket.remoteAddress,
        remotePort = _socket.remotePort;

  ///返回此channel的全局唯一标识符。
  String get id => _id.toRadixString(16);

  Socket get socket => _socket;

  set secureSocket(secureSocket) => _socket = secureSocket;

  Future<void> write(Object obj) async {
    var data = pipeline._encoder.encode(obj);
    _socket.add(data);
    await _socket.flush();
  }

  void close() {
    if (isClosed) {
      return;
    }
    _socket.destroy();
    isOpen = false;
  }

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
    return 'Channel($_id ${remoteAddress.host}:$remotePort)';
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

  @override
  void channelActive(Channel channel) {
    _handler.channelActive(channel);
  }

  @override
  void channelRead(Channel channel, Uint8List msg) {
    try {
      var data = _decoder.decode(msg);
      if (data != null) _handler.channelRead(channel, data!);
    } catch (error, trace) {
      exceptionCaught(channel, error, trace: trace);
    }
  }

  @override
  exceptionCaught(Channel channel, cause, {StackTrace? trace}) {
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
  final String host;
  final int port;

  HostAndPort(this.scheme, this.host, this.port);

  bool isSsl() {
    return httpsScheme.startsWith(scheme);
  }

  /// 根据url构建
  static HostAndPort of(String url) {
    String domain = url;
    String? scheme;
    //域名格式 直接解析
    if (url.startsWith(httpScheme)) {
      //httpScheme
      scheme = url.startsWith(httpsScheme) ? httpsScheme : httpScheme;
      domain = url.substring(scheme.length).split("/")[0];
    }
    //ip格式 host:port
    List<String> hostAndPort = domain.split(":");

    if (hostAndPort.length == 2) {
      bool isSsl = hostAndPort[1] == "443";
      scheme = isSsl ? httpsScheme : httpScheme;
      return HostAndPort(scheme, hostAndPort[0], int.parse(hostAndPort[1]));
    }
    scheme ??= httpScheme;
    return HostAndPort(scheme, hostAndPort[0], 80);
  }

  @override
  String toString() {
    return '$scheme$host:$port';
  }
}

/// 解码
abstract interface class Decoder<T> {
  T? decode(Uint8List data);
}

/// 编码
abstract interface class Encoder<T> {
  List<int> encode(T data);
}

/// 编解码器
abstract class Codec<T> implements Decoder<T>, Encoder<T> {
  static const int defaultMaxInitialLineLength = 1024;
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

  Network initChannel(void Function(Channel channel) initializer) {
    _channelInitializer = initializer;
    return this;
  }

  Channel listen(Socket socket) {
    var channel = Channel(socket);
    _channelInitializer.call(channel);

    channel.pipeline.channelActive(channel);

    socket.listen((data) => _onEvent(data, channel),
        onError: (error, trace) => channel.pipeline.exceptionCaught(channel, error, trace: trace),
        onDone: () => channel.pipeline.channelInactive(channel));

    return channel;
  }

  _onEvent(Uint8List data, Channel channel) async {
    HostAndPort? hostAndPort = channel.getAttribute(AttributeKeys.HOST_KEY);
    if (hostAndPort != null && hostAndPort.isSsl()) {
      try {
        var certificate = await CertificateManager.getCertificateContext(hostAndPort.host);
        SecureSocket secureSocket = await SecureSocket.secureServer(channel.socket, certificate, bufferedData: data);
        channel.secureSocket = secureSocket;
        secureSocket.listen((event) => channel.pipeline.channelRead(channel, event));
      } catch (error, trace) {
        channel.pipeline._handler.exceptionCaught(channel, error, trace: trace);
      }
      return;
    }

    channel.pipeline.channelRead(channel, data);
  }
}

class Server extends Network {
  final int port;

  Server(this.port);

  Future<void> bind() async {
    ServerSocket.bind(InternetAddress.loopbackIPv4, port).then((serverSocket) => {
          serverSocket.listen((socket) {
            listen(socket);
          })
        });
  }
}

class Client extends Network {
  var log = Logger();

  Future<Channel> connect(HostAndPort hostAndPort) async {
    if (hostAndPort.isSsl()) {
      return SecureSocket.connect(hostAndPort.host, hostAndPort.port, onBadCertificate: (certificate) => true)
          .then((socket) => listen(socket));
    }
    return Socket.connect(hostAndPort.host, hostAndPort.port).then((socket) => listen(socket));
  }
}
