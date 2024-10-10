package com.network.proxy.vpn.transport.protocol

import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * IPv4报头的数据结构。
 */
data class IP4Header(
    var ipVersion: Byte = 0, //对于IPv4，其值为4（因此命名为IPv4）。 4bit
    private var internetHeaderLength: Byte = 0, //头部长度 4bit
    private var diffTypeOfService: Byte, //差分服务代码点 =>6位
    private var ecn: Byte = 0, //显式拥塞通知（ECN）
    var totalLength: Int = 0, //此IP数据包的总长度 16bit
    var identification: Int = 0, //主要用于唯一标识单个IP数据报的片段组。 16bit
    private var mayFragment: Boolean, // 1bit   用于指示数据报是否可以分段。
    private var lastFragment: Boolean, // 1bit   用于指示数据报是否是片段中的最后一个。
    var fragmentOffset: Short = 0, //13bit，指定特定片段相对于原始未分段的IP数据报的开始的偏移量。
    private var timeToLive: Byte = 0, //用于防止数据报持续存在。8bit
    var protocol: Byte = 0, //定义IP数据报的数据部分中使用的协议。 8bit
    var headerChecksum: Int = 0, //用于对头部进行错误检查的16位字段。 16bit
    var sourceIP: Int = 0, //发送者的IPv4地址。 32bit
    var destinationIP: Int = 0 //接收者的IPv4地址。 32bit
) {
    //用于控制或识别片段的3比特字段。
    //bit 0: 保留；必须为零
    //bit 1: Don't Fragment (DF)
    //bit 2: More Fragments (MF)
    private var flag: Byte = initFlag()

    private fun initFlag(): Byte {
        var initFlag = 0
        if (mayFragment) {
            initFlag = 0x40
        }

        if (lastFragment) {
            initFlag = (initFlag or 0x20)
        }
        return initFlag.toByte()
    }

    fun setMayFragment(mayFragment: Boolean) {
        this.mayFragment = mayFragment
        flag = if (mayFragment) {
            (flag.toInt() or 0x40).toByte()
        } else {
            (flag.toInt() and 0xBF).toByte()
        }
    }

    fun getIPHeaderLength(): Int {
        return internetHeaderLength * 4
    }

    fun copy(): IP4Header {
        return IP4Header(
            ipVersion, internetHeaderLength, diffTypeOfService, ecn, totalLength, identification,
            mayFragment, lastFragment, fragmentOffset, timeToLive, protocol, headerChecksum,
            sourceIP, destinationIP
        )
    }

    fun toBytes(): ByteArray {
        val buffer = ByteBuffer.allocate(getIPHeaderLength())
        buffer.order(ByteOrder.BIG_ENDIAN)
        val versionAndHeaderLength = (ipVersion.toInt() shl 4) + internetHeaderLength
        buffer.put(versionAndHeaderLength.toByte())

        val typeOfService: Byte = (diffTypeOfService.toInt() shl 2 and (ecn
            .toInt() and 0xFF)).toByte()
        buffer.put(typeOfService)

        buffer.putShort(totalLength.toShort())
        buffer.putShort(identification.toShort())

        //组合标志和部分片段偏移
        buffer.put((fragmentOffset.toInt() shr 8 and 0x1F or flag.toInt()).toByte())
        buffer.put(fragmentOffset.toByte())

        buffer.put(timeToLive)
        buffer.put(protocol)
        buffer.putShort(headerChecksum.toShort())
        buffer.putInt(sourceIP)
        buffer.putInt(destinationIP)
        return buffer.array()
    }
}

object IPPacketFactory {
    private const val IP4_HEADER_SIZE = 20
    private const val IP4_VERSION = 0x04

    /**
     * 从给定的ByteBuffer流创建IPv4标头
     */
    fun createIP4Header(buffer: ByteBuffer): IP4Header? {
        if (buffer.remaining() < IP4_HEADER_SIZE) {
            throw IllegalArgumentException("IP header byte array must have at least $IP4_HEADER_SIZE bytes")
        }

        val versionAndHeaderLength: Byte = buffer.get()
        val ipVersion = (versionAndHeaderLength.toInt() shr 4).toByte()
        if (ipVersion.toInt() != IP4_VERSION) {
            Log.e("IPPacketFactory", "Invalid IP version $ipVersion")
            return null
        }

        val internetHeaderLength = (versionAndHeaderLength.toInt() and 0x0F).toByte()

        val typeOfService = buffer.get().toInt()
        val diffTypeOfService: Byte = (typeOfService shr 2).toByte();
        val ecn: Byte = (typeOfService and 0x03).toByte()

        val totalLength: Int = buffer.getShort().toInt()
        val identification: Int = buffer.getShort().toInt()

        val flagsAndFragmentOffset: Short = buffer.getShort()
        val mayFragment = flagsAndFragmentOffset.toInt() and 0x4000 != 0
        val lastFragment = flagsAndFragmentOffset.toInt() and 0x2000 != 0
        val fragmentOffset = (flagsAndFragmentOffset.toInt() and 0x1FFF).toShort()

        val timeToLive: Byte = buffer.get()
        val protocol: Byte = buffer.get()
        val checksum: Int = buffer.getShort().toInt()
        val sourceIp: Int = buffer.getInt()
        val desIp: Int = buffer.getInt()

        if (internetHeaderLength > 5) {
            // drop the IP option
            for (i in 0 until (internetHeaderLength - 5)) {
                buffer.getInt()
            }
        }

        return IP4Header(
            ipVersion, internetHeaderLength, diffTypeOfService, ecn, totalLength, identification,
            mayFragment, lastFragment, fragmentOffset, timeToLive, protocol, checksum,
            sourceIp, desIp
        )
    }
}