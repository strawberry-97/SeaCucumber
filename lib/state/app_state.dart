import 'package:flutter/foundation.dart';

import '../models/subscription_type.dart';
import '../models/vless_node.dart';
import '../services/clash_parser.dart';
import '../services/config_generator.dart';
import '../services/file_service.dart';
import '../services/shadowrocket_parser.dart';
import '../services/storage_service.dart';
import '../services/subscription_loader.dart';

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

  bool _didAutoImport = false;

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
    notifyListeners();
  }

  /// 进入 app 时自动导入一次订阅（若本地已记住链接）
  Future<void> autoImportIfNeeded() async {
    if (_didAutoImport) return;
    _didAutoImport = true;
    if (currentSubscriptionURL.trim().isEmpty) return;
    await importSubscription();
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
    selectedNode = parsed.first;
    await FileService.ensureRuleSets();
    await FileService.writeConfig(
      ConfigGenerator.makeConfig(parsed.first),
    );
    StorageService.selectedNodeName = parsed.first.name;
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

  /// 选中节点并写入配置
  Future<void> select(VlessNode node) async {
    selectedNode = node;
    StorageService.selectedNodeName = node.name;
    await FileService.ensureRuleSets();
    final ok = await FileService.writeConfig(ConfigGenerator.makeConfig(node));
    if (!ok) {
      message = '写入配置失败，请重试';
    }
    notifyListeners();
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
