package com.network.proxy.plugin

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process.INVALID_UID
import android.system.OsConstants.IPPROTO_TCP
import android.util.Log
import com.network.proxy.ProxyVpnService
import com.network.proxy.vpn.ConnectionManager
import com.network.proxy.vpn.TAG
import com.network.proxy.vpn.util.PacketUtil
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.log

/**
 * 进程信息管理器
 *
 * @author wanghongen
 */
class ProcessInfoPlugin private constructor() : AndroidFlutterPlugin() {
    companion object {
        const val CHANNEL = "com.proxy/processInfo"

        val instance = ProcessInfoPlugin()
    }

    private val cache = ConcurrentHashMap<Int, AppInfo>()
    lateinit var context: Context
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getProcessByPort" -> {
                    val host = call.argument<String>("host")
                    val port = call.argument<Int>("port")
                    val localAddress = InetSocketAddress(host!!, port!!)

                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun getProcessInfo(
        localAddress: InetSocketAddress, remoteAddress: InetSocketAddress
    ): AppInfo? {
        val connectivityManager: ConnectivityManager =
            activity.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        Log.i(TAG, "getProcessInfo: $localAddress $remoteAddress")

        val uid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivityManager.getConnectionOwnerUid(IPPROTO_TCP, localAddress, remoteAddress)
        } else {
            val method = ConnectivityManager::class.java.getMethod(
                "getConnectionOwnerUid",
                Int::class.javaPrimitiveType,
                InetSocketAddress::class.java,
                InetSocketAddress::class.java
            )
            method.invoke(
                connectivityManager, IPPROTO_TCP, localAddress, remoteAddress
            ) as Int
        }

        if (uid != INVALID_UID) {
            return getProcessInfo(uid)
        }
        return null
    }

    private fun getProcessInfo(uid: Int): AppInfo? {
        val packageManager = activity.packageManager

        var appInfo = cache[uid]
        if (appInfo != null) return appInfo

        val pkgNames = packageManager.getPackagesForUid(uid) ?: return null
        for (pkgName in pkgNames) {
            val applicationInfo = packageManager.getApplicationInfo(pkgName, 0)
            appInfo = AppInfo.create(packageManager, applicationInfo)
            cache[uid] = appInfo
            return appInfo
        }
        return null
    }

}