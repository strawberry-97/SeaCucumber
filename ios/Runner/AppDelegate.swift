import Flutter
import UIKit
import Network
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "com.scvpn.vpn/engine"
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS 14+ 本地网络授权：启动时主动探测局域网，触发系统弹窗
    LocalNetworkPermission.request()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let ch = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "VpnEngine")!.messenger()
    )
    channel = ch

    // 状态变化转发到 Flutter
    VpnManager.shared.onStatusChange = { [weak self] status in
      self?.channel?.invokeMethod("onStatusChanged", arguments: status)
    }

    ch.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "gone", message: nil, details: nil))
        return
      }
      Task {
        await self.handle(call, result: result)
      }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    switch call.method {
    case "prepare":
      // iOS 首次连接时系统会弹 VPN 授权框，prepare 无需额外操作
      result(true)

    case "connect":
      guard let args = call.arguments as? [String: Any],
            let config = args["config"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少 config", details: nil))
        return
      }
      if let rules = args["rules"] as? [String: String], !rules.isEmpty {
        SharedConstants.writeRuleSets(rules)
      } else {
        SharedConstants.ensureRuleSets()
      }
      SharedConstants.writeConfig(config)
      do {
        try await VpnManager.shared.connect(configJSON: config)
        result(nil)
      } catch {
        result(FlutterError(code: "connect_failed", message: error.localizedDescription, details: nil))
      }

    case "disconnect":
      await VpnManager.shared.disconnect()
      result(nil)

    case "status":
      result(await VpnManager.shared.currentStatus())

    case "readLog":
      result(SharedConstants.readLog())

    case "clearLog":
      SharedConstants.clearLog()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// iOS 14+ 本地网络授权触发工具
///
/// iOS 没有“网络权限”这种全局开关，也不会在 App 启动时自动弹窗。
/// 本地网络弹窗只有在 App 真正向局域网发送/接收数据时才会出现。
/// 这里通过向子网广播地址发一个 UDP 探测包来主动触发系统弹窗。
enum LocalNetworkPermission {
    static func request() {
        DispatchQueue.global(qos: .utility).async {
            guard let broadcast = firstBroadcastAddress() else { return }
            let conn = NWConnection(
                host: NWEndpoint.Host(broadcast),
                port: NWEndpoint.Port(rawValue: 9)!,
                using: .udp
            )
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.send(content: Data([0x01]), completion: .contentProcessed { _ in
                        conn.cancel()
                    })
                case .failed, .cancelled:
                    conn.cancel()
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .utility))
        }
    }

    /// 取第一个非回环 IPv4 接口，并计算其子网广播地址
    private static func firstBroadcastAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
                  let nm = ifa.ifa_netmask else { continue }

            let addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let mask = nm.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }

            let ip = UInt32(bigEndian: addr.sin_addr.s_addr)
            let m = UInt32(bigEndian: mask.sin_addr.s_addr)
            guard m != 0 else { continue }

            guard let ipStr = ipString(addr.sin_addr.s_addr),
                  !ipStr.hasPrefix("127.") else { continue }

            let broadcastHost = (ip & m) | (~m)
            var bc = in_addr()
            bc.s_addr = broadcastHost.bigEndian
            return ipString(bc.s_addr)
        }
        return nil
    }

    private static func ipString(_ saddr: in_addr_t) -> String? {
        var addr = in_addr()
        addr.s_addr = saddr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &addr, &buf, socklen_t(buf.count)) != nil else { return nil }
        return String(cString: buf)
    }
}
