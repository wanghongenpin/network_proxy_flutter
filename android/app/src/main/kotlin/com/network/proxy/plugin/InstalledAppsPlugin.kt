package com.network.proxy.plugin

import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Locale

class InstalledAppsPlugin : AndroidFlutterPlugin() {
    var channel: MethodChannel? = null

    companion object {
        const val CHANNEL = "com.proxy/installedApps"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)

        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val withIcon = call.argument<Boolean>("withIcon") ?: false
                    val packageNamePrefix = call.argument<String>("packageNamePrefix") ?: ""
                    result.success(getInstalledApps(withIcon, packageNamePrefix))
                }

                "getAppInfo" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(getAppInfo(packageName))
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getAppInfo(packageName: String): Map<String, Any?> {
        val packageManager = activity.packageManager
        packageManager.getApplicationInfo(packageName, 0).let { app ->
            return convertAppToMap(packageManager, app, true)
        }
    }

    private fun getInstalledApps(
        withIcon: Boolean,
        packageNamePrefix: String
    ): List<Map<String, Any?>> {
        val packageManager = activity.packageManager
        var installedApps = packageManager.getInstalledApplications(0)
        installedApps =
            installedApps.filter { app ->
                (app.flags and ApplicationInfo.FLAG_SYSTEM) <= 0
                        || (app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                        || packageManager.getLaunchIntentForPackage(app.packageName) != null
            }

        if (packageNamePrefix.isNotEmpty())
            installedApps = installedApps.filter { app ->
                app.packageName.startsWith(
                    packageNamePrefix.lowercase(Locale.ENGLISH)
                )
            }
        return installedApps.map { app -> convertAppToMap(packageManager, app, withIcon) }
    }

    private fun convertAppToMap(
        packageManager: PackageManager,
        app: ApplicationInfo,
        withIcon: Boolean
    ): HashMap<String, Any?> {

        val map = HashMap<String, Any?>()
        map["name"] = packageManager.getApplicationLabel(app)
        map["packageName"] = app.packageName
        map["icon"] =
            if (withIcon) drawableToByteArray(app.loadIcon(packageManager)) else ByteArray(0)
        val packageInfo = packageManager.getPackageInfo(app.packageName, 0)
        map["versionName"] = packageInfo.versionName
        map["versionCode"] = getVersionCode(packageInfo)
        return map
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = drawableToBitmap(drawable)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth,
            drawable.intrinsicHeight,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    @Suppress("DEPRECATION")
    private fun getVersionCode(packageInfo: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) packageInfo.versionCode.toLong()
        else packageInfo.longVersionCode
    }

}