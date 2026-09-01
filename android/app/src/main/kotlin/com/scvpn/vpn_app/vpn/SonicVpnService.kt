package com.scvpn.vpn_app.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.IpPrefix
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import androidx.core.app.NotificationCompat
import com.scvpn.vpn_app.MainActivity
import com.scvpn.vpn_app.R
import io.nekohasekai.libbox.*
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.NetworkInterface as JavaNetworkInterface
import java.util.concurrent.Executors

/**
 * sing-box 内核 VPN 服务（Android VpnService）
 *
 * 依赖 `libbox.aar`（sing-box Go 移动库，Java 包 io.nekohasekai.libbox）。
 * 构建方法见项目根目录 scripts/build_libbox_android.sh。
 *
 * 注意：Java 绑定为 throws 风格（Go 返回 error 的函数在 Java 侧 `throws Exception`），
 * 且类名不带 Libbox 前缀（SetupOptions / CommandServer / TunOptions 等）。
 */
class SonicVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.scvpn.vpn_app.vpn.START"
        const val ACTION_STOP = "com.scvpn.vpn_app.vpn.STOP"
        const val EXTRA_CONFIG = "config"
        private const val CHANNEL_ID = "vpn_status"
        private const val NOTIFICATION_ID = 1
    }

    private var commandServer: CommandServer? = null
    private lateinit var platformInterface: AndroidPlatformInterface
    private var vpnFd: Int = -1
    private val executor = Executors.newSingleThreadExecutor()

    override fun onCreate() {
        super.onCreate()
        VpnController.attach(this)
        platformInterface = AndroidPlatformInterface(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn()
                return START_NOT_STICKY
            }
            else -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG) ?: ""
                startVpn(config)
                return START_STICKY
            }
        }
    }

    // MARK: - 启动 / 停止

    private fun startVpn(config: String) {
        startForeground()
        executor.execute {
            try {
                VpnController.appendLog("startVpn begin; config length = ${config.length}")
                if (config.isEmpty()) {
                    throw Exception("配置为空，请先导入订阅并选择节点")
                }

                val basePath = filesDir.absolutePath
                val workingPath = "$basePath/working"
                val tempPath = "$basePath/temp"
                java.io.File(workingPath).mkdirs()
                java.io.File(tempPath).mkdirs()

                val options = SetupOptions()
                options.basePath = basePath
                options.workingPath = workingPath
                options.tempPath = tempPath
                options.fixAndroidStack = true
                options.logMaxLines = 2000L
                options.debug = false

                Libbox.setup(options)
                VpnController.appendLog("LibboxSetup ok")

                val server = Libbox.newCommandServer(platformInterface, platformInterface)
                server.start()
                commandServer = server
                VpnController.appendLog("command server started")

                server.startOrReloadService(config, OverrideOptions())
                VpnController.appendLog("startOrReloadService ok")

                VpnController.updateStatus("connected")
            } catch (e: Exception) {
                VpnController.appendLog("startVpn FAILED: ${e.message}")
                VpnController.updateStatus("error")
                stopVpn()
            }
        }
    }

    private fun stopVpn() {
        executor.execute {
            try {
                commandServer?.closeService()
                platformInterface.reset()
            } catch (_: Exception) {
            }
            try {
                Thread.sleep(100)
                commandServer?.close()
            } catch (_: Exception) {
            }
            commandServer = null
            closeVpnFd()
            VpnController.updateStatus("disconnected")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun closeVpnFd() {
        if (vpnFd != -1) {
            try {
                ParcelFileDescriptor.adoptFd(vpnFd).close()
            } catch (_: Exception) {
            }
            vpnFd = -1
        }
    }

    // MARK: - 前台通知

    private fun startForeground() {
        createChannel()
        val intent = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SC VPN")
            .setContentText("VPN 已连接")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "VPN 状态", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.execute {
            try {
                commandServer?.closeService()
                commandServer?.close()
            } catch (_: Exception) {
            }
        }
        executor.shutdown()
    }

    override fun onRevoke() {
        // VPN 被系统撤销（用户取消授权 / 系统强制停止）时清理资源，
        // 避免 netd 残留导致应用后续断网。
        executor.execute {
            try {
                commandServer?.closeService()
                commandServer?.close()
            } catch (_: Exception) {
            }
            commandServer = null
            closeVpnFd()
            VpnController.updateStatus("disconnected")
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // MARK: - sing-box 平台接口（桥接）

    inner class AndroidPlatformInterface(private val service: SonicVpnService) :
        PlatformInterface, CommandServerHandler {

        private var vpnBuilder: Builder? = null
        private var interfaceMonitorCallback: ConnectivityManager.NetworkCallback? = null
        private var interfaceMonitorListener: InterfaceUpdateListener? = null

        fun reset() {
            vpnBuilder = null
            val cb = interfaceMonitorCallback
            if (cb != null) {
                try {
                    service.getSystemService(ConnectivityManager::class.java)
                        .unregisterNetworkCallback(cb)
                } catch (_: Exception) {
                }
            }
            interfaceMonitorCallback = null
            interfaceMonitorListener = null
        }

        // ---------- TUN ----------

        override fun openTun(options: TunOptions?): Int {
            if (options == null) throw Exception("nil options")
            val builder = Builder()
            vpnBuilder = builder

            builder.setSession("SC VPN")
            builder.setMtu(options.getMTU())

            // 地址（IPv4 / IPv6）
            var it = options.getInet4Address()
            while (it?.hasNext() == true) {
                val p = it.next() ?: continue
                builder.addAddress(p.address(), p.prefix())
            }
            var it6 = options.getInet6Address()
            while (it6?.hasNext() == true) {
                val p = it6.next() ?: continue
                builder.addAddress(p.address(), p.prefix())
            }

            // DNS（sing-box 返回用于 DNS 劫持的地址）
            val dns = options.getDNSServerAddress()
            if (dns != null && dns.value.isNotEmpty()) {
                builder.addDnsServer(dns.value)
            }

            // IPv4 路由
            var routeIt = options.getInet4RouteAddress()
            if (routeIt != null && routeIt.hasNext()) {
                while (routeIt.hasNext()) {
                    val p = routeIt.next() ?: continue
                    builder.addRoute(p.address(), p.prefix())
                }
            } else {
                builder.addRoute("0.0.0.0", 0)
            }
            var exclIt = options.getInet4RouteExcludeAddress()
            while (exclIt?.hasNext() == true) {
                val p = exclIt.next() ?: continue
                builder.excludeRouteCompat(p.address(), p.prefix())
            }

            // IPv6 路由
            var routeIt6 = options.getInet6RouteAddress()
            if (routeIt6 != null && routeIt6.hasNext()) {
                while (routeIt6.hasNext()) {
                    val p = routeIt6.next() ?: continue
                    builder.addRoute(p.address(), p.prefix())
                }
            } else {
                builder.addRoute("::", 0)
            }
            var exclIt6 = options.getInet6RouteExcludeAddress()
            while (exclIt6?.hasNext() == true) {
                val p = exclIt6.next() ?: continue
                builder.excludeRouteCompat(p.address(), p.prefix())
            }

            // 应用过滤（仅包含/排除指定应用）
            var includeIt = options.getIncludePackage()
            while (includeIt?.hasNext() == true) {
                builder.addAllowedApplication(includeIt.next() ?: continue)
            }
            var excludeIt = options.getExcludePackage()
            while (excludeIt?.hasNext() == true) {
                builder.addDisallowedApplication(excludeIt.next() ?: continue)
            }

            // 建立 TUN 并把 fd 交给 Go 核心
            val pfd = builder.establish()
                ?: throw Exception("establish VPN interface failed")
            vpnFd = pfd.detachFd()
            return vpnFd
        }

        // excludeRoute 只有 IpPrefix 重载（API 33+），低版本跳过
        private fun Builder.excludeRouteCompat(address: String, prefix: Int) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                excludeRoute(IpPrefix(InetAddress.getByName(address), prefix))
            }
        }

        // ---------- 平台探测 ----------

        override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

        override fun autoDetectInterfaceControl(fd: Int) {
            // 关键：把 outbound socket 交给系统 protect，使其绕过 VPN（tun0），
            // 否则内核的出站连接会被自己的 TUN 捕获形成环路，报
            // "no available network interface"。
            service.protect(fd)
        }

        override fun useProcFS(): Boolean = false

        override fun findConnectionOwner(
            ipProtocol: Int,
            sourceAddress: String?,
            sourcePort: Int,
            destinationAddress: String?,
            destinationPort: Int,
        ): ConnectionOwner? = ConnectionOwner()

        override fun underNetworkExtension(): Boolean = false

        override fun includeAllNetworks(): Boolean = false

        override fun readWIFIState(): WIFIState? = null

        override fun systemCertificates(): StringIterator? = null

        override fun localDNSTransport(): LocalDNSTransport? =
            object : LocalDNSTransport {
                override fun raw(): Boolean = false

                override fun exchange(
                    ctx: ExchangeContext?,
                    message: ByteArray?,
                ) {
                    ctx?.errnoCode(OsConstants.EAFNOSUPPORT)
                }

                override fun lookup(
                    ctx: ExchangeContext?,
                    network: String,
                    domain: String,
                ) {
                    if (ctx == null) return
                    try {
                        val addresses = InetAddress.getAllByName(domain)
                        val builder = StringBuilder()
                        for (address in addresses) {
                            val ok = (network == "ip4" && address is Inet4Address) ||
                                (network == "ip6" && address is Inet6Address)
                            if (ok) {
                                builder.append(address.hostAddress).append('\n')
                            }
                        }
                        if (builder.isEmpty()) {
                            ctx.errnoCode(OsConstants.EHOSTUNREACH)
                        } else {
                            ctx.success(builder.toString())
                        }
                    } catch (e: Exception) {
                        ctx.errnoCode(OsConstants.EHOSTUNREACH)
                    }
                }
            }

        override fun clearDNSCache() {}

        override fun sendNotification(notification: io.nekohasekai.libbox.Notification?) {}

        override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
            if (listener == null) return
            interfaceMonitorListener = listener
            val cm = service.getSystemService(ConnectivityManager::class.java)
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    updateDefaultInterface(cm, network)
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    capabilities: NetworkCapabilities,
                ) {
                    updateDefaultInterface(cm, network)
                }

                override fun onLinkPropertiesChanged(
                    network: Network,
                    linkProperties: LinkProperties,
                ) {
                    updateDefaultInterface(cm, network)
                }

                override fun onLost(network: Network) {
                    interfaceMonitorListener?.updateDefaultInterface("", -1, false, false)
                }
            }
            interfaceMonitorCallback = callback
            try {
                cm.registerDefaultNetworkCallback(callback)
            } catch (_: Exception) {
            }
            // 立即回调一次当前默认接口，确保 sing-box 立刻拿到物理网卡
            try {
                cm.activeNetwork?.let { updateDefaultInterface(cm, it) }
            } catch (_: Exception) {
            }
        }

        private fun updateDefaultInterface(
            cm: ConnectivityManager,
            network: Network,
            depth: Int = 0,
        ) {
            if (depth > 2) return
            val caps = cm.getNetworkCapabilities(network)
            if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                // VPN 网络（tun0）不应作为默认接口，改用底层真实网络（wlan0/蜂窝）
                val underlying = try {
                    val method = ConnectivityManager::class.java
                        .getMethod("getUnderlyingNetworks", Network::class.java)
                    method.invoke(cm, network) as? Array<Network>
                } catch (_: Exception) {
                    null
                }
                if (!underlying.isNullOrEmpty()) {
                    updateDefaultInterface(cm, underlying[0], depth + 1)
                }
                return
            }
            val linkProps = cm.getLinkProperties(network) ?: return
            val ifaceName = linkProps.interfaceName ?: return
            val ifaceIndex = try {
                JavaNetworkInterface.getByName(ifaceName)?.index ?: -1
            } catch (_: Exception) {
                -1
            }
            val isExpensive =
                caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) != true
            val isConstrained =
                caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED) != true
            interfaceMonitorListener?.updateDefaultInterface(
                ifaceName, ifaceIndex, isExpensive, isConstrained,
            )
        }

        override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
            val cb = interfaceMonitorCallback ?: return
            try {
                service.getSystemService(ConnectivityManager::class.java)
                    .unregisterNetworkCallback(cb)
            } catch (_: Exception) {
            }
            interfaceMonitorCallback = null
            interfaceMonitorListener = null
        }

        override fun getInterfaces(): NetworkInterfaceIterator? {
            val interfaces = try {
                JavaNetworkInterface.getNetworkInterfaces()?.toList() ?: emptyList()
            } catch (_: Exception) {
                emptyList()
            }
            return object : NetworkInterfaceIterator {
                private val iterator = interfaces.iterator()
                override fun hasNext(): Boolean = iterator.hasNext()
                override fun next(): io.nekohasekai.libbox.NetworkInterface? {
                    val jif = iterator.next()
                    val nif = io.nekohasekai.libbox.NetworkInterface()
                    nif.name = jif.name ?: ""
                    nif.index = jif.index
                    nif.mtu = try {
                        jif.mtu
                    } catch (_: Exception) {
                        1500
                    }
                    nif.flags = fallbackFlags(jif)
                    val addrList = mutableListOf<String>()
                    try {
                        for (ia in jif.interfaceAddresses) {
                            val host = ia.address?.hostAddress ?: continue
                            // 必须是 CIDR 格式（netip.MustParsePrefix），且去掉 IPv6 zone
                            val cleanHost = host.substringBefore('%')
                            addrList.add("$cleanHost/${ia.networkPrefixLength}")
                        }
                    } catch (_: Exception) {
                    }
                    nif.addresses = object : StringIterator {
                        private val a = addrList.iterator()
                        override fun hasNext() = a.hasNext()
                        override fun next() = a.next()
                        override fun len() = addrList.size
                    }
                    nif.type = interfaceTypeOf(jif.name)
                    return nif
                }
            }
        }

        private fun interfaceTypeOf(name: String?): Int {
            val n = name?.lowercase() ?: return 3
            return when {
                n.startsWith("wlan") || n.startsWith("wifi") -> 0
                n.startsWith("rmnet") || n.startsWith("ccmni") ||
                    n.startsWith("wwan") || n.startsWith("pdp") ||
                    n.startsWith("svnet") -> 1
                n.startsWith("eth") -> 2
                else -> 3
            }
        }

        private fun fallbackFlags(jif: JavaNetworkInterface): Int {
            var flags = 0
            try {
                if (jif.isUp) flags = flags or 0x1 or 0x40 // IFF_UP | IFF_RUNNING
                if (jif.isLoopback) flags = flags or 0x8 // IFF_LOOPBACK
                if (jif.isPointToPoint) flags = flags or 0x10 // IFF_POINTOPOINT
                if (jif.supportsMulticast()) flags = flags or 0x1000 // IFF_MULTICAST
            } catch (_: Exception) {
            }
            return flags
        }

        // ---------- 命令服务回调 ----------

        override fun getSystemProxyStatus(): SystemProxyStatus =
            SystemProxyStatus()

        override fun serviceReload() {}

        override fun serviceStop() {
            executor.execute { stopVpn() }
        }

        override fun setSystemProxyEnabled(enabled: Boolean) {}

        override fun writeDebugMessage(message: String?) {
            message?.let { VpnController.appendLog("debug: $it") }
        }
    }
}
