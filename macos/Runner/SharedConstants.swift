import Foundation

/// App 与 Network Extension 之间共享的常量
///
/// 移植自 clash-verg 的 SharedConstants.swift
enum SharedConstants {
    /// App Group 标识（需在 Apple 开发者后台注册，两个 target 的 entitlements 都要声明）
    static let appGroupID = "group.com.scvpn.vpnApp"
    /// 传给隧道的 sing-box 配置（JSON）
    static let configFileName = "config.json"
    /// 隧道运行日志
    static let logFileName = "tunnel.log"

    /// App Group 共享容器 URL
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// 隧道读取配置
    static func readConfig() -> String? {
        guard let url = sharedContainerURL?.appendingPathComponent(configFileName) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// App 写入配置；返回是否成功
    @discardableResult
    static func writeConfig(_ json: String) -> Bool {
        guard let url = sharedContainerURL?.appendingPathComponent(configFileName) else { return false }
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// 读取隧道日志
    static func readLog() -> String {
        guard let url = sharedContainerURL?.appendingPathComponent(logFileName) else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// 清空日志
    static func clearLog() {
        guard let url = sharedContainerURL?.appendingPathComponent(logFileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 分流规则集文件名
    static let ruleSetFiles = ["geoip-cn.srs", "geosite-cn.srs"]

    /// 把内置的 CN 分流规则集（.srs）复制到 App Group 容器。
    /// 隧道 libbox 的 filemanager basePath 是 <容器>/working，相对路径规则集必须放这里。
    @discardableResult
    static func ensureRuleSets() -> Bool {
        guard let container = sharedContainerURL else { return false }
        let workingDir = container.appendingPathComponent("working", isDirectory: true)
        try? FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        var allOK = true
        for name in ruleSetFiles {
            let dest = workingDir.appendingPathComponent(name)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path),
               let size = attrs[.size] as? Int, size > 1000 {
                continue
            }
            let base = (name as NSString).deletingPathExtension
            guard let src = Bundle.main.url(forResource: base, withExtension: "srs") else {
                allOK = false
                continue
            }
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: src, to: dest)
            } catch {
                allOK = false
            }
        }
        return allOK
    }

    /// 把 Dart 传来的规则集（文件名 → base64）写入 App Group/working。
    @discardableResult
    static func writeRuleSets(_ rules: [String: String]) -> Bool {
        guard let container = sharedContainerURL else { return false }
        let workingDir = container.appendingPathComponent("working", isDirectory: true)
        try? FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        var allOK = true
        for (name, b64) in rules {
            guard !name.contains("/"), !name.contains(".."),
                  let data = Data(base64Encoded: b64) else {
                allOK = false
                continue
            }
            do {
                try data.write(to: workingDir.appendingPathComponent(name), options: .atomic)
            } catch {
                allOK = false
            }
        }
        return allOK
    }
}
