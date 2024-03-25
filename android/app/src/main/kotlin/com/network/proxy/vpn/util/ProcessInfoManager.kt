package com.network.proxy.vpn.util

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.system.OsConstants
import com.google.common.cache.CacheBuilder
import com.network.proxy.plugin.AppInfo
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

    private val localPortUidMap =
        CacheBuilder.newBuilder().maximumSize(10_000).expireAfterAccess(120, TimeUnit.SECONDS)
            .build<Int, Int>()

    private val appInfoCache =
        CacheBuilder.newBuilder().maximumSize(10_000).expireAfterAccess(300, TimeUnit.SECONDS)
            .build<Int, AppInfo>()

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
            localPortUidMap.put(localAddress.port, uid)
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

    fun getProcessInfoByPort(localPort: Int): AppInfo? {
        val uid = localPortUidMap.getIfPresent(localPort)
        if (uid != null) {
            return getProcessInfo(uid)
        }
        return null
    }

    private fun getProcessInfo(uid: Int): AppInfo? {
        var appInfo = appInfoCache.getIfPresent(uid)
        if (appInfo != null) return appInfo

        val packageManager = activity?.packageManager
        val pkgNames = packageManager?.getPackagesForUid(uid) ?: return null
        for (pkgName in pkgNames) {
            val applicationInfo = packageManager.getApplicationInfo(pkgName, 0)
            appInfo = AppInfo.create(packageManager, applicationInfo)
            appInfoCache.put(uid, appInfo)
            return appInfo
        }
        return null
    }

}