package com.network.proxy.plugin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class AppLifecyclePlugin : AndroidFlutterPlugin() {
    var channel: MethodChannel? = null

    companion object {
        const val CHANNEL = "com.proxy/appLifecycle"

    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    }

    fun onUserLeaveHint() {
        channel?.invokeMethod("onUserLeaveHint", null)
    }

    fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        channel?.invokeMethod("onPictureInPictureModeChanged", isInPictureInPictureMode)
    }

}