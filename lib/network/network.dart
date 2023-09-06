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
import 'dart:typed_data';

import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/crts.dart';
import 'package:network_proxy/network/util/host_filter.dart';

import 'host_port.dart';

class Network {
  late Function _channelInitializer;
  Configuration? configuration;
  StreamSubscription? subscription;

  Network initChannel(void Function(Channel channel) initializer) {
    _channelInitializer = initializer;
    return this;
  }

  Channel listen(Socket socket) {
    var channel = Channel(socket);
    _channelInitializer.call(channel);
    channel.pipeline.channelActive(channel);
    subscription = socket.listen((data) => _onEvent(data, channel),
        onError: (error, StackTrace trace) => channel.pipeline.exceptionCaught(channel, error, trace: trace),
        onDone: () => channel.pipeline.channelInactive(channel));
    return channel;
  }

  _onEvent(Uint8List data, Channel channel) async {
    //手机扫码转发远程地址
    if (configuration?.remoteHost != null) {
      channel.putAttribute(AttributeKeys.remote, HostAndPort.of(configuration!.remoteHost!));
    }

    //外部代理信息
    if (configuration?.externalProxy?.enabled == true) {
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
    if (hostAndPort?.isSsl() == true || (data.length > 3 && data.first == 0x16 && data[1] == 0x03 && data[2] == 0x01)) {
      if (hostAndPort?.scheme == HostAndPort.httpScheme) {
        hostAndPort?.scheme = HostAndPort.httpsScheme;
      }

      ssl(channel, hostAndPort!, data);
      return;
    }

    channel.pipeline.channelRead(channel, data);
  }

  /// ssl握手
  void ssl(Channel channel, HostAndPort hostAndPort, Uint8List data) async {
    try {
      Channel? remoteChannel = channel.getAttribute(channel.id);
      if (remoteChannel != null) {
        remoteChannel.secureSocket = await SecureSocket.secure(remoteChannel.socket,
            host: hostAndPort.host, onBadCertificate: (certificate) => true);
      }

      //ssl自签证书
      var certificate = await CertificateManager.getCertificateContext(hostAndPort.host);
      //服务端等待客户端ssl握手
      channel.secureSocket = await SecureSocket.secureServer(channel.socket, certificate, bufferedData: data);
    } catch (error, trace) {
      if (error is HandshakeException) {
        await subscription?.cancel();
      }
      channel.pipeline.exceptionCaught(channel, error, trace: trace);
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

    return Socket.connect(host, hostAndPort.port, timeout: const Duration(seconds: 3)).then((socket) {
      if (socket.address.type != InternetAddressType.unix) {
        socket.setOption(SocketOption.tcpNoDelay, true);
      }
      return listen(socket);
    });
  }

  /// ssl连接
  Future<Channel> secureConnect(HostAndPort hostAndPort) async {
    return SecureSocket.connect(hostAndPort.host, hostAndPort.port,
        timeout: const Duration(seconds: 3), onBadCertificate: (certificate) => true).then((socket) => listen(socket));
  }
}
