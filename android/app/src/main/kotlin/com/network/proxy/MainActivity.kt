package com.network.proxy

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import com.network.proxy.plugin.VpnServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine


class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prepareVpn()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pluginRegister(flutterEngine)
    }

    /**
     * 注册插件
     */
    private fun pluginRegister(flutterEngine: FlutterEngine) {
        flutterEngine.plugins.add(VpnServicePlugin())
    }

    /**
     * 准备vpn<br>
     * 设备可能弹出连接vpn提示
     */
    private fun prepareVpn() {
        val intent = VpnService.prepare(this@MainActivity)
        if (intent != null) {
            startActivityForResult(intent, VpnServicePlugin.REQUEST_CODE)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
    }

}
