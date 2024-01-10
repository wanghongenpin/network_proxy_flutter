package com.network.proxy.vpn.socket

import android.util.Log
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.BlockingDeque
import java.util.concurrent.LinkedBlockingDeque
import kotlin.concurrent.Volatile

class ClientPacketWriter(private val clientWriter: FileOutputStream) : Runnable {
    companion object {
        private const val TAG: String = "ClientPacketWriter"
        private const val MAX_PACKET_LEN = 32767
    }

    @Volatile
    private var shutdown = false

    private val packetQueue: BlockingDeque<ByteArray> = LinkedBlockingDeque()

    fun write(data: ByteArray) {
        if (data.size > MAX_PACKET_LEN) throw Error("Packet too large")
        packetQueue.addLast(data)
    }

    fun shutdown() {
        this.shutdown = true
    }

    override fun run() {
        while (!this.shutdown && clientWriter.channel.isOpen) {
            try {
                val data: ByteArray = this.packetQueue.take()
                try {
                    this.clientWriter.write(data)
                } catch (e: IOException) {
                    Log.e(TAG, "Error writing $shutdown data.length bytes to the VPN")
                    e.printStackTrace()
//                    this.packetQueue.addFirst(data) // Put the data back, so it's resent
                    Thread.sleep(10) // Add an arbitrary tiny pause, in case that helps
                }
            } catch (ignored: InterruptedException) {
            }
        }
    }
}
