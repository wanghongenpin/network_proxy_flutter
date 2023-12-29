package com.network.proxy.vpn.util

import java.nio.ByteBuffer
import kotlin.math.min


object TLS {

    /**
     * 判断是否是TLS Client Hello
     */
    fun isTLSClientHello(packetData: ByteBuffer): Boolean {
        if (packetData.remaining() < 43) return false
        val position = packetData.position()
        val data = packetData.array()
        if (data[position].toInt() != 0x16 /* handshake */) return false
        if (data[1 + position].toInt() != 0x03) return false
        return if (data[5 + position].toInt() != 0x01) false else data[9 + position].toInt() == 0x03 && data[10 + position] >= 0x00 && data[1 + position] <= 0x03
    }

    /**
     * 从TLS Client Hello 解析域名
     */
    fun getDomain(buffer: ByteBuffer): String? {
        var offset = buffer.position()
        val limit = buffer.limit()
        //TLS Client Hello
        if (buffer[offset].toInt() != 0x16) return null
        //Skip 43 byte header
        offset += 43
        if (limit < (offset + 1)) return null

        //read session id
        val sessionIDLength = buffer[offset++]
        offset += sessionIDLength

        //read cipher suites
        if (offset + 2 > limit) return null
        val cipherSuitesLength = buffer.getShort(offset)
        offset += 2
        offset += cipherSuitesLength

        //read Compression method.
        if (offset + 1 > limit) return null
        val compressionMethodLength = buffer[offset++].toInt() and 0xFF
        offset += compressionMethodLength
        if (offset > limit) return null

        //read Extensions
        if (offset + 2 > limit) return null

        val extensionsLength = buffer.getShort(offset)
        offset += 2
        if (offset + extensionsLength > limit) return null

        var end: Int = offset + extensionsLength
        end = min(end, limit)
        while (offset + 4 <= end) {
            val extensionType = buffer.getShort(offset)
            val extensionLength = buffer.getShort(offset + 2)
            offset += 4
            //server_name
            if (extensionType.toInt() == 0) {
                if (offset + 5 > limit) return null
                val serverNameListLength = buffer.getShort(offset)
                offset += 2
                if (offset > limit) return null
                if (offset + serverNameListLength > limit) return null

                val serverNameType = buffer[offset++]
                val serverNameLength = buffer.getShort(offset)
                offset += 2
                if (offset > limit || serverNameType.toInt() != 0) return null
                if (offset + serverNameLength > limit) return null
                val serverNameBytes = ByteArray(serverNameLength.toInt())
                buffer.get(serverNameBytes)
                return String(serverNameBytes)
            } else {
                offset += extensionLength
            }
        }
        return null
    }

}