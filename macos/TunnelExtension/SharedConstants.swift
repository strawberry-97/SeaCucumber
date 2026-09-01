import Foundation

/// App 与 Network Extension 之间共享的常量（隧道侧副本，与主应用保持一致）
enum SharedConstants {
    static let appGroupID = "group.com.scvpn.vpnApp"
    static let configFileName = "config.json"
    static let logFileName = "tunnel.log"

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func readConfig() -> String? {
        guard let url = sharedContainerURL?.appendingPathComponent(configFileName) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func writeConfig(_ json: String) {
        guard let url = sharedContainerURL?.appendingPathComponent(configFileName) else { return }
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    static func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        var targets: [URL] = []
        if let own = ownLogURL { targets.append(own) }
        if let shared = sharedContainerURL?.appendingPathComponent(logFileName) { targets.append(shared) }
        for url in targets {
            if let fh = try? FileHandle(forWritingTo: url) {
                defer { try? fh.close() }
                _ = try? fh.seekToEnd()
                try? fh.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    static var ownLogURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(logFileName)
    }

    static func clearLog() {
        if let url = sharedContainerURL?.appendingPathComponent(logFileName) {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = ownLogURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
