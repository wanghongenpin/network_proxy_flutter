package com.network.proxy.plugin

import android.util.Log
import com.network.proxy.ProxyVpnService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class VpnServicePlugin : AndroidFlutterPlugin() {
    companion object {
        const val CHANNEL = "com.proxy/proxyVpn"
        const val REQUEST_CODE: Int = 24
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isRunning" -> {
                    result.success(ProxyVpnService.isRunning)
                }
                "startVpn" -> {
                    val host = call.argument<String>("proxyHost")
                    val port = call.argument<Int>("proxyPort")
                    val allowApps = call.argument<ArrayList<String>>("allowApps")
                    startVpn(host!!, port!!, allowApps)
                }

                "stopVpn" -> {
                    stopVpn()
                }

                "restartVpn" -> {
                    val host = call.argument<String>("proxyHost")
                    val port = call.argument<Int>("proxyPort")
                    val allowApps = call.argument<ArrayList<String>>("allowApps")
                    stopVpn()
                    startVpn(host!!, port!!, allowApps)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * 启动vpn服务
     */
    private fun startVpn(host: String, port: Int, allowApps: ArrayList<String>?) {
        Log.i("com.network.proxy", "startVpn $host:$port $allowApps")
        val intent = ProxyVpnService.startVpnIntent(activity, host, port, allowApps)
        activity.startService(intent)
    }

    /**
     * 停止vpn服务
     */
    private fun stopVpn() {
        activity.startService(ProxyVpnService.stopVpnIntent(activity))
    }
}