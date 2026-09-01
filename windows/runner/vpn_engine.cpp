#include "vpn_engine.h"

#include <flutter/encodable_value.h>
#include <flutter/engine_method_result.h>
#include <flutter/method_channel.h>

#include <filesystem>
#include <fstream>
#include <sstream>

#include <shellapi.h>

namespace fs = std::filesystem;

VpnEngine::VpnEngine(flutter::FlutterEngine* engine) : engine_(engine) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine_->messenger(), "com.scvpn.vpn/engine",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });
}

VpnEngine::~VpnEngine() {
  Disconnect();
}

void VpnEngine::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "prepare") {
    // Windows 端 TUN 需要管理员权限；连接时若失败会返回错误提示。
    result->Success(flutter::EncodableValue(true));
  } else if (method == "connect") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    std::string config;
    std::map<std::string, std::string> rules;
    if (args) {
      auto it = args->find(flutter::EncodableValue("config"));
      if (it != args->end()) {
        if (auto* s = std::get_if<std::string>(&it->second)) {
          config = *s;
        }
      }
      auto rit = args->find(flutter::EncodableValue("rules"));
      if (rit != args->end()) {
        if (auto* m = std::get_if<flutter::EncodableMap>(&rit->second)) {
          for (const auto& [k, v] : *m) {
            if (const auto* name = std::get_if<std::string>(&k)) {
              if (const auto* b64 = std::get_if<std::string>(&v)) {
                rules[*name] = *b64;
              }
            }
          }
        }
      }
    }
    Connect(config, rules);
    result->Success();
  } else if (method == "disconnect") {
    Disconnect();
    result->Success();
  } else if (method == "status") {
    result->Success(flutter::EncodableValue(Status()));
  } else if (method == "readLog") {
    result->Success(flutter::EncodableValue(ReadLog()));
  } else if (method == "clearLog") {
    ClearLog();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

std::string VpnEngine::ConfigPath() const {
  auto path = fs::temp_directory_path() / "sc_vpn_config.json";
  return path.string();
}

std::string VpnEngine::LogPath() const {
  auto path = fs::temp_directory_path() / "sc_vpn_tunnel.log";
  return path.string();
}

// 简单的 base64 解码（规则集数据由 Dart 侧提供）
static std::string Base64Decode(const std::string& in) {
  static const std::string table =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string out;
  int val = 0, valb = -8;
  for (unsigned char c : in) {
    if (c == '=') break;
    auto pos = table.find(c);
    if (pos == std::string::npos) continue;
    val = (val << 6) + static_cast<int>(pos);
    valb += 6;
    if (valb >= 0) {
      out.push_back(static_cast<char>((val >> valb) & 0xFF));
      valb -= 8;
    }
  }
  return out;
}

void VpnEngine::Connect(const std::string& config,
                        const std::map<std::string, std::string>& rules) {
  if (config.empty()) {
    NotifyStatus("error");
    return;
  }

  auto dir = fs::path(ConfigPath()).parent_path();
  try {
    fs::create_directories(dir);
  } catch (...) {
  }

  // 写入配置文件
  {
    std::ofstream ofs(ConfigPath(), std::ios::trunc | std::ios::binary);
    ofs << config;
  }

  // 写入规则集（相对路径规则集相对进程工作目录解析，故放在配置同目录）
  for (const auto& [name, b64] : rules) {
    if (name.find('/') != std::string::npos ||
        name.find("..") != std::string::npos) {
      continue;
    }
    std::ofstream ofs((dir / name).string(),
                      std::ios::trunc | std::ios::binary);
    ofs << Base64Decode(b64);
  }

  // sing-box.exe 需要管理员权限才能创建 TUN 接口
  std::string exe = "sing-box.exe";
  std::string cmd = "run -c \"" + ConfigPath() + "\" > \"" + LogPath() + "\" 2>&1";
  std::string cwd = dir.string();

  SHELLEXECUTEINFOA sei = {};
  sei.cbSize = sizeof(sei);
  sei.fMask = SEE_MASK_NOCLOSEPROCESS;
  sei.lpVerb = "runas";  // 请求管理员权限
  sei.lpFile = exe.c_str();
  sei.lpParameters = cmd.c_str();
  sei.lpDirectory = cwd.c_str();
  sei.nShow = SW_HIDE;

  NotifyStatus("connecting");
  if (ShellExecuteExA(&sei) && sei.hProcess) {
    process_pid_.store(GetProcessId(sei.hProcess));
    // 启动成功后由状态查询确认连接；这里乐观标记为已连接
    NotifyStatus("connected");
    CloseHandle(sei.hProcess);
  } else {
    process_pid_.store(0);
    NotifyStatus("error");
  }
}

void VpnEngine::Disconnect() {
  int pid = process_pid_.exchange(0);
  if (pid > 0) {
    HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, static_cast<DWORD>(pid));
    if (h) {
      TerminateProcess(h, 0);
      CloseHandle(h);
    }
  }
  NotifyStatus("disconnected");
}

std::string VpnEngine::Status() const {
  int pid = process_pid_.load();
  if (pid == 0) return "disconnected";
  HANDLE h = OpenProcess(SYNCHRONIZE, FALSE, static_cast<DWORD>(pid));
  if (!h) return "disconnected";
  DWORD wait = WaitForSingleObject(h, 0);
  CloseHandle(h);
  if (wait == WAIT_OBJECT_0) return "disconnected";  // 进程已退出
  return "connected";
}

std::string VpnEngine::ReadLog() const {
  std::ifstream ifs(LogPath());
  if (!ifs) return "";
  std::ostringstream ss;
  ss << ifs.rdbuf();
  return ss.str();
}

void VpnEngine::ClearLog() {
  std::ofstream ofs(LogPath(), std::ios::trunc);
  ofs.close();
}

void VpnEngine::NotifyStatus(const std::string& status) {
  channel_->InvokeMethod("onStatusChanged",
                         std::make_unique<flutter::EncodableValue>(status));
}
