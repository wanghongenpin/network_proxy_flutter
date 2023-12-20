package com.network.proxy.vpn.socket

import java.net.DatagramSocket
import java.net.Socket

interface ProtectSocket {

    /**
     * 保护Socket不受VPN连接的影响。保护后，通过该套接字发送的数据将直接进入底层网络，因此其流量不会通过VPN转发。
     */
    fun protect(socket: Socket): Boolean

    fun protect(socket: DatagramSocket): Boolean

}