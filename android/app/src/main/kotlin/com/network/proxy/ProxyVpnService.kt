package com.network.proxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.network.proxy.vpn.socket.ProtectSocket
import com.network.proxy.vpn.socket.ProtectSocketHolder

/**
 * VPN服务
 * @author wanghongen
 */
class ProxyVpnService : VpnService(), ProtectSocket {
    private var vpnInterface: ParcelFileDescriptor? = null

    companion object {
        const val MAX_PACKET_LEN = 1500

        const val ProxyHost = "ProxyHost"
        const val ProxyPort = "ProxyPort"
        const val AllowApps = "AllowApps" //允许的名单

        /**
         * 动作：断开连接
         */
        const val ACTION_DISCONNECT = "DISCONNECT"

        /**
         * 通知配置
         */
        private const val NOTIFICATION_ID = 9527
        const val VPN_NOTIFICATION_CHANNEL_ID = "vpn-notifications"

        var isRunning = false

        var host: String? = null
        var port: Int = 0
        var allowApps: ArrayList<String>? = null

        fun stopVpnIntent(context: Context): Intent {
            return Intent(context, ProxyVpnService::class.java).also {
                it.action = ACTION_DISCONNECT
            }
        }

        fun startVpnIntent(
            context: Context,
            proxyHost: String? = host,
            proxyPort: Int? = port,
            allowApps: ArrayList<String>? = this.allowApps
        ): Intent {
            return Intent(context, ProxyVpnService::class.java).also {
                it.putExtra(ProxyHost, proxyHost)
                it.putExtra(ProxyPort, proxyPort)
                it.putStringArrayListExtra(AllowApps, allowApps)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnect()
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        return if (intent.action == ACTION_DISCONNECT) {
            disconnect()
            START_NOT_STICKY
        } else {
            connect(
                intent.getStringExtra(ProxyHost) ?: host!!,
                intent.getIntExtra(ProxyPort, port),
                intent.getStringArrayListExtra(AllowApps) ?: allowApps
            )
            START_STICKY
        }
    }

    private fun disconnect() {
        vpnInterface?.close()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        vpnInterface = null
        isRunning = false
    }

    private fun connect(proxyHost: String, proxyPort: Int, allowPackages: ArrayList<String>?) {
        Log.i("ProxyVpnService", "startVpn $host:$port $allowApps")

        host = proxyHost
        port = proxyPort
        allowApps = allowPackages
        vpnInterface = createVpnInterface(proxyHost, proxyPort, allowPackages)
        if (vpnInterface == null) {
            val alertDialog = Intent(applicationContext, VpnAlertDialog::class.java)
                .setAction("com.network.proxy.ProxyVpnService")
            alertDialog.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(alertDialog)
            return
        }

        ProtectSocketHolder.setProtectSocket(this)
        showServiceNotification()
        isRunning = true
    }

    private fun showServiceNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val notificationChannel = NotificationChannel(
                VPN_NOTIFICATION_CHANNEL_ID,
                "VPN Status",
                NotificationManager.IMPORTANCE_LOW
            )
            notificationManager.createNotificationChannel(notificationChannel)
        }

        val pendingActivityIntent: PendingIntent =
            Intent(this, MainActivity::class.java).let { notificationIntent ->
                PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
            }

        val notification: Notification =
            NotificationCompat.Builder(this, VPN_NOTIFICATION_CHANNEL_ID)
                .setContentIntent(pendingActivityIntent)
                .setContentTitle(getString(R.string.vpn_active_notification_title))
                .setContentText(getString(R.string.vpn_active_notification_content))
                .setOngoing(true)
                .build()

        startForeground(NOTIFICATION_ID, notification)
    }


    private fun createVpnInterface(proxyHost: String, proxyPort: Int, allowPackages: List<String>?):
            ParcelFileDescriptor? {
        val build = Builder()
            .setMtu(MAX_PACKET_LEN)
            .addAddress("10.0.0.2", 32)
            .addRoute("0.0.0.0", 0)
            .setSession(baseContext.applicationInfo.name)
            .setBlocking(true)

        val packages = allowPackages?.filter { it != baseContext.packageName }
        if (packages?.isNotEmpty() == true) {
            packages.forEach {
                build.addAllowedApplication(it)
            }
        } else {
            build.addDisallowedApplication(baseContext.packageName)
        }

        build.setConfigureIntent(
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE
            )
        )

        return build.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                setHttpProxy(ProxyInfo.buildDirectProxy(proxyHost, proxyPort))
            }
        }.establish()
    }


}
