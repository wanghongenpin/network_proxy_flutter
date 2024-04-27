package com.network.proxy.vpn

import android.util.Log
import com.network.proxy.vpn.socket.CloseableConnection
import com.network.proxy.vpn.transport.protocol.IP4Header
import com.network.proxy.vpn.transport.protocol.TCPHeader
import com.network.proxy.vpn.transport.protocol.UDPHeader
import com.network.proxy.vpn.util.PacketUtil
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.channels.SelectionKey
import java.nio.channels.spi.AbstractSelectableChannel
import kotlin.concurrent.Volatile

class Connection(
    val protocol: Protocol,
    val sourceIp: Int, val sourcePort: Int,
    val destinationIp: Int, val destinationPort: Int,
    private val connectionCloser: CloseableConnection
) {

    var channel: AbstractSelectableChannel? = null
    var selectionKey: SelectionKey? = null

    //接收用于存储来自远程主机的数据的缓冲器
    private val receivingStream: ByteArrayOutputStream = ByteArrayOutputStream()

    //发送缓冲区，用于存储要从vpn客户端发送到目标主机的数据
    private val sendingStream: ByteArrayOutputStream = ByteArrayOutputStream()

    var hasReceivedLastSegment = false

    /**
     * 是否初始化链接 针对代理判断协议延迟初始化
     */
    var isInitConnect = false

    //指示三向握手是否已完成
    var isConnected = false

    //从客户端接收的最后一个数据包
    var lastIpHeader: IP4Header? = null
    var lastTcpHeader: TCPHeader? = null
    var lastUdpHeader: UDPHeader? = null

    var timestampSender = 0
    var timestampReplyTo = 0

    //从客户端接收的序列
    var recSequence: Long = 0

    //在tcp选项内的SYN期间由客户端发送
    var maxSegmentSize = 0

    //跟踪我们发送给客户端的ack，并等待客户端返回ack
    var sendUnAck: Long = 0

    //发送到客户端的下一个ack
    var sendNext: Long = 0

    //true when connection is about to be close
    var isClosingConnection = false

    //指示客户端的数据已准备好发送到目标
    @Volatile
    var isDataForSendingReady = false

    //closing session and aborting connection, will be done by background task
    @Volatile
    var isAbortingConnection = false

    //indicate that vpn client has sent FIN flag and it has been acked
    var isAckedToFin = false

    companion object {
        fun getConnectionKey(
            protocol: Protocol, destIp: Int, destPort: Int, sourceIp: Int, sourcePort: Int
        ): String {
            return protocol.name + "|" + PacketUtil.intToIPAddress(sourceIp) + ":" + sourcePort +
                    "->" + PacketUtil.intToIPAddress(destIp) + ":" + destPort
        }
    }

//    fun getConnectionKey(): String {
//        return getConnectionKey(protocol, destinationIp, destinationIp, sourceIp, sourcePort)
//    }

    fun closeConnection() {
        connectionCloser.closeConnection(this)
    }

    /**
     * 设置要发送到目标服务器的数据
     */
    @Synchronized
    fun setSendingData(data: ByteBuffer): Int {
        val remaining = data.remaining()
        sendingStream.write(data.array(), data.position(), data.remaining())
        return remaining
    }

    @Synchronized
    fun addReceivedData(data: ByteArray?) {
        try {
            receivingStream.write(data)
        } catch (e: IOException) {
            Log.e(TAG, e.toString())
        }
    }

    /**
     * 获取缓冲区中接收到的所有数据并清空它。
     */
    @Synchronized
    fun getReceivedData(maxSize: Int): ByteArray? {
        var data = receivingStream.toByteArray()
        receivingStream.reset()
        if (data.size > maxSize) {
            val small = ByteArray(maxSize)
            System.arraycopy(data, 0, small, 0, maxSize)
            val len = data.size - maxSize
            receivingStream.write(data, maxSize, len)
            data = small
        }
        return data
    }

    /**
     * buffer has more data for vpn client
     */
    fun hasReceivedData(): Boolean {
        return receivingStream.size() > 0
    }

    fun hasDataToSend(): Boolean {
        return sendingStream.size() > 0
    }

    /**
     * 出列数据以发送到服务器
     */
    @Synchronized
    fun getSendingData(): ByteArray? {
        val data = sendingStream.toByteArray()
        sendingStream.reset()
        return data
    }

    fun cancelKey() {
        selectionKey?.let {
            synchronized(it) {
                if (!it.isValid) return
                it.cancel()
            }
        }

    }

    fun subscribeKey(op: Int) {
        selectionKey?.let {
            synchronized(it) {
                if (!it.isValid) return
                it.interestOps(it.interestOps() or op)
            }
        }
    }

    fun unsubscribeKey(op: Int) {
        selectionKey?.let {
            synchronized(it) {
                if (!it.isValid) return
                it.interestOps(it.interestOps() and op.inv())
            }
        }
    }

    override fun toString(): String {
       return "Connection{" +
                    "protocol=" + protocol +
                    ", sourceIp=" + PacketUtil.intToIPAddress(sourceIp) +
                    ", sourcePort=" + sourcePort +
                    ", destinationIp=" + PacketUtil.intToIPAddress(destinationIp) +
                    ", destinationPort=" + destinationPort +
                    '}'
    }

}