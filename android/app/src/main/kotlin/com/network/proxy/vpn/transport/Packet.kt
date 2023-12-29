package com.network.proxy.vpn.transport

import com.network.proxy.vpn.transport.protocol.IP4Header
import com.network.proxy.vpn.transport.protocol.TransportHeader

class Packet(var ipHeader: IP4Header, var transportHeader: TransportHeader, var buffer: ByteArray) {
}