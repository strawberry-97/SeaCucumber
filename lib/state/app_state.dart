import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/subscription_type.dart';
import '../models/vless_node.dart';
import '../services/clash_parser.dart';
import '../services/config_generator.dart';
import '../services/file_service.dart';
import '../services/shadowrocket_parser.dart';
import '../services/storage_service.dart';
import '../services/subscription_loader.dart';
import '../services/vpn_engine.dart';

/// 应用状态（节点 / 订阅 / 外观 / 导入）
///
/// 移植自 clash-verg 的 AppState.swift
class AppState extends ChangeNotifier {
  List<VlessNode> nodes = [];
  VlessNode? selectedNode;

  SubscriptionType subscriptionType = SubscriptionType.clashVerge;
  AppAppearance appearance = AppAppearance.system;

  String clashVergeURL = '';
  String shadowrocketURL = '';
  String otherURL = '';

  bool isImporting = false;
  String message = '';

  /// 默认一直连接：启动自动连、断线自动重连
  bool autoConnect = true;

  /// 期望的连接状态（用户主动连接或自动连接后为 true；主动断开后为 false）
  bool desiredConnected = false;

  /// 是否已挂上状态看护
  bool _watchAttached = false;
  bool _inProgress = false;
  bool _didAutoImport = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  VpnEngine get vpn => VpnEngine.instance;

  /// 当前订阅类型对应的 URL
  String get currentSubscriptionURL => switch (subscriptionType) {
        SubscriptionType.clashVerge => clashVergeURL,
        SubscriptionType.shadowrocket => shadowrocketURL,
        SubscriptionType.other => otherURL,
      };

  /// 从本地存储恢复状态
  Future<void> load() async {
    subscriptionType = StorageService.subscriptionType;
    appearance = StorageService.appearance;
    clashVergeURL = StorageService.clashVergeURL;
    shadowrocketURL = StorageService.shadowrocketURL;
    otherURL = StorageService.otherURL;
    autoConnect = StorageService.autoConnect;
    notifyListeners();
  }

  /// 挂上连接看护：隧道掉线且仍处于「应连接」状态时自动重连
  void attachConnectionWatch() {
    if (_watchAttached) return;
    _watchAttached = true;
    vpn.status.addListener(_onVpnStatusChanged);
    // 单例常驻，不主动摘除监听
  }

  void _onVpnStatusChanged() {
    switch (vpn.status.value) {
      case VpnStatus.connected:
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _reconnectAttempt = 0;
      case VpnStatus.disconnected:
      case VpnStatus.error:
        if (autoConnect && desiredConnected) _scheduleReconnect();
      default:
        break;
    }
  }

  /// 指数退避重连（3s 起，最多 30s，持续尝试）
  void _scheduleReconnect() {
    if (!autoConnect || !desiredConnected) return;
    if (_inProgress) return;
    if (_reconnectTimer?.isActive ?? false) return;
    const ladder = [3, 5, 8, 12, 20, 30];
    final idx = _reconnectAttempt.clamp(0, ladder.length - 1);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: ladder[idx]), () {
      _reconnectTimer = null;
      if (autoConnect && desiredConnected) ensureConnected(silent: true);
    });
  }

  /// 进入 app 时自动导入一次订阅（若本地已记住链接）
  Future<void> autoImportIfNeeded() async {
    if (_didAutoImport) return;
    _didAutoImport = true;
    if (currentSubscriptionURL.trim().isEmpty) return;
    await importSubscription();
  }

  /// 「一直连接」入口：满足条件（autoConnect 且已有配置）就建立连接
  Future<void> ensureConnected({bool silent = true}) async {
    if (!autoConnect) return;
    if (vpn.isConnected || vpn.isBusy) return;
    desiredConnected = true;
    await _doConnect(silent: silent);
  }

  /// 用户点击「建立连接」
  Future<void> connectByUser() async {
    desiredConnected = true;
    _reconnectAttempt = 0;
    if (vpn.isConnected || vpn.isBusy) {
      // 已连接：把最新配置热重载进隧道（切换节点后调用）
      await _doConnect(silent: false);
      return;
    }
    await _doConnect(silent: false);
  }

  /// 用户点击「断开连接」
  Future<void> disconnectByUser() async {
    desiredConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    await vpn.disconnect();
    notifyListeners();
  }

  /// 真正发起连接（配置优先取当前节点，其次取上次写入的 config.json）
  Future<void> _doConnect({bool silent = false}) async {
    if (_inProgress) return;
    _inProgress = true;
    try {
      await _doConnectInner(silent: silent);
    } finally {
      _inProgress = false;
    }
  }

  Future<void> _doConnectInner({bool silent = false}) async {
    var config = selectedNode != null
        ? ConfigGenerator.makeConfig(selectedNode!)
        : await FileService.readConfig();

    if (config == null || config.trim().isEmpty) {
      desiredConnected = false;
      if (!silent) {
        message = '请先在「设置」导入订阅并选择节点';
        notifyListeners();
      }
      return;
    }

    try {
      final granted = await vpn.prepare();
      if (!granted) {
        message = '未授予 VPN 权限';
        notifyListeners();
        return;
      }
      await FileService.ensureRuleSets();

      // 已连接且配置没变（比如启动时先用缓存配置连上、随后导入解析出同一节点）：
      // 直接跳过，避免无意义的隧道重启
      if (vpn.isConnected && config.trim() == (await FileService.readConfig())?.trim()) {
        await vpn.refreshStatus();
        if (!silent) notifyListeners();
        return;
      }

      // 已连接（如换节点）：先断开，再按新配置重建隧道
      if (vpn.isConnected || vpn.isBusy) {
        await vpn.disconnect();
        await Future.delayed(const Duration(milliseconds: 1500));
        await vpn.refreshStatus();
      }

      await FileService.log(
          'connect requested (auto=$autoConnect silent=$silent node=${selectedNode?.name})');
      await vpn.connect(config);
      await Future.delayed(const Duration(seconds: 2));
      await vpn.refreshStatus();
      if (vpn.isConnected) {
        _reconnectAttempt = 0;
        final alwaysOn = await vpn.isAlwaysOn();
        await FileService.log('connected; alwaysOn=$alwaysOn node=${selectedNode?.name}');
        if (!silent) message = '已连接';
        notifyListeners();
      } else {
        _scheduleReconnect();
      }
    } catch (e) {
      final log = await vpn.readLog();
      final extra = log.isEmpty ? '' : '\n$log';
      message = '连接失败：$e$extra';
      notifyListeners();
      await FileService.log('connect failed: $e');
      _scheduleReconnect();
    }
  }

  void setAutoConnect(bool value) {
    autoConnect = value;
    StorageService.autoConnect = value;
    if (value) {
      ensureConnected();
    } else {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempt = 0;
    }
    notifyListeners();
  }

  /// 下载并解析订阅
  Future<void> importSubscription() async {
    final urlString = currentSubscriptionURL.trim();
    if (urlString.isEmpty) {
      message = '请先输入订阅地址';
      notifyListeners();
      return;
    }
    final uri = Uri.tryParse(urlString);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      message = '订阅地址无效';
      notifyListeners();
      return;
    }

    isImporting = true;
    notifyListeners();
    try {
      await FileService.log('importSubscription url=$urlString type=${subscriptionType.name}');
      final raw = await SubscriptionLoader.download(
        url: uri,
        type: subscriptionType,
      );

      final List<VlessNode> parsed = switch (subscriptionType) {
        SubscriptionType.clashVerge => ClashParser.parseNodes(raw),
        SubscriptionType.shadowrocket => ShadowrocketParser.parseNodes(raw),
        SubscriptionType.other => _detectAndParse(raw),
      };

      StorageService.rememberURL(subscriptionType, urlString);
      await _applyParsedNodes(parsed);
      await autoConnectAfterImport();
    } on SubscriptionException catch (e) {
      message = '导入失败：${e.message}';
      debugPrint('importSubscription failed: ${e.message}');
      await FileService.log('importSubscription failed: ${e.message}');
    } catch (e) {
      message = '导入失败：$e';
      debugPrint('importSubscription failed: $e');
      await FileService.log('importSubscription failed: $e');
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  /// 从本地文件导入订阅内容（订阅服务器不可直连时用）
  Future<void> importLocalSubscription() async {
    final raw = await FileService.readLocalSub();
    if (raw == null || raw.trim().isEmpty) {
      message = '未找到本地订阅文件';
      notifyListeners();
      return;
    }
    await FileService.log(
        'importLocalSubscription type=${subscriptionType.name} len=${raw.length}');
    await importRawContent(raw);
  }

  /// 直接导入订阅内容（YAML / base64 列表）
  Future<void> importRawContent(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      message = '订阅内容为空';
      notifyListeners();
      return;
    }
    isImporting = true;
    notifyListeners();
    try {
      final List<VlessNode> parsed = switch (subscriptionType) {
        SubscriptionType.clashVerge => ClashParser.parseNodes(trimmed),
        SubscriptionType.shadowrocket => ShadowrocketParser.parseNodes(trimmed),
        SubscriptionType.other => _detectAndParse(trimmed),
      };
      await _applyParsedNodes(parsed);
      await autoConnectAfterImport();
    } catch (e) {
      message = '导入失败：$e';
      debugPrint('importRawContent failed: $e');
      await FileService.log('importRawContent failed: $e');
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }

  /// 解析成功后写入节点与配置
  Future<void> _applyParsedNodes(List<VlessNode> parsed) async {
    if (parsed.isEmpty) {
      message = '未解析到节点';
      return;
    }

    nodes = parsed;
    // 优先沿用上次选中的节点，找不到再退回第一个
    final remembered = StorageService.selectedNodeName;
    selectedNode = parsed.firstWhere(
      (n) => n.name == remembered,
      orElse: () => parsed.first,
    );
    await FileService.ensureRuleSets();
    await FileService.writeConfig(
      ConfigGenerator.makeConfig(selectedNode!),
    );
    StorageService.selectedNodeName = selectedNode!.name;
    message = '导入成功';
    await FileService.writeDiagnostic(
      nodesCount: nodes.length,
      selectedNode: selectedNode?.name,
      subscriptionTitle: subscriptionType.title,
    );
  }

  /// 「其它」类型：自动识别订阅格式（Clash YAML / 小火箭 base64 列表）
  static List<VlessNode> _detectAndParse(String raw) {
    if (raw.contains('proxies:')) {
      return ClashParser.parseNodes(raw);
    }
    return ShadowrocketParser.parseNodes(raw);
  }

  /// 导入后自动建立连接（一直连接模式）
  Future<void> autoConnectAfterImport() async {
    if (!autoConnect) return;
    await ensureConnected(silent: true);
  }

  /// 选中节点并写入配置；已连接时热重载配置（保持一直连接）
  Future<void> select(VlessNode node) async {
    selectedNode = node;
    StorageService.selectedNodeName = node.name;
    await FileService.ensureRuleSets();
    final ok = await FileService.writeConfig(ConfigGenerator.makeConfig(node));
    if (!ok) {
      message = '写入配置失败，请重试';
    }
    notifyListeners();

    // 一直连接模式下换节点不必手动重连，直接把新配置推给隧道
    if (autoConnect && (desiredConnected || vpn.isConnected)) {
      desiredConnected = true;
      await _doConnect(silent: true);
    }
  }

  /// 更新当前订阅类型对应的 URL
  void updateSubscriptionURL(String value) {
    switch (subscriptionType) {
      case SubscriptionType.clashVerge:
        clashVergeURL = value;
      case SubscriptionType.shadowrocket:
        shadowrocketURL = value;
      case SubscriptionType.other:
        otherURL = value;
    }
    FileService.log('updateSubscriptionURL type=${subscriptionType.name} value=$value');
    notifyListeners();
  }

  void setSubscriptionType(SubscriptionType t) {
    subscriptionType = t;
    StorageService.subscriptionType = t;
    notifyListeners();
  }

  void setAppearance(AppAppearance a) {
    appearance = a;
    StorageService.appearance = a;
    notifyListeners();
  }

  void showMessage(String msg) {
    message = msg;
    notifyListeners();
  }
}
