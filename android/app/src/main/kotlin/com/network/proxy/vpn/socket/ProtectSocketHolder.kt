package com.network.proxy.vpn.socket

import java.net.DatagramSocket
import java.net.Socket

/**
 * ProtectSocket的持有者，用于在VPNService中获取ProtectSocket的实例
 */
class ProtectSocketHolder {

    companion object {
        private var protectSocket: ProtectSocket? = null

        fun setProtectSocket(protectSocket: ProtectSocket) {
            this.protectSocket = protectSocket
        }

        fun getProtectSocket(): ProtectSocket? {
            return protectSocket
        }

        fun protect(socket: Socket): Boolean {
            return protectSocket?.protect(socket) ?: false
        }

        fun protect(socket: DatagramSocket): Boolean {
            return protectSocket?.protect(socket) ?: false
        }
    }


}