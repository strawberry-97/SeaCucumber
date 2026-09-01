package com.scvpn.vpn_app

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.scvpn.vpn_app.vpn.VpnController
import com.scvpn.vpn_app.vpn.SonicVpnService

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.scvpn.vpn/engine"
        private const val VPN_REQUEST_CODE = 24
    }

    private var pendingPrepareResult: MethodChannel.Result? = null
    private var pendingConnectConfig: String? = null
    private var pendingConnectRules: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        VpnController.channel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepareVpn(result)
                    "connect" -> {
                        val config = call.argument<String>("config") ?: ""
                        @Suppress("UNCHECKED_CAST")
                        val rules = call.argument<Map<String, String>>("rules")
                        connectVpn(config, rules, result)
                    }
                    "disconnect" -> {
                        VpnController.stopVpn(this)
                        result.success(null)
                    }
                    "status" -> result.success(VpnController.status)
                    "readLog" -> result.success(VpnController.readLog())
                    "clearLog" -> {
                        VpnController.clearLog()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 请求 VPN 权限（返回是否已授权；首次会弹出系统授权框）
    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(true)
            return
        }
        pendingPrepareResult = result
        startActivityForResult(intent, VPN_REQUEST_CODE)
    }

    /// 建立连接（内部确保权限已授权）
    private fun connectVpn(config: String, rules: Map<String, String>?, result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            VpnController.startVpn(this, config, rules)
            result.success(null)
            return
        }
        pendingConnectConfig = config
        pendingConnectRules = rules
        startActivityForResult(intent, VPN_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_REQUEST_CODE) return

        if (resultCode == RESULT_OK) {
            pendingPrepareResult?.success(true)
            pendingConnectConfig?.let { config ->
                VpnController.startVpn(this, config, pendingConnectRules)
            }
        } else {
            pendingPrepareResult?.success(false)
            VpnController.updateStatus("permissionDenied")
        }
        pendingPrepareResult = null
        pendingConnectConfig = null
        pendingConnectRules = null
    }

    override fun onDestroy() {
        // 注意：仅断开隧道控制，不强制停止服务（服务可独立存活）
        super.onDestroy()
    }
}
