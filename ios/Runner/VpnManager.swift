import Foundation
import NetworkExtension

/// VPN 错误
struct VPNError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// 管理 VPN 配置与连接（NETunnelProviderManager）
///
/// 移植自 clash-verg 的 VPNManager.swift
final class VpnManager {
    static let shared = VpnManager()

    let tunnelBundleID = "com.scvpn.vpnApp.tunnel"

    private var statusObserver: NSObjectProtocol?

    /// 状态变化回调（AppDelegate 用于转发到 Flutter）
    var onStatusChange: ((String) -> Void)?

    private var manager: NETunnelProviderManager?

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshStatusAndNotify()
        }
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    private func refreshStatusAndNotify() {
        guard let m = manager ?? tryLoadManager() else { return }
        onStatusChange?(Self.statusName(m.connection.status))
    }

    private func tryLoadManager() -> NETunnelProviderManager? {
        // 同步加载不可靠，这里仅做同步快速路径；完整加载走 loadManager()
        return manager
    }

    /// 当前状态名称（与 Flutter 侧 VpnStatus 枚举对应）
    static func statusName(_ status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnecting: return "disconnecting"
        case .reasserting: return "reasserting"
        case .invalid: return "notConfigured"
        case .disconnected: return "disconnected"
        @unknown default: return "disconnected"
        }
    }

    /// 异步加载 manager
    private func loadManager() async -> NETunnelProviderManager? {
        if let manager { return manager }
        let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
        return managers?.first
    }

    /// 查询当前状态（供 Flutter 调用）
    ///
    /// 注意：这里只读，不再关闭 on-demand —— 否则每次 Flutter 轮询状态
    /// 都会把「始终开启 VPN」拆掉，导致隧道被系统断开后无法自动恢复。
    func currentStatus() async -> String {
        guard let m = await loadManager() else {
            return Self.statusName(.invalid)
        }
        return Self.statusName(m.connection.status)
    }

    /// 当前是否已启用「始终开启 VPN」（on-demand）
    func isAlwaysOn() async -> Bool {
        guard let m = await loadManager() else { return false }
        return m.isOnDemandEnabled
    }

    /// 创建或加载 VPN 配置
    private func ensureManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first {
            manager = existing
            return existing
        }
        let m = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelBundleID
        proto.serverAddress = "SC VPN"
        proto.providerConfiguration = ["configFileName": SharedConstants.configFileName]
        m.protocolConfiguration = proto
        m.localizedDescription = "SC VPN"
        m.isEnabled = true
        try await m.saveToPreferences()
        manager = m
        return m
    }

    /// 启动 VPN；configJSON 通过 providerConfiguration 传给隧道
    ///
    /// 默认开启 on-demand（always-on）：隧道被系统/重启/切网断开后由系统自动拉起，
    /// 防止「自动断开」。
    func connect(configJSON: String) async throws {
        let m = try await ensureManager()
        if let proto = m.protocolConfiguration as? NETunnelProviderProtocol {
            proto.providerConfiguration = ["config": configJSON]
        }
        m.isEnabled = true
        enableAlwaysOn(m)
        try await m.saveToPreferences()

        // 已连接（例如切换节点）：先停再起，保证新配置生效
        if m.connection.status == .connected || m.connection.status == .connecting {
            m.connection.stopVPNTunnel()
            try await Task.sleep(nanoseconds: 1_200_000_000)
        }
        try m.connection.startVPNTunnel()
        onStatusChange?(Self.statusName(.connecting))
        // 等 2 秒，若隧道未能建立则读取其日志告知用户
        try await Task.sleep(nanoseconds: 2_000_000_000)
        if m.connection.status != .connected, m.connection.status != .connecting {
            let log = SharedConstants.readLog()
            if !log.isEmpty {
                throw VPNError("隧道启动失败：\n\(log)")
            }
        }
        onStatusChange?(Self.statusName(m.connection.status))
    }

    /// 开启「始终开启 VPN」：on-demand 规则为 connect，系统会在隧道掉线时自动重连
    private func enableAlwaysOn(_ m: NETunnelProviderManager) {
        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any
        m.onDemandRules = [rule]
        m.isOnDemandEnabled = true
        SharedConstants.log("always-on: on-demand enabled (NEOnDemandRuleConnect)")
    }

    /// 关闭 always-on。**仅在用户主动断开时调用**，
    /// 否则关闭 on-demand 后 iOS 会立刻把隧道重新拉起，表现为「断不掉」。
    private func disableAlwaysOn(_ m: NETunnelProviderManager) async {
        if !m.isOnDemandEnabled, (m.onDemandRules ?? []).isEmpty { return }
        m.isOnDemandEnabled = false
        m.onDemandRules = []
        try? await m.saveToPreferences()
    }

    /// 停止 VPN（用户主动断开）
    func disconnect() async {
        guard let m = await loadManager() else { return }
        await disableAlwaysOn(m)
        if m.connection.status == .connected || m.connection.status == .connecting {
            m.connection.stopVPNTunnel()
        }
        onStatusChange?(Self.statusName(.disconnecting))
    }
}
