import Foundation
import NetworkExtension
import Libbox

// MARK: - 同步桥接（把 async 桥接给 Go 侧的同步回调）

func runBlocking<T>(_ block: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ResultBox<T>()
    Task.detached(priority: .userInitiated) {
        box.value = await block()
        semaphore.signal()
    }
    semaphore.wait()
    return box.value
}

func runBlocking<T>(_ block: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ResultBox<T>()
    Task.detached(priority: .userInitiated) {
        do {
            box.result = .success(try await block())
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    return try box.result.get()
}

private final class ResultBox<T> {
    var value: T!
    var result: Result<T, Error>!
}

// MARK: - 隧道入口

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var commandServer: LibboxCommandServer?
    private lazy var platformInterface = ExtensionPlatformInterface(self)

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        SharedConstants.clearLog()
        SharedConstants.log("startTunnel begin; providerConfig length = \(options?["config"] as? String ?? "nil")")
        do {
            var config = options?["config"] as? String
            if config == nil || config!.isEmpty {
                config = SharedConstants.readConfig()
                SharedConstants.log("config from appgroup: \(config != nil ? "\(config!.count) bytes" : "nil")")
            } else {
                SharedConstants.log("config from providerConfiguration: \(config!.count) bytes")
            }
            try await startServiceInternal(config: config ?? "")
            SharedConstants.log("startTunnel success")
        } catch {
            SharedConstants.log("startTunnel FAILED: \(error.localizedDescription)")
            throw error
        }
    }

    private func startServiceInternal(config: String) async throws {
        // basePath 必须是短路径：unix socket sun_path 限长约 103 字符。
        let fm = FileManager.default
        guard let sharedURL = fm.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID) else {
            throw TunnelError("App Group 不可用，请检查签名与 entitlements")
        }
        let basePath = sharedURL.path
        let workingPath = sharedURL.appendingPathComponent("working").path
        let tempPath = sharedURL.appendingPathComponent("temp").path
        try? fm.createDirectory(atPath: workingPath, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: tempPath, withIntermediateDirectories: true)

        guard !config.isEmpty else {
            throw TunnelError("未找到配置，请先在主应用中导入订阅并选择节点")
        }
        SharedConstants.log("config loaded: \(config.count) bytes; basePath=\(basePath)")

        let effectiveConfig = injectLogOutput(config)

        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = basePath
        setupOptions.workingPath = workingPath
        setupOptions.tempPath = tempPath
        setupOptions.logMaxLines = 2000
        setupOptions.debug = false

        var setupError: NSError?
        LibboxSetup(setupOptions, &setupError)
        if let setupError {
            throw TunnelError("setup: \(setupError.localizedDescription)")
        }
        SharedConstants.log("LibboxSetup ok")

        var error: NSError?
        commandServer = LibboxNewCommandServer(platformInterface, platformInterface, &error)
        if let error {
            throw TunnelError("command server: \(error.localizedDescription)")
        }
        try commandServer!.start()
        SharedConstants.log("command server started")

        do {
            try commandServer!.startOrReloadService(effectiveConfig, options: LibboxOverrideOptions())
            SharedConstants.log("startOrReloadService ok")
        } catch {
            throw TunnelError("start service: \(error.localizedDescription)")
        }
    }

    /// 把 sing-box 内部日志输出到隧道自己的 Documents/singbox.log
    private func injectLogOutput(_ config: String) -> String {
        guard let data = config.data(using: .utf8),
              var obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return config }
        var logSection = obj["log"] as? [String: Any] ?? [:]
        logSection["level"] = "info"
        logSection["timestamp"] = true
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logSection["output"] = docs.appendingPathComponent("singbox.log").path
        }
        obj["log"] = logSection
        guard let newData = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let newString = String(data: newData, encoding: .utf8)
        else { return config }
        return newString
    }

    func stopService() {
        try? commandServer?.closeService()
        platformInterface.reset()
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        stopService()
        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100_000_000)
            server.close()
            commandServer = nil
        }
    }

    override func sleep() async {
        commandServer?.pause()
    }

    override func wake() {
        commandServer?.wake()
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        let msg = String(data: messageData, encoding: .utf8) ?? ""
        if msg == "reload" {
            guard let config = SharedConstants.readConfig(), !config.isEmpty else {
                return "no config".data(using: .utf8)
            }
            do {
                try commandServer?.startOrReloadService(config, options: LibboxOverrideOptions())
                return nil
            } catch {
                return error.localizedDescription.data(using: .utf8)
            }
        }
        return nil
    }
}

struct TunnelError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
