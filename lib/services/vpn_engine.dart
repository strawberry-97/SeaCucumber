import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'file_service.dart';

/// VPN 引擎状态
enum VpnStatus {
  disconnected('未连接'),
  connecting('连接中…'),
  connected('已连接'),
  disconnecting('断开中…'),
  reasserting('重连中…'),
  notConfigured('未配置'),
  permissionDenied('未授权'),
  error('错误');

  final String label;
  const VpnStatus(this.label);

  static VpnStatus fromName(String? name) => VpnStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => VpnStatus.disconnected,
      );
}

/// VPN 引擎抽象：通过 MethodChannel 调用各平台原生实现
///
/// 通道：`com.scvpn.vpn/engine`
/// Dart → 原生：prepare / connect / disconnect / isConnected / status
/// 原生 → Dart：onStatusChanged
class VpnEngine {
  static const MethodChannel _channel = MethodChannel('com.scvpn.vpn/engine');

  static final VpnEngine instance = VpnEngine._();

  VpnEngine._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final ValueNotifier<VpnStatus> status = ValueNotifier(VpnStatus.disconnected);

  String? _lastError;

  String? get lastError => _lastError;

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onStatusChanged') {
      final name = call.arguments as String?;
      status.value = VpnStatus.fromName(name);
    } else if (call.method == 'onLog') {
      // 原生侧日志回调（可选）
    }
    return null;
  }

  bool get isConnected => status.value == VpnStatus.connected;

  bool get isBusy =>
      status.value == VpnStatus.connecting ||
      status.value == VpnStatus.disconnecting ||
      status.value == VpnStatus.reasserting;

  /// Android：请求 VPN 权限（返回是否已授权）
  Future<bool> prepare() async {
    try {
      return await _channel.invokeMethod<bool>('prepare') ?? true;
    } on PlatformException catch (e) {
      _lastError = e.message;
      return false;
    }
  }

  /// 建立连接，[configJson] 为 sing-box 配置；规则集一并传给原生层
  Future<void> connect(String configJson) async {
    try {
      final rules = await FileService.loadRuleSetsAsBase64();
      await _channel.invokeMethod('connect', {
        'config': configJson,
        'rules': rules,
      });
    } on PlatformException catch (e) {
      _lastError = e.message;
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      _lastError = e.message;
      rethrow;
    }
  }

  /// 查询当前状态
  Future<void> refreshStatus() async {
    try {
      final name = await _channel.invokeMethod<String>('status');
      status.value = VpnStatus.fromName(name);
    } on PlatformException {
      status.value = VpnStatus.notConfigured;
    }
  }

  /// 读取隧道日志（原生侧实现）
  Future<String> readLog() async {
    try {
      return await _channel.invokeMethod<String>('readLog') ?? '';
    } on PlatformException {
      return '';
    }
  }

  /// 清空隧道日志
  Future<void> clearLog() async {
    try {
      await _channel.invokeMethod('clearLog');
    } catch (_) {}
  }
}
