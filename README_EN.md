# SC VPN (vpn_app)

[中文](README.md) | English

A cross-platform VPN client built with [Flutter](https://flutter.dev) and the [sing-box](https://sing-box.sagernet.org/) core, supporting **Android / iOS / macOS / Windows**.

Rewritten in Flutter, referencing `clash-verg` (iOS SwiftUI + sing-box), while keeping its core workflow: import subscription → list nodes → one-tap connect, with **direct connection for domestic traffic and proxying for overseas traffic** (split routing).

- App display name: **SC VPN** (project name `vpn_app`)
- UI style: Glassmorphism with a light ice-blue primary color `#87D8F5`, following the system light/dark mode
- For sideloading / personal use only, not distributed on app stores
- For personal use only; **any commercial use is prohibited**
- Core: sing-box (Go mobile library `libbox`; iOS / macOS / Android link the core directly, Windows uses a `sing-box.exe` subprocess)

## Features

- **Split routing**: based on `geosite-cn` / `geoip-cn` rule sets (local `.srs` binaries), domestic traffic goes direct, overseas traffic goes through the proxy; private IPs also go direct
- **Split DNS**: domestic domains use domestic public DNS (Android has no system DNS and resolves directly), overseas domains go through proxy DoH (`https://8.8.8.8/dns-query`)
- **Two subscription protocols + auto-detection**: Clash Verge (YAML), Shadowrocket (base64 `vless://`), "Other" (auto-detected format)
- **Protocol support**: VLESS + Reality (TCP), VLESS + WebSocket + TLS; `hysteria2` is not supported yet
- **Local subscription memory**: after a successful import the URL is saved and automatically re-imported on the next launch, selecting the first node
- **Local subscription file import**: when the subscription server is not directly reachable, content can be read and imported from `subscription_local.txt` in the app's documents directory
- **Glassmorphism UI**: frosted-glass texture with light/dark adaptation; Nodes / Subscription / Logs / Settings

## Platform Status

| Platform | Status | Notes |
|---|---|---|
| Android | ✅ Working | `VpnService` + `libbox.aar`, with `protect()` loop prevention, foreground notification, interface detection |
| macOS | ✅ Working | `NETunnelProviderManager` + tunnel extension + `Libbox.xcframework` (with macOS slice) |
| iOS | ✅ Working | `NETunnelProviderManager` + tunnel extension + `Libbox.xcframework`; requires a real device + developer signing + App Group, with built-in local network permission probing and Personal VPN entitlement (TUN cannot be created on the simulator) |
| Windows | ⏳ Engine ready | `sing-box.exe` subprocess (UAC elevation) + `wintun.dll`; engine fully implemented, pending verification on a Windows environment |

## Directory Structure

```
vpn_app/
├── lib/                        # Dart layer (cross-platform)
│   ├── models/                 # VlessNode / SubscriptionType / AppAppearance
│   ├── services/               # parsers / config generator / subscription / files / VPN engine
│   ├── state/                  # AppState (ChangeNotifier)
│   ├── theme/                  # glassmorphism theme
│   └── ui/                     # HomePage / NodesPage / SettingsPage / LogsPage
├── assets/rules/               # geosite-cn.srs / geoip-cn.srs (built-in rule sets)
├── assets/alipay-qr.jpg        # Alipay QR code
├── assets/wechat-qr.jpg        # WeChat QR code
├── android/                    # Android native (VpnService + libbox.aar)
├── ios/                        # iOS native (Runner + Tunnel Network Extension + Libbox.xcframework)
├── macos/                      # macOS native (Runner + TunnelExtension)
├── windows/                    # Windows native (sing-box.exe subprocess)
├── scripts/                    # build & project setup scripts (incl. build_libbox_android.sh one-click core build)
└── test/                       # Dart unit tests (parsers / config generator)
```

## Shared Conventions

- MethodChannel: `com.scvpn.vpn/engine`
  - Dart → native: `prepare` / `connect({config, rules})` / `disconnect` / `status` / `readLog` / `clearLog`
  - native → Dart: `onStatusChanged(status)`
- Bundle ID: `com.scvpn.vpnApp`; tunnel extension `com.scvpn.vpnApp.tunnel`
- App Group (iOS/macOS): `group.com.scvpn.vpnApp`
- Rule sets are passed to the native side as base64 via the `rules` argument of `connect`; native writes them into the core's working directory

## Usage

1. Open the app → switch to the "Settings" tab → choose a subscription type (Clash Verge / Shadowrocket / Other)
2. Paste the subscription URL → tap "Import Subscription"; if the subscription server is not directly reachable, write the subscription content to the documents directory
   `subscription_local.txt` and tap "Import from Local File"
3. Go back to the "Nodes" page, select a node → tap "Connect"; on Android the system VPN authorization dialog appears the first time — tap Allow
4. Switching nodes = rewriting `config.json` + restarting the tunnel
5. After a successful import the URL is remembered locally; the next launch auto-imports and selects the first node

## Subscription Format Notes

| Type | User-Agent | Accept | Parsing |
|---|---|---|---|
| Clash Verge | `clash-verge/2.5.1` | `application/yaml, text/yaml, */*` | `ClashParser` (VLESS nodes in YAML) |
| Shadowrocket | `Shadowrocket/2.2.12` | `text/plain, */*` | `ShadowrocketParser` (base64 `vless://` list) |
| Other | `Mozilla/5.0 (iPhone…)` | `*/*` | Auto-detect: if it contains `proxies:` parse as Clash, otherwise parse as Shadowrocket |

- Subscription URLs are empty by default and are only written locally **after a successful import** (keys: `clashVergeURL` / `shadowrocketURL` / `otherURL`, with the type stored in `subscriptionType`)
- Placeholder nodes (remaining traffic / time until reset / plan expiry, etc.) are filtered out automatically
- `hysteria2://` nodes in Shadowrocket subscriptions are not supported yet and are skipped

## Building the libbox Core

The sing-box Go core requires **Go 1.25+** (a tailscale dependency uses `reflect.TypeAssert`) and
**sagernet/gomobile v0.1.12** (the legacy `&error` pointer signature, matching the Swift/Kotlin code in this repository).

```bash
# Go 1.25+ (China mirror)
curl -sL -o /tmp/go.tar.gz https://mirrors.aliyun.com/golang/go1.25.4.darwin-arm64.tar.gz
mkdir -p ~/development && tar -C ~/development -xzf /tmp/go.tar.gz && mv ~/development/go ~/development/go-1.25.4

export GOROOT=$HOME/development/go-1.25.4
export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
export GOPATH=$HOME/go
GOFLAGS=-mod=mod go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
```

### Android (libbox.aar)

Requires Android SDK + NDK 28.0.13004108 and OpenJDK 17 (`libcronet.a` is precompiled against that NDK version;
older lld versions do not recognize the new relocation types):

```bash
# Install the NDK (must be 28.0.13004108)
sdkmanager "ndk;28.0.13004108"

# Build the AAR (run the official script inside the singbox-core source directory)
cd <singbox-core path>
export GOROOT=$HOME/development/go-1.25.4
export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
export JAVA_HOME=$HOME/development/jdk-17/Contents/Home   # openjdk 17
export ANDROID_HOME=$HOME/Library/Android/sdk
go run ./cmd/internal/build_libbox -target android
cp libbox.aar <this-project>/android/app/libs/libbox.aar
```

`android/app/build.gradle.kts` already has `implementation(files("libs/libbox.aar"))` enabled.

> You can also run `./scripts/build_libbox_android.sh [singbox-core path]` to build and copy in one step
> (the script defaults to `../clash-verg/singbox-core`).

> For networks in China: `android/settings.gradle.kts` and `android/build.gradle.kts` are already configured
> with Aliyun Maven mirrors (central / google / gradle-plugin) to avoid Maven Central being blocked.

### Apple (Libbox.xcframework, with iOS/macOS slices)

```bash
cd <singbox-core source path>
export GOROOT=$HOME/development/go-1.25.4
export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
# All platforms: ios,iossimulator,tvos,tvossimulator,macos
go run ./cmd/internal/build_libbox -target apple
# or macOS only
go run ./cmd/internal/build_libbox -target apple -platform macos
```

The `Libbox.xcframework` artifact needs to be placed in:
- iOS: `ios/Frameworks/Libbox.xcframework`
- macOS: `macos/Frameworks/Libbox.xcframework`

> The `ios/Frameworks/Libbox.xcframework` in this repository was copied from clash-verg (iOS slice only,
> legacy gomobile signature). macOS requires a rebuilt version that includes the macOS slice.

## Running on Each Platform

### iOS / macOS

Open `ios/Runner.xcodeproj` or `macos/Runner.xcodeproj` in Xcode:

1. Sign in with a developer account and configure signing for both the Runner and tunnel targets
2. Register the App Group `group.com.scvpn.vpnApp` in the developer portal, and enable the
   Personal VPN entitlement (`com.apple.developer.networking.vpn.api` = `allow-vpn`);
   enable App Groups / Network Extension capabilities for both targets
3. Run on a real device (a VPN tunnel cannot create a TUN interface on the iOS simulator);
   on launch the app actively probes the local network to trigger the iOS "Local Network" permission dialog

> The project structure is pre-configured by scripts:
> - `scripts/add_swift_to_xcode.py` (registers VpnManager/SharedConstants)
> - `scripts/add_ios_tunnel_target.py` (iOS tunnel target)
> - `scripts/add_macos_tunnel_target.py` (macOS tunnel target)

### Android

```bash
cd vpn_app
flutter run
# or build an APK
flutter build apk --debug
```

Build and enable `libbox.aar` first (see above).

### Windows

1. Download a `sing-box.exe` and `wintun.dll` matching the core version, and place them next to
   the build output (or on the system PATH)
2. Run with administrator privileges after `flutter build windows`
   (sing-box TUN requires administrator privileges; the app elevates via UAC)

## Dart-layer Tests

```bash
flutter test
flutter analyze
```

## Sponsor

> If this project helps you, feel free to scan the QR codes to support the author 🙏

<div align="center">
  <img src="assets/alipay-qr.jpg" width="200" alt="Alipay QR code" />
  <img src="assets/wechat-qr.jpg" width="200" alt="WeChat QR code" />
</div>

## Disclaimer

> ⚠️ This project is for personal learning and personal use only. **Any commercial use or commercial activity is prohibited** (including but not limited to reselling, paid distribution, commercial deployment, profiting, etc.). Please do not use this project in any profit-making or commercial scenario.

## Notes

- Logs: on iOS/macOS/Android the core writes to its own container; Dart reads them via the MethodChannel `readLog`
- Routing: the config generator uses the `geosite-cn`/`geoip-cn` rule sets for direct domestic routing,
  with the remaining traffic going out through the proxy
