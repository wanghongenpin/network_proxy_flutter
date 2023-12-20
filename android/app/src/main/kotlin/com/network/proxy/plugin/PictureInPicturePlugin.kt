package com.network.proxy.plugin

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import com.network.proxy.ProxyVpnService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * 画中画插件
 */
class PictureInPicturePlugin : AndroidFlutterPlugin() {
    private var registerBroadcast = false

    ///广播事件接受者
    private val vpnBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d("com.network.proxy", "onReceive ${intent?.action}")

            if (context == null || intent?.action != VPN_ACTION) {
                return
            }
            val isRunning = ProxyVpnService.isRunning

            if (isRunning) {
                activity.startService(ProxyVpnService.stopVpnIntent(activity))
            } else {
                activity.startService(ProxyVpnService.startVpnIntent(activity))
            }

            //设置画中画参数
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                updatePictureInPictureParams(!isRunning)
            }
        }
    }

    companion object {
        const val CHANNEL = "com.proxy/pictureInPicture"
        const val VPN_ACTION = "VPN_ACTION"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPictureInPictureMode" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val param = updatePictureInPictureParams(ProxyVpnService.isRunning)

                        if (!registerBroadcast) {
                            registerBroadcast = true
                            ContextCompat.registerReceiver(
                                activity,
                                vpnBroadcastReceiver,
                                IntentFilter(VPN_ACTION),
                                ContextCompat.RECEIVER_NOT_EXPORTED
                            )
                        }

                        result.success(activity.enterPictureInPictureMode(param))
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // 画中画参数
    private fun updatePictureInPictureParams(isRunning: Boolean): PictureInPictureParams {

        val params = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(8, 19))
                .apply {
                    setActions(listOf(action(isRunning)))   //vpn服务运行中，显示停止按钮
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        setSeamlessResizeEnabled(false)
                    }
                }
                .build()
        } else {
            throw RuntimeException("getPictureInPictureParams error")
        }
        activity.setPictureInPictureParams(params)
        return params
    }

    //停止vpn服务 RemoteAction
    private fun action(isRunning: Boolean): RemoteAction {
        val pIntent: PendingIntent = PendingIntent.getBroadcast(
            activity,
            if (isRunning) 0 else 1,
            Intent(VPN_ACTION),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        )

        //vpn服务运行中，显示停止按钮
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return RemoteAction(
                Icon.createWithResource(
                    this@PictureInPicturePlugin.activity,
                    if (isRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                ), "Proxy", "Proxy", pIntent
            )
        } else {
            throw RuntimeException("action error")
        }
    }
}