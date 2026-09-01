# SC VPN（vpn_app）

[English](README_EN.md) | 中文

基于 [Flutter](https://flutter.dev) + [sing-box](https://sing-box.sagernet.org/) 内核的跨平台 VPN 客户端，支持 **Android / iOS / macOS / Windows**。

参考 `clash-verg`（iOS SwiftUI + sing-box）重写为 Flutter，保留其核心能力：导入订阅 → 显示节点 → 一键连接，**国内直连、国外走代理**（分流路由）。

- App 显示名：**SC VPN**（工程名 `vpn_app`）
- UI 风格：玻璃拟态（Glassmorphism），浅冰青蓝主色 `#87D8F5`，跟随系统浅色/深色模式
- 仅用于侧载（sideload）/ 个人自用，不上架应用商店
- 仅供个人自用，**禁止任何商业用途**
- 内核：sing-box（Go 移动库 `libbox`，iOS / macOS / Android 直连内核，Windows 走 `sing-box.exe` 子进程）

## 功能特性

- **分流路由**：基于 `geosite-cn` / `geoip-cn` 规则集（本地 `.srs` 二进制），国内流量直连、国外走代理；私有 IP 也直连
- **DNS 分流**：国内域名用国内公共 DNS（Android 无系统 DNS，直连解析），国外域名走代理 DoH（`https://8.8.8.8/dns-query`）
- **双订阅协议 + 自动识别**：Clash Verge（YAML）、小火箭（base64 `vless://`）、「其它」（自动识别格式）
- **协议支持**：VLESS + Reality（TCP）、VLESS + WebSocket + TLS；`hysteria2` 暂不支持
- **订阅链接本机记忆**：订阅成功后自动保存，下次启动自动导入并选中第一个节点
- **本地订阅文件导入**：订阅服务器不可直连时，可从 App 文档目录的 `subscription_local.txt` 读取并导入
- **玻璃拟态 UI**：磨砂玻璃质感 + 浅色/深色自适应；节点 / 订阅 / 日志 / 设置

## 平台状态

| 平台 | 状态 | 说明 |
|---|---|---|
| Android | ✅ 可用 | `VpnService` + `libbox.aar`，含 `protect()` 防环路、前台通知、接口探测 |
| macOS | ✅ 可用 | `NETunnelProviderManager` + 隧道扩展 + `Libbox.xcframework`（含 macos slice） |
| iOS | ✅ 可用 | `NETunnelProviderManager` + 隧道扩展 + `Libbox.xcframework`；需真机 + 开发者签名 + App Group，已内置本地网络授权探测与 Personal VPN entitlement（模拟器无法建立 TUN） |
| Windows | ⏳ 引擎就绪 | `sing-box.exe` 子进程（UAC 提权）+ `wintun.dll`，引擎已完整实现，待 Windows 环境验证 |

## 目录结构

```
vpn_app/
├── lib/                        # Dart 层（跨平台）
│   ├── models/                 # VlessNode / SubscriptionType / AppAppearance
│   ├── services/               # 解析器 / 配置生成 / 订阅 / 文件 / VPN 引擎
│   ├── state/                  # AppState（ChangeNotifier）
│   ├── theme/                  # 玻璃拟态主题
│   └── ui/                     # HomePage / NodesPage / SettingsPage / LogsPage
├── assets/rules/               # geosite-cn.srs / geoip-cn.srs（内置规则集）
├── assets/alipay-qr.jpg        # 支付宝收款码
├── assets/wechat-qr.jpg        # 微信收款码
├── android/                    # Android 原生（VpnService + libbox.aar）
├── ios/                        # iOS 原生（Runner + Tunnel Network Extension + Libbox.xcframework）
├── macos/                      # macOS 原生（Runner + TunnelExtension）
├── windows/                    # Windows 原生（sing-box.exe 子进程）
├── scripts/                    # 构建与工程配置脚本（含 build_libbox_android.sh 一键构建内核）
└── test/                       # Dart 单元测试（解析器 / 配置生成）
```

## 统一约定

- MethodChannel：`com.scvpn.vpn/engine`
  - Dart → 原生：`prepare` / `connect({config, rules})` / `disconnect` / `status` / `readLog` / `clearLog`
  - 原生 → Dart：`onStatusChanged(status)`
- Bundle ID：`com.scvpn.vpnApp`；隧道扩展 `com.scvpn.vpnApp.tunnel`
- App Group（iOS/macOS）：`group.com.scvpn.vpnApp`
- 规则集以 base64 随 `connect` 的 `rules` 参数传给原生，原生写入内核 working 目录

## 使用流程

1. 打开 App → 底部切到「设置」→ 选择订阅类型（Clash Verge / 小火箭 / 其它）
2. 粘贴订阅地址 → 点「导入订阅」；若订阅服务器不可直连，可把订阅内容写入文档目录
   `subscription_local.txt` 后点「从本地文件导入」
3. 回「节点」页选节点 → 点「建立连接」，Android 首次会弹系统 VPN 授权框，点允许
4. 换节点 = 重写 `config.json` + 隧道重启
5. 订阅成功后链接已本机记忆；下次启动会自动导入并选中第一个节点

## 订阅格式说明

| 类型 | User-Agent | Accept | 解析方式 |
|---|---|---|---|
| Clash Verge | `clash-verge/2.5.1` | `application/yaml, text/yaml, */*` | `ClashParser`（YAML 中 VLESS 节点） |
| 小火箭 | `Shadowrocket/2.2.12` | `text/plain, */*` | `ShadowrocketParser`（base64 `vless://` 列表） |
| 其它 | `Mozilla/5.0 (iPhone…)` | `*/*` | 自动识别：含 `proxies:` 按 Clash 解析，否则按小火箭解析 |

- 订阅链接默认空，**仅在导入成功后**写入本机（key：`clashVergeURL` / `shadowrocketURL` / `otherURL`，类型存于 `subscriptionType`）
- 占位节点（剩余流量 / 距离下次重置 / 套餐到期等）会被自动过滤
- 小火箭订阅中的 `hysteria2://` 节点暂不支持，会被跳过

## 构建内核 libbox

sing-box Go 内核需要 **Go 1.25+**（tailscale 依赖使用了 `reflect.TypeAssert`）与
**sagernet/gomobile v0.1.12**（旧式 `&error` 指针签名，与仓库内 Swift/Kotlin 代码匹配）。

```bash
# Go 1.25+（国内镜像）
curl -sL -o /tmp/go.tar.gz https://mirrors.aliyun.com/golang/go1.25.4.darwin-arm64.tar.gz
mkdir -p ~/development && tar -C ~/development -xzf /tmp/go.tar.gz && mv ~/development/go ~/development/go-1.25.4

export GOROOT=$HOME/development/go-1.25.4
export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
export GOPATH=$HOME/go
GOFLAGS=-mod=mod go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
```

### Android（libbox.aar）

需要 Android SDK + NDK 28.0.13004108 与 OpenJDK 17（`libcronet.a` 预编译自该 NDK 版本，
旧版 lld 不认识新重定位类型）：

```bash
# 安装 NDK（必须 28.0.13004108）
sdkmanager "ndk;28.0.13004108"

# 构建 AAR（在 singbox-core 源码目录内运行官方脚本）
cd <singbox-core 路径>
export GOROOT=$HOME/development/go-1.25.4
export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
export JAVA_HOME=$HOME/development/jdk-17/Contents/Home   # openjdk 17
export ANDROID_HOME=$HOME/Library/Android/sdk
go run ./cmd/internal/build_libbox -target android
cp libbox.aar <本项目>/android/app/libs/libbox.aar
```

`android/app/build.gradle.kts` 已启用 `implementation(files("libs/libbox.aar"))`。

> 也可直接运行 `./scripts/build_libbox_android.sh [singbox-core 路径]` 一键完成构建与复制
> （脚本默认读取 `../clash-verg/singbox-core`）。

> 国内网络：`android/settings.gradle.kts` 与 `android/build.gradle.kts` 已配置
> 阿里云 Maven 镜像（central / google / gradle-plugin），避免 Maven Central 被墙。

### Apple（Libbox.xcframework，含 iOS/macOS slice）

```bash
cd <singbox-core 源码路径>
export GOROOT=$HOME/development/go-1.25.4
export PATH="$GOROOT/bin:$HOME/go/bin:$PATH"
# 全平台：ios,iossimulator,tvos,tvossimulator,macos
go run ./cmd/internal/build_libbox -target apple
# 或仅 macOS
go run ./cmd/internal/build_libbox -target apple -platform macos
```

产物 `Libbox.xcframework` 需放到：
- iOS：`ios/Frameworks/Libbox.xcframework`
- macOS：`macos/Frameworks/Libbox.xcframework`

> 仓库内 `ios/Frameworks/Libbox.xcframework` 已从 clash-verg 复制（仅 iOS slice，
> 旧式 gomobile 签名）。macOS 需要重新构建含 macos slice 的版本。

## 各平台运行

### iOS / macOS

Xcode 打开 `ios/Runner.xcodeproj` 或 `macos/Runner.xcodeproj`：

1. 登录开发者账号，为 Runner 与 tunnel 两个 target 配置签名
2. 在开发者后台注册 App Group `group.com.scvpn.vpnApp`，并开通
   Personal VPN entitlement（`com.apple.developer.networking.vpn.api` = `allow-vpn`）；
   两个 target 的 Capabilities 都勾选 App Groups / Network Extension
3. 真机运行（VPN 隧道无法在 iOS 模拟器上建立 TUN）；
   App 启动时会主动探测局域网，触发 iOS「本地网络」授权弹窗

> 工程结构已由脚本预置：
> - `scripts/add_swift_to_xcode.py`（VpnManager/SharedConstants 注册）
> - `scripts/add_ios_tunnel_target.py`（iOS 隧道 target）
> - `scripts/add_macos_tunnel_target.py`（macOS 隧道 target）

### Android

```bash
cd vpn_app
flutter run
# 或构建 APK
flutter build apk --debug
```

需要先构建并启用 `libbox.aar`（见上文）。

### Windows

1. 下载与内核版本匹配的 `sing-box.exe` 与 `wintun.dll`，
   放到编译产物同目录（或系统 PATH）
2. `flutter build windows` 后用管理员权限运行
   （sing-box TUN 需要管理员权限，程序会通过 UAC 提权）

## Dart 层测试

```bash
flutter test
flutter analyze
```

## 赞助支持

> 如果这个项目对你有帮助，欢迎扫码支持作者 🙏

<div align="center">
  <img src="assets/alipay-qr.jpg" width="200" alt="支付宝收款码" />
  <img src="assets/wechat-qr.jpg" width="200" alt="微信收款码" />
</div>

## 使用声明

> ⚠️ 本项目仅供个人学习与自用，**禁止任何商业用途或商业行为**（包括但不限于倒卖、收费分发、商业部署、盈利等）。请勿将本项目用于任何盈利或商业场景。

## 说明

- 日志：iOS/macOS/Android 由内核写入各自容器，Dart 通过 MethodChannel `readLog` 读取
- 分流：配置生成器使用 `geosite-cn`/`geoip-cn` 规则集实现国内直连、
  其余流量走代理出口
