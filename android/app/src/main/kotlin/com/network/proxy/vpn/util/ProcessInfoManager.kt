package com.network.proxy.vpn.util

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.system.OsConstants
import com.google.common.cache.CacheBuilder
import com.network.proxy.plugin.ProcessInfo
import com.network.proxy.vpn.Connection
import java.net.InetSocketAddress
import java.nio.channels.SocketChannel
import java.util.concurrent.TimeUnit

/**
 * 进程信息管理器，用于获取进程信息
 * @author wanghongen
 */
class ProcessInfoManager private constructor() {
    companion object {
        @Suppress("all")
        val instance = ProcessInfoManager()
    }

    class NetworkInfo(val uid: Int, val remoteHost: String, val remotePort: Int)

    private val localPortMap =
        CacheBuilder.newBuilder().maximumSize(10_000).expireAfterAccess(60, TimeUnit.SECONDS)
            .build<Int, NetworkInfo>()

    private val appInfoCache =
        CacheBuilder.newBuilder().maximumSize(10_000).expireAfterAccess(300, TimeUnit.SECONDS)
            .build<Int, ProcessInfo>()

    var activity: Context? = null

    fun setConnectionOwnerUid(connection: Connection) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }

        val sourceAddress =
            InetSocketAddress(PacketUtil.intToIPAddress(connection.sourceIp), connection.sourcePort)
        val destinationAddress = InetSocketAddress(
            PacketUtil.intToIPAddress(connection.destinationIp), connection.destinationPort
        )

        val uid = getProcessInfo(sourceAddress, destinationAddress)
        val channel = connection.channel
        if (uid != null && channel is SocketChannel) {
            val localAddress = channel.localAddress as InetSocketAddress
            val networkInfo =
                NetworkInfo(uid, destinationAddress.hostString, destinationAddress.port)
            localPortMap.put(localAddress.port, networkInfo)
        }
    }

    fun removeConnection(connection: Connection) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }

        val channel = connection.channel
        if (channel is SocketChannel) {
            val localAddress = channel.localAddress as InetSocketAddress
            localPortMap.invalidate(localAddress.port)
        }
    }


    private fun getProcessInfo(
        localAddress: InetSocketAddress, remoteAddress: InetSocketAddress
    ): Int? {
//        Log.d(TAG, "getProcessInfo: $localAddress $remoteAddress")

        if (activity == null) {
            return null
        }
        val connectivityManager: ConnectivityManager =
            activity!!.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val uid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivityManager.getConnectionOwnerUid(
                OsConstants.IPPROTO_TCP, localAddress, remoteAddress
            )
        } else {
            val method = ConnectivityManager::class.java.getMethod(
                "getConnectionOwnerUid",
                Int::class.javaPrimitiveType,
                InetSocketAddress::class.java,
                InetSocketAddress::class.java
            )
            method.invoke(
                connectivityManager, OsConstants.IPPROTO_TCP, localAddress, remoteAddress
            ) as Int
        }

        if (uid != Process.INVALID_UID) {
            return uid
        }
        return null
    }

    fun getProcessInfoByPort(localPort: Int): ProcessInfo? {
        val networkInfo = localPortMap.getIfPresent(localPort)
        if (networkInfo != null) {
            val processInfo = getProcessInfo(networkInfo.uid)

            return processInfo?.apply {
                put("remoteHost", networkInfo.remoteHost)
                put("remotePort", networkInfo.remotePort)
            }
        }
        return null
    }

    private fun getProcessInfo(uid: Int): ProcessInfo? {
        var appInfo = appInfoCache.getIfPresent(uid)
        if (appInfo != null) return appInfo

        val packageManager = activity?.packageManager
        val pkgNames = packageManager?.getPackagesForUid(uid) ?: return null
        for (pkgName in pkgNames) {
            val applicationInfo = packageManager.getApplicationInfo(pkgName, 0)
            appInfo = ProcessInfo.create(packageManager, applicationInfo)
            appInfoCache.put(uid, appInfo)
            return appInfo
        }
        return null
    }

}