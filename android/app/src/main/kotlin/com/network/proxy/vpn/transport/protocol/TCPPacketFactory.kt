package com.network.proxy.vpn.transport.protocol

import com.network.proxy.vpn.transport.Packet
import com.network.proxy.vpn.util.PacketUtil
import java.nio.ByteBuffer
import java.util.concurrent.ThreadLocalRandom

object TCPPacketFactory {

    private const val TCP_HEADER_LENGTH = 20

    /**
     * 从tcp报文创建tcpHeader
     */
    @JvmStatic
    fun createTCPHeader(byteBuffer: ByteBuffer): TCPHeader {
        if (byteBuffer.remaining() < TCP_HEADER_LENGTH) {
            throw IllegalArgumentException("Invalid TCP Header Length")
        }

        val sourcePort: Int = byteBuffer.getShort().toInt() and 0xFFFF
        val destinationPort: Int = byteBuffer.getShort().toInt() and 0xFFFF
        val sequenceNumber: Long = byteBuffer.getInt().toLong()
        val ackNumber: Long = byteBuffer.getInt().toLong()

        val dataOffsetAndReserved = byteBuffer.get()
        val dataOffset = (dataOffsetAndReserved.toInt() and 0xF0) shr 4
        val isNs: Boolean = dataOffsetAndReserved.toInt() and 0x1 > 0x0

        val flags = byteBuffer.get().toInt()

        val window = byteBuffer.short.toInt()
        val checksum = byteBuffer.short.toInt()
        val urgentPointer = byteBuffer.short.toInt()

        var optionsAndPadding: ByteArray? = null
        val optionsSize = dataOffset - 5
        if (optionsSize > 0) {
            optionsAndPadding = ByteArray(optionsSize * 4)
            byteBuffer.get(optionsAndPadding, 0, optionsSize * 4)
        }
        return TCPHeader(
            sourcePort, destinationPort, sequenceNumber, ackNumber,
            dataOffset, isNs, flags, window, checksum, urgentPointer, optionsAndPadding
        )
    }

    /**
     * 创建带有RST标志的数据包，以便在需要重置时发送到客户端。
     */
    fun createRstData(ipHeader: IP4Header, tcpHeader: TCPHeader, dataLength: Int): ByteArray {
        val ip = ipHeader.copy()
        val tcp = tcpHeader.copy()

        var ackNumber: Long = 0
        var seqNumber: Long = 0

        if (tcp.ackNumber > 0) {
            seqNumber = tcp.ackNumber
        } else {
            ackNumber = tcp.sequenceNumber + dataLength
        }

        tcp.ackNumber = ackNumber
        tcp.sequenceNumber = seqNumber

        //将IP从源翻转到目标
        flipIp(ip, tcp)

        ip.identification = 0

        tcp.flags = 0
        tcp.isNS = false
        tcp.setIsRST(true)

        tcp.dataOffset = 5
        tcp.options = null
        tcp.windowSize = 0

        //重新计算IP长度
        val totalLength = ip.getIPHeaderLength() + tcp.getTCPHeaderLength()

        ip.totalLength = totalLength

        return createPacketData(ip, tcp, null)
    }

    /**
     * 创建数据包数据以发送回客户端
     */
    @JvmStatic
    fun createResponsePacketData(
        ipHeader: IP4Header, tcpHeader: TCPHeader, packetData: ByteArray?, isPsh: Boolean,
        ackNumber: Long, seqNumber: Long, timeSender: Int, timeReplyTo: Int
    ): ByteArray {
        val ip = ipHeader.copy()
        val tcp = tcpHeader.copy()

        flipIp(ip, tcp)
        tcp.ackNumber = ackNumber
        tcp.sequenceNumber = seqNumber
        ip.identification = PacketUtil.getPacketId()

        //总是发送ACK

        //ACK is always sent
        tcp.setIsACK(true)
        tcp.setIsSYN(false)
        tcp.setIsPSH(isPsh)
        tcp.setIsFIN(false)
        tcp.timeStampSender = timeSender
        tcp.timeStampReplyTo = timeReplyTo
        tcp.dataOffset = 5
        tcp.options = null

        var totalLength = ip.getIPHeaderLength() + tcp.getTCPHeaderLength()
        if (packetData != null) {
            totalLength += packetData.size
        }
        ip.totalLength = totalLength

        return createPacketData(ip, tcp, packetData)
    }


    /**
     * 向客户端确认服务器已收到请求。
     */
    @JvmStatic
    fun createResponseAckData(
        ipHeader: IP4Header, tcpHeader: TCPHeader, ackToClient: Long
    ): ByteArray {
        val ip = ipHeader.copy()
        val tcp = tcpHeader.copy()

        flipIp(ip, tcp)
        val seqNumber = tcp.ackNumber
        tcp.ackNumber = ackToClient
        tcp.sequenceNumber = seqNumber

        ip.identification = PacketUtil.getPacketId()

        //ACK
        tcp.setIsACK(true)
        tcp.setIsSYN(false)
        tcp.setIsPSH(false)
        tcp.setIsFIN(false)
        tcp.dataOffset = 5
        tcp.options = null

        ip.totalLength = ip.getIPHeaderLength() + tcp.getTCPHeaderLength()
        return createPacketData(ip, tcp, null)
    }

    //将IP从源翻转到目标
    private fun flipIp(ip: IP4Header, tcp: TCPHeader) {
        val sourceIp = ip.destinationIP
        val destIp = ip.sourceIP
        val sourcePort = tcp.getDestinationPort()
        val destPort = tcp.getSourcePort()

        ip.destinationIP = destIp
        ip.sourceIP = sourceIp
        tcp.setDestinationPort(destPort)
        tcp.setSourcePort(sourcePort)
    }

    /**
     * 通过写回客户端流创建SYN-ACK数据包数据
     */
    fun createSynAckPacketData(ipHeader: IP4Header, tcpHeader: TCPHeader): Packet {
        val ip = ipHeader.copy()
        val tcp = tcpHeader.copy()

        flipIp(ip, tcp)

        //ack = received sequence + 1
        val ackNumber = tcpHeader.sequenceNumber + 1
        tcp.ackNumber = ackNumber

        //服务器生成的初始序列号
        val seqNumber = ThreadLocalRandom.current().nextLong(0, 100000)
        tcp.sequenceNumber = seqNumber

        //SYN-ACK
        tcp.setIsACK(true)
        tcp.setIsSYN(true)

        tcp.timeStampReplyTo = tcp.timeStampSender
        tcp.timeStampSender = PacketUtil.currentTime

        tcp.dataOffset = 5
        tcp.options = null
        ip.totalLength = ip.getIPHeaderLength() + tcp.getTCPHeaderLength()

        return Packet(ip, tcp, createPacketData(ip, tcp, null))
    }

    /**
     * 创建发送到客户端的FIN-ACK
     */
    fun createFinAckData(
        ipHeader: IP4Header, tcpHeader: TCPHeader, ackToClient: Long,
        seqToClient: Long, isFin: Boolean, isAck: Boolean
    ): ByteArray {
        val ip = ipHeader.copy()
        val tcp = tcpHeader.copy()

        flipIp(ip, tcp)

        tcp.ackNumber = ackToClient
        tcp.sequenceNumber = seqToClient
        ip.identification = PacketUtil.getPacketId()

        //ACK
        tcp.setIsACK(isAck)
        tcp.setIsSYN(false)
        tcp.setIsPSH(false)
        tcp.setIsFIN(isFin)

        tcp.dataOffset = 5
        tcp.options = null

        ip.totalLength = ip.getIPHeaderLength() + tcp.getTCPHeaderLength()
        return createPacketData(ip, tcp, null)
    }

    fun createFinData(
        ip: IP4Header, tcp: TCPHeader, ackNumber: Long, seqNumber: Long,
        timeSender: Int, timeReplyTo: Int
    ): ByteArray {
        //将IP从源翻转到目标
        flipIp(ip, tcp)

        tcp.ackNumber = ackNumber
        tcp.sequenceNumber = seqNumber

        ip.identification = PacketUtil.getPacketId()

        tcp.timeStampReplyTo = timeReplyTo
        tcp.timeStampSender = timeSender

        tcp.flags = 0
        tcp.isNS = false
        tcp.setIsACK(true)
        tcp.setIsFIN(true)

        tcp.dataOffset = 5
        tcp.options = null
        //窗口大小应为零
        tcp.windowSize = 0

        ip.totalLength = ip.getIPHeaderLength() + tcp.getTCPHeaderLength()
        return createPacketData(ip, tcp, null)
    }

    /**
     * 从tcpHeader创建tcp报文
     */
    private fun createPacketData(ipHeader: IP4Header, tcpHeader: TCPHeader, data: ByteArray?):
            ByteArray {
        val dataLength = data?.size ?: 0

        val buffer =
            ByteBuffer.allocate(ipHeader.getIPHeaderLength() + tcpHeader.getTCPHeaderLength() + dataLength)
        val ipBuffer = ipHeader.toBytes()
        val tcpBuffer = tcpHeader.toBytes()

        buffer.put(ipBuffer)
        buffer.put(tcpBuffer)

        data?.let { buffer.put(it) }

        val zero = byteArrayOf(0, 0)
        //计算前先将校验和清零
        buffer.position(10)
        buffer.put(zero)

        val ipChecksum = PacketUtil.calculateChecksum(buffer.array(), 0, ipBuffer.size)
        buffer.position(10)
        buffer.put(ipChecksum)

        val tcpStart = ipBuffer.size
        buffer.position(tcpStart + 16)
        buffer.put(zero)

        val tcpChecksum = PacketUtil.calculateTCPHeaderChecksum(
            buffer.array(), tcpStart, tcpBuffer.size + dataLength,
            ipHeader.destinationIP, ipHeader.sourceIP
        )

        //将新的校验和写回阵列
        buffer.position(tcpStart + 16)
        buffer.put(tcpChecksum)
        return buffer.array()
    }

}
