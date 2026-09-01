import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static let channelName = "com.scvpn.vpn/engine"
  private var channel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let ch = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel = ch

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
      result(true)

    case "connect":
      guard let args = call.arguments as? [String: Any],
            let config = args["config"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少 config", details: nil))
        return
      }
      if let rules = args["rules"] as? [String: String], !rules.isEmpty {
        SharedConstants.writeRuleSets(rules)
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
