package com.network.proxy

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {
    companion object {
        const val VPN_CHANNEL = "com.proxy/proxyVpn"
        const val VPN_REQUEST_CODE: Int = 24
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prepareVpn()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vpnMethodChannel(flutterEngine)
    }

    /**
     * vpn方法通道
     */
    private fun vpnMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVpn" -> {
                        val host = call.argument<String>("proxyHost")
                        val port = call.argument<Int>("proxyPort")
                        startVpn(host!!, port!!)
                    }

                    "stopVpn" -> {
                        stopVpn()
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    /**
     * 准备vpn<br>
     * 设备可能弹出连接vpn提示
     */
    private fun prepareVpn() {
        val intent = VpnService.prepare(this@MainActivity)
        if (intent != null) {
            startActivityForResult(intent, VPN_REQUEST_CODE)
        }
    }

    /**
     * 启动vpn服务
     */
    private fun startVpn(host: String, port: Int) {
        Log.i("com.network.proxy", "startVpn")
        val intent = Intent(this, ProxyVpnService::class.java)
        intent.putExtra(ProxyVpnService.ProxyHost, host)
        intent.putExtra(ProxyVpnService.ProxyPort, port)
        startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
    }

    /**
     * 停止vpn服务
     */
    private fun stopVpn() {
        startService(Intent(this@MainActivity, ProxyVpnService::class.java).also {
            it.action = ProxyVpnService.ACTION_DISCONNECT
        })
    }

}
