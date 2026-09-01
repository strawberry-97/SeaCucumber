#!/usr/bin/env bash
# 构建 Android 的 sing-box Go 内核 libbox.aar
#
# 依赖（本项目已验证）：
#   - Go 1.25+（tailscale 依赖需要 reflect.TypeAssert）
#   - sagernet/gomobile v0.1.12（旧式 &error/ret0_ 签名，与仓库 Swift/Kotlin 代码匹配）
#   - Android SDK + NDK 28.0.13004108（libcronet.a 预编译自该版本）
#   - OpenJDK 17（构建脚本校验 `java --version` 含 "openjdk 17"）
#
# 用法：
#   ./scripts/build_libbox_android.sh [singbox-core 路径]
#
set -euo pipefail

# sing-box 内核源码路径（默认取 clash-verg 目录下的 singbox-core）
SINGBOX_CORE="${1:-$(cd "$(dirname "$0")/../../../clash-verg/singbox-core" && pwd)}"
APP_LIBS="$(cd "$(dirname "$0")/../android/app/libs" && pwd)"

echo "==> sing-box 源码: $SINGBOX_CORE"
echo "==> 输出目录:      $APP_LIBS"

# 环境（可按本机实际路径调整）
GOROOT="${GOROOT:-$HOME/development/go-1.25.4}"
JAVA_HOME="${JAVA_HOME:-$HOME/development/jdk-17/Contents/Home}"
GOPATH="${GOPATH:-$HOME/go}"

export GOROOT
export GOPATH
export JAVA_HOME
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

# 校验依赖
test -x "$GOROOT/bin/go" || { echo "错误: 未找到 Go（$GOROOT/bin/go）"; exit 1; }
test -x "$GOPATH/bin/gomobile" || { echo "错误: 未安装 gomobile（$GOPATH/bin/gomobile）"; exit 1; }
test -n "$ANDROID_HOME" || { echo "错误: 未设置 ANDROID_HOME"; exit 1; }
test -x "$JAVA_HOME/bin/java" || { echo "错误: 未找到 OpenJDK 17（$JAVA_HOME）"; exit 1; }

mkdir -p "$APP_LIBS"

cd "$SINGBOX_CORE"

# 官方构建脚本（-target android 产出 libbox.aar，含 4 个 ABI）
go run ./cmd/internal/build_libbox -target android

# 复制产物
if [[ -f libbox.aar ]]; then
  cp -f libbox.aar "$APP_LIBS/libbox.aar"
  echo "==> 已复制 libbox.aar 到 $APP_LIBS"
else
  echo "提示: 未在 $SINGBOX_CORE 根目录找到 libbox.aar，请手动查找并复制"
fi

echo "==> 完成。android/app/build.gradle.kts 已启用 implementation(files(\"libs/libbox.aar\"))"
