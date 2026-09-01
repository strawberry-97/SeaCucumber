import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "com.scvpn.vpn/engine"
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
