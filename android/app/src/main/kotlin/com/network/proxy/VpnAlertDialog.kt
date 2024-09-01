package com.network.proxy

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import kotlin.system.exitProcess

/**
 * @author wanghongen
 */
class VpnAlertDialog : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val dialog: AlertDialog = AlertDialog.Builder(this)
            .setTitle("提示")
            .setMessage("必须添加VPN才能使用")
            .setPositiveButton("确认") { _, _ ->
                exitProcess(0)
            }
            .setCancelable(false)
            .create()
        dialog.show()
    }

}