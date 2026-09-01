#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <atomic>
#include <map>
#include <memory>
#include <string>

// Windows 平台的 VPN 引擎：通过 sing-box.exe 子进程实现 TUN 代理。
//
// 依赖：sing-box.exe 与 wintun.dll 需放在可执行文件同目录（见 README）。
// 建立连接需要管理员权限（sing-box TUN 需要）。
class VpnEngine {
 public:
  explicit VpnEngine(flutter::FlutterEngine* engine);
  ~VpnEngine();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Connect(const std::string& config,
               const std::map<std::string, std::string>& rules);
  void Disconnect();
  std::string Status() const;
  std::string ReadLog() const;
  void ClearLog();

  void NotifyStatus(const std::string& status);
  std::string ConfigPath() const;
  std::string LogPath() const;

  flutter::FlutterEngine* engine_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::atomic<int> process_pid_{0};
};
