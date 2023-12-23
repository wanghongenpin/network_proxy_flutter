package com.network.proxy

import android.content.Intent
import android.content.res.Configuration
import android.net.VpnService
import android.os.Bundle
import com.network.proxy.plugin.AppLifecyclePlugin
import com.network.proxy.plugin.PictureInPicturePlugin
import com.network.proxy.plugin.VpnServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine


class MainActivity : FlutterActivity() {
    private val lifecycleChannel: AppLifecyclePlugin = AppLifecyclePlugin()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prepareVpn()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pluginRegister(flutterEngine)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        lifecycleChannel.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        lifecycleChannel.onPictureInPictureModeChanged(isInPictureInPictureMode)
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }

    /**
     * 注册插件
     */
    private fun pluginRegister(flutterEngine: FlutterEngine) {
        flutterEngine.plugins.add(VpnServicePlugin())
        flutterEngine.plugins.add(PictureInPicturePlugin())
        flutterEngine.plugins.add(lifecycleChannel)
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

    override fun onDestroy() {
        activity.startService(ProxyVpnService.stopVpnIntent(activity))
        super.onDestroy()
    }

}
