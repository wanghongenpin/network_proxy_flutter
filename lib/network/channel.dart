/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/codec.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/logger.dart';

import 'handler.dart';

///处理I/O事件或截获I/O操作
abstract class ChannelHandler<T> {
  var log = logger;

  ///连接建立
  void channelActive(Channel channel) {}

  ///读取数据事件
  void channelRead(Channel channel, T msg) {}

  ///连接断开
  void channelInactive(Channel channel) {
    // log.i("close $channel");
  }

  void exceptionCaught(Channel channel, dynamic error, {StackTrace? trace}) {
    HostAndPort? attribute = channel.getAttribute(AttributeKeys.host);
    log.e("[${channel.id}] error $attribute $channel", error: error, stackTrace: trace);
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

  Object? error; //异常

  Channel(this._socket)
      : _id = DateTime.now().millisecondsSinceEpoch + Random().nextInt(999999),
        remoteAddress = _socket.remoteAddress,
        remotePort = _socket.remotePort;

  ///返回此channel的全局唯一标识符。
  String get id => _id.toRadixString(16);

  Socket get socket => _socket;

  set secureSocket(SecureSocket secureSocket) {
    _socket = secureSocket;
    pipeline.listen(this);
  }

  String? get selectedProtocol => isSsl ? (_socket as SecureSocket).selectedProtocol : null;

  ///是否是ssl链接
  bool get isSsl => _socket is SecureSocket;

  Future<void> write(Object obj) async {
    if (isClosed) {
      logger.w("[$id] channel is closed");
      return;
    }

    //只能有一个写入
    int retry = 0;
    while (isWriting && retry++ < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    isWriting = true;
    try {
      var data = pipeline._encoder.encode(obj);
      if (!isClosed) {
        _socket.add(data);
      }
      await _socket.flush();
    } catch (e, t) {
      // print(getAttribute(id)._attributes);
      print(e);
      print(t);
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
    isOpen = false;
    _socket.destroy();
  }

  ///返回此channel是否打开
  bool get isClosed => !isOpen;

  T? getAttribute<T>(String key) {
    if (!_attributes.containsKey(key)) {
      return null;
    }
    return _attributes[key] as T;
  }

  void putAttribute(String key, Object? value) {
    if (value == null) {
      _attributes.remove(key);
      return;
    }
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
  late ChannelHandler handler;
  EventListener? listener;

  final ByteBuf buffer = ByteBuf();

  handle(Decoder decoder, Encoder encoder, ChannelHandler handler) {
    _encoder = encoder;
    _decoder = decoder;
    this.handler = handler;
  }

  /// 监听
  void listen(Channel channel) {
    buffer.clear();

    channel.socket.listen((data) => channel.pipeline.channelRead(channel, data),
        onError: (error, trace) => channel.pipeline.exceptionCaught(channel, error, trace: trace),
        onDone: () => channel.pipeline.channelInactive(channel));
  }

  @override
  void channelActive(Channel channel) {
    handler.channelActive(channel);
  }

  /// 转发请求
  void relay(Channel clientChannel, Channel remoteChannel) {
    var rawCodec = RawCodec();
    clientChannel.pipeline.handle(rawCodec, rawCodec, RelayHandler(remoteChannel));
    remoteChannel.pipeline.handle(rawCodec, rawCodec, RelayHandler(clientChannel));
  }

  ///远程转发请求
  remoteForward(Channel clientChannel, HostAndPort remote, Uint8List msg) async {
    Channel? remoteChannel = clientChannel.getAttribute(clientChannel.id);
    remoteChannel = remoteChannel ?? await HttpClients.startConnect(remote, RelayHandler(clientChannel));
    if (clientChannel.isSsl && !remoteChannel.isSsl) {
      remoteChannel.secureSocket = await SecureSocket.secure(remoteChannel.socket,
          host: clientChannel.getAttribute(AttributeKeys.domain), onBadCertificate: (certificate) => true);
    }

    relay(clientChannel, remoteChannel);
    handler.channelRead(clientChannel, msg);
  }

  @override
  void channelRead(Channel channel, Uint8List msg) async {
    try {
      //手机扫码连接转发远程
      HostAndPort? remote = channel.getAttribute(AttributeKeys.remote);
      Channel? remoteChannel = channel.getAttribute(channel.id);
      if (remote != null) {
        remoteForward(channel, remote, msg);
        return;
      }

      buffer.add(msg);
      //大body 不解析直接转发
      if (buffer.length > Codec.maxBodyLength) {
        relay(channel, remoteChannel!);
        handler.channelRead(channel, buffer.buffer);
        buffer.clear();
        return;
      }

      HttpRequest? request = remoteChannel?.getAttribute(AttributeKeys.request);
      var data = _decoder.decode(buffer, resolveBody: request?.method != HttpMethod.head);
      if (data == null) {
        return;
      }

      var length = buffer.length;
      buffer.clear();

      if (data is HttpRequest) {
        data.packageSize = length;
        data.hostAndPort = channel.getAttribute(AttributeKeys.host) ?? getHostAndPort(data, ssl: channel.isSsl);
        if (data.headers.host != null && data.headers.host?.contains(":") == false) {
          data.hostAndPort?.host = data.headers.host!;
        }
      }

      if (data is HttpResponse) {
        data.packageSize = length;
        data.remoteAddress = '${channel.remoteAddress.host}:${channel.remotePort}';
        data.request = request;
        request?.response = data;
      }

      //websocket协议
      if (data is HttpResponse && data.isWebSocket && remoteChannel != null) {
        request?.hostAndPort?.scheme = channel.isSsl ? HostAndPort.wssScheme : HostAndPort.wsScheme;
        logger.d("webSocket ${data.request?.hostAndPort}");
        remoteChannel.write(data);

        var rawCodec = RawCodec();
        channel.pipeline.handle(rawCodec, rawCodec, WebSocketChannelHandler(remoteChannel, data, listener: listener));
        remoteChannel.pipeline
            .handle(rawCodec, rawCodec, WebSocketChannelHandler(channel, data.request!, listener: listener));
        return;
      }

      handler.channelRead(channel, data!);
    } catch (error, trace) {
      buffer.clear();
      exceptionCaught(channel, error, trace: trace);
    }
  }

  @override
  exceptionCaught(Channel channel, dynamic error, {StackTrace? trace}) {
    handler.exceptionCaught(channel, error, trace: trace);
  }

  @override
  channelInactive(Channel channel) {
    handler.channelInactive(channel);
  }
}

class RawCodec extends Codec<Object> {
  @override
  Object? decode(ByteBuf data, {bool resolveBody = true}) {
    return data.readBytes(data.readableBytes());
  }

  @override
  List<int> encode(Object data) {
    return data as List<int>;
  }
}

abstract interface class ChannelInitializer {
  void initChannel(Channel channel);
}
