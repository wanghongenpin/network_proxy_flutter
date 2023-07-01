package com.network.proxy

import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor

class ProxyVpnService : VpnService() {
    private lateinit var vpnInterface: ParcelFileDescriptor

    companion object {
        const val ProxyHost = "ProxyHost"
        const val ProxyPort = "ProxyPort"

        /**
         * 动作：断开连接
         */
        const val ACTION_DISCONNECT = "DISCONNECT"
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnect()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return if (intent?.action == ACTION_DISCONNECT) {
            disconnect()
            START_NOT_STICKY
        } else {
            connect(intent?.getStringExtra(ProxyHost)!!, intent.getIntExtra(ProxyPort, 0))
            START_STICKY
        }
    }

    private fun disconnect() {
        vpnInterface.close()
    }

    private fun connect(proxyHost: String, proxyPort: Int) {
        vpnInterface = createVpnInterface(proxyHost, proxyPort)
    }

    private fun createVpnInterface(proxyHost: String, proxyPort: Int): ParcelFileDescriptor {
        return Builder()
            .addAddress("10.0.0.2", 32)
            .addRoute("0.0.0.0", 0)
            .setSession(baseContext.applicationInfo.name)
            .also {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    it.addDisallowedApplication(baseContext.packageName)
                        .setHttpProxy(ProxyInfo.buildDirectProxy(proxyHost, proxyPort))
                }
            }
            .establish() ?: throw IllegalStateException("无法初始化vpnInterface")
    }


}
