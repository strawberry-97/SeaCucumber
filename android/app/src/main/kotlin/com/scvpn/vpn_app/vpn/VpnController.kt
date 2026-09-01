package com.scvpn.vpn_app.vpn

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// VPN 控制中心：管理状态、配置与日志（App 与 VpnService 共享）
object VpnController {
    var channel: MethodChannel? = null
    private var appContext: Context? = null

    var status: String = "disconnected"
        private set

    private var pendingConfig: String = ""

    /// 由 MainActivity 初始化
    fun attach(context: Context) {
        appContext = context.applicationContext
    }

    /// 更新状态并通知 Flutter 侧（任意线程安全：MethodChannel 必须在主线程调用）
    fun updateStatus(newStatus: String) {
        status = newStatus
        val ch = channel ?: return
        Handler(Looper.getMainLooper()).post {
            ch.invokeMethod("onStatusChanged", newStatus)
        }
    }

    fun currentConfig(): String = pendingConfig

    /// 启动 VPN 服务（rules: 文件名 → base64，写入 filesDir/working 供内核读取）
    fun startVpn(context: Context, config: String, rules: Map<String, String>? = null) {
        attach(context)
        pendingConfig = config
        writeRuleSets(rules)
        updateStatus("connecting")
        val intent = Intent(context, SonicVpnService::class.java).apply {
            action = SonicVpnService.ACTION_START
            putExtra(SonicVpnService.EXTRA_CONFIG, config)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    /// 把内置规则集写入 filesDir/working（sing-box workingPath）
    private fun writeRuleSets(rules: Map<String, String>?) {
        if (rules == null) return
        val ctx = appContext ?: return
        try {
            val working = File(ctx.filesDir, "working")
            working.mkdirs()
            for ((name, b64) in rules) {
                if (name.contains("..") || name.contains("/")) continue
                val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                File(working, name).writeBytes(bytes)
            }
        } catch (_: Exception) {
        }
    }

    /// 停止 VPN 服务
    fun stopVpn(context: Context) {
        updateStatus("disconnecting")
        val intent = Intent(context, SonicVpnService::class.java).apply {
            action = SonicVpnService.ACTION_STOP
        }
        context.startService(intent)
    }

    // MARK: - 日志

    private fun logFile(): File? =
        appContext?.let { File(it.filesDir, "tunnel.log") }

    fun appendLog(message: String) {
        try {
            val f = logFile() ?: return
            val stamp = java.text.SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US
            ).format(java.util.Date())
            f.appendText("$stamp $message\n")
        } catch (_: Exception) {
        }
    }

    fun readLog(): String =
        try {
            logFile()?.readText() ?: ""
        } catch (_: Exception) {
            ""
        }

    fun clearLog() {
        try {
            logFile()?.delete()
        } catch (_: Exception) {
        }
    }
}
