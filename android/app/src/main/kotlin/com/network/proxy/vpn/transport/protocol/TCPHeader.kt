package com.network.proxy.vpn.transport.protocol

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * TCP报头的数据结构。
 */
class TCPHeader(
    private var sourcePort: Int = 0, //源端口号 16bit
    private var destinationPort: Int = 0, //目的端口号 16bit
    var sequenceNumber: Long = 0, //序列号 32bit
    var ackNumber: Long = 0, //确认号 32bit
    var dataOffset: Int = 0, //数据偏移4bit
    var isNS: Boolean = false, //ECN-nonce concealment protection (experimental: see RFC 3540)
    var flags: Int = 0, //标志位 9bit
    var windowSize: Int = 0, //窗口大小 16bit
    var checksum: Int = 0, //校验和 16bit
    private var urgentPointer: Int = 0, //紧急指针 16bit
    var options: ByteArray? = null //选项
) : TransportHeader {

    //options
    var maxSegmentSize: Short = 0
    private var windowScale: Byte = 0
    private var isSelectiveAckPermitted = false
    var timeStampSender = 0
    var timeStampReplyTo = 0

    companion object {
        private const val END_OF_OPTIONS_LIST: Byte = 0
        private const val NO_OPERATION: Byte = 1
        private const val MAX_SEGMENT_SIZE: Byte = 2
        private const val WINDOW_SCALE: Byte = 3
        private const val SELECTIVE_ACK_PERMITTED: Byte = 4
        private const val TIME_STAMP: Byte = 8
    }

    fun isSYN(): Boolean {
        return flags and 0x02 != 0
    }

    fun isFIN(): Boolean {
        return flags and 0x01 != 0
    }

    fun isRST(): Boolean {
        return flags and 0x04 != 0
    }

    fun isPSH(): Boolean {
        return flags and 0x08 != 0
    }

    fun isACK(): Boolean {
        return flags and 0x10 != 0
    }

    fun isURG(): Boolean {
        return flags and 0x20 != 0
    }

    fun isECE(): Boolean {
        return flags and 0x40 != 0
    }

    fun isCWR(): Boolean {
        return flags and 0x80 != 0
    }

    fun setIsRST(isRST: Boolean) {
        flags = if (isRST) {
            (flags or 0x04)
        } else {
            (flags and 0xFB)
        }
    }

    fun setIsSYN(isSYN: Boolean) {
        flags = if (isSYN) {
            (flags or 0x02)
        } else {
            (flags and 0xFD)
        }
    }

    fun setIsFIN(isFIN: Boolean) {
        flags = if (isFIN) {
            (flags or 0x01)
        } else {
            (flags and 0xFE)
        }
    }

    fun setIsPSH(isPSH: Boolean) {
        flags = if (isPSH) {
            (flags or 0x08)
        } else {
            (flags and 0xF7)
        }
    }

    fun setIsACK(isACK: Boolean) {
        flags = if (isACK) {
            (flags or 0x10)
        } else {
            (flags and 0xEF)
        }
    }

    fun getTCPHeaderLength(): Int {
        return dataOffset * 4
    }

    fun toBytes(): ByteArray {
        val tcpHeaderLength = getTCPHeaderLength()
        val tcpHeader = ByteArray(tcpHeaderLength)
        val byteBuffer = ByteBuffer.wrap(tcpHeader)
        byteBuffer.order(ByteOrder.BIG_ENDIAN)

        byteBuffer.putShort(sourcePort.toShort())
        byteBuffer.putShort(destinationPort.toShort())

        byteBuffer.putInt(sequenceNumber.toInt())
        byteBuffer.putInt(ackNumber.toInt())

        //is ns and data offset
        byteBuffer.put(((dataOffset shl 4) and 0xF0 or (if (isNS) 0x1 else 0x0)).toByte())
        byteBuffer.put(flags.toByte())
        byteBuffer.putShort(windowSize.toShort())
        byteBuffer.putShort(checksum.toShort())
        byteBuffer.putShort(urgentPointer.toShort())
//        encodeTcpOptions()?.let {
//            byteBuffer.put(it)
//        }

        return tcpHeader
    }

    fun copy(): TCPHeader {
        return TCPHeader(
            sourcePort, destinationPort, sequenceNumber, ackNumber,
            dataOffset, isNS, flags, windowSize, checksum, urgentPointer,
            options
        )
    }

    private fun handleTcpOptions() {
        if (options == null) {
            return
        }

        var index = 0
        val packet = ByteBuffer.wrap(options!!)
        val optionsSize = options!!.size

        while (index < optionsSize) {
            val optionKind = packet.get()
            index++
            if (optionKind == END_OF_OPTIONS_LIST || optionKind == NO_OPERATION) {
                continue
            }
            val size = packet.get()
            index++
            when (optionKind) {
                MAX_SEGMENT_SIZE -> {
                    maxSegmentSize = packet.getShort()
                    index += 2
                }

                WINDOW_SCALE -> {
                    windowScale = packet.get()
                    index++
                }

                SELECTIVE_ACK_PERMITTED -> isSelectiveAckPermitted = true
                TIME_STAMP -> {
                    timeStampSender = packet.getInt()
                    timeStampReplyTo = packet.getInt()
                    index += 8
                }

                else -> {
                    skipRemainingOptions(packet, size.toInt())
                    index = index + size - 2
                }
            }
        }
    }

    private fun skipRemainingOptions(packet: ByteBuffer, size: Int) {
        for (i in 2 until size) {
            packet.get()
        }
    }

    override fun getSourcePort(): Int {
        return sourcePort
    }

    override fun getDestinationPort(): Int {
        return destinationPort
    }

    fun setSourcePort(sourcePort: Int) {
        this.sourcePort = sourcePort
    }

    fun setDestinationPort(destinationPort: Int) {
        this.destinationPort = destinationPort
    }
}