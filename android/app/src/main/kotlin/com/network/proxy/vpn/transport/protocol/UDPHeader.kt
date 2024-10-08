package com.network.proxy.vpn.transport.protocol


import com.network.proxy.vpn.util.PacketUtil
import java.nio.ByteBuffer


/**
 * UDP报头的数据结构。
 */
data class UDPHeader(
    var sourcePort: Int = 0, //源端口号 16bit
    var destinationPort: Int = 0, //目的端口号 16bit
    var length: Int = 0, //UDP数据报长度 16bit
    var checksum: Int = 0 //校验和 16bit
)


object UDPPacketFactory {
    @JvmStatic
    fun createUDPHeader(stream: ByteBuffer): UDPHeader {
        require(stream.remaining() >= 8) { "Minimum UDP header is 8 bytes." }
        val srcPort = stream.getShort().toInt() and 0xffff
        val destPort = stream.getShort().toInt() and 0xffff
        val length = stream.getShort().toInt() and 0xffff
        val checksum = stream.getShort().toInt()
        return UDPHeader(srcPort, destPort, length, checksum)
    }

    /**
     * 创建用于响应vpn客户端的数据包
     */
    @JvmStatic
    fun createResponsePacket(ip: IP4Header, udp: UDPHeader, packetData: ByteArray?): ByteArray {
        val buffer: ByteArray
        var udpLen = 8
        if (packetData != null) {
            udpLen += packetData.size
        }
        val srcPort = udp.destinationPort
        val destPort = udp.sourcePort
        val ipHeader = ip.copy()
        val srcIp = ip.destinationIP
        val destIp = ip.sourceIP
        ipHeader.setMayFragment(false)
        ipHeader.sourceIP = srcIp
        ipHeader.destinationIP = destIp
        ipHeader.identification = PacketUtil.getPacketId()

        //ip的长度是整个数据包的长度 => IP header length + UDP header length (8) + UDP body length
        val totalLength = ipHeader.getIPHeaderLength() + udpLen
        ipHeader.totalLength = totalLength
        buffer = ByteArray(totalLength)
        val ipData = ipHeader.toBytes()

        // clear IP checksum
        ipData[11] = 0
        ipData[10] = 0

        //calculate checksum for IP header
        val ipChecksum = PacketUtil.calculateChecksum(ipData, 0, ipData.size)
        //write result of checksum back to buffer
        System.arraycopy(ipChecksum, 0, ipData, 10, 2)
        System.arraycopy(ipData, 0, buffer, 0, ipData.size)

        //copy UDP header to buffer
        var start = ipData.size
        val intContainer = ByteArray(4)
        PacketUtil.writeIntToBytes(srcPort, intContainer, 0)

        //extract the last two bytes of int value
        System.arraycopy(intContainer, 2, buffer, start, 2)
        start += 2

        PacketUtil.writeIntToBytes(destPort, intContainer, 0)
        System.arraycopy(intContainer, 2, buffer, start, 2)
        start += 2
        PacketUtil.writeIntToBytes(udpLen, intContainer, 0)
        System.arraycopy(intContainer, 2, buffer, start, 2)
        start += 2

        val checksum: Short = 0
        PacketUtil.writeIntToBytes(checksum.toInt(), intContainer, 0)
        System.arraycopy(intContainer, 2, buffer, start, 2)
        start += 2

        //now copy udp data
        if (packetData != null) System.arraycopy(packetData, 0, buffer, start, packetData.size)
        return buffer
    }
}

