import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_type.dart';

/// 本地持久化（订阅地址 / 类型 / 外观 / 选中节点索引）
///
/// 移植自 clash-verg 的 UserDefaults 用法
class StorageService {
  static const _kSubscriptionType = 'subscriptionType';
  static const _kAppearance = 'appearance';
  static const _kClashVergeURL = 'clashVergeURL';
  static const _kShadowrocketURL = 'shadowrocketURL';
  static const _kOtherURL = 'otherURL';
  static const _kSelectedNodeName = 'selectedNodeName';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p => _prefs!;

  static SubscriptionType get subscriptionType =>
      SubscriptionType.values.firstWhere(
        (t) => t.name == _p.getString(_kSubscriptionType),
        orElse: () => SubscriptionType.clashVerge,
      );

  static set subscriptionType(SubscriptionType v) =>
      _p.setString(_kSubscriptionType, v.name);

  static AppAppearance get appearance => AppAppearance.values.firstWhere(
        (a) => a.name == _p.getString(_kAppearance),
        orElse: () => AppAppearance.system,
      );

  static set appearance(AppAppearance v) => _p.setString(_kAppearance, v.name);

  static String get clashVergeURL => _p.getString(_kClashVergeURL) ?? '';
  static set clashVergeURL(String v) => _p.setString(_kClashVergeURL, v);

  static String get shadowrocketURL => _p.getString(_kShadowrocketURL) ?? '';
  static set shadowrocketURL(String v) => _p.setString(_kShadowrocketURL, v);

  static String get otherURL => _p.getString(_kOtherURL) ?? '';
  static set otherURL(String v) => _p.setString(_kOtherURL, v);

  static String get selectedNodeName =>
      _p.getString(_kSelectedNodeName) ?? '';
  static set selectedNodeName(String v) =>
      _p.setString(_kSelectedNodeName, v);

  /// 当前订阅类型对应的 URL
  static String urlFor(SubscriptionType type) => switch (type) {
        SubscriptionType.clashVerge => clashVergeURL,
        SubscriptionType.shadowrocket => shadowrocketURL,
        SubscriptionType.other => otherURL,
      };

  static void rememberURL(SubscriptionType type, String value) {
    switch (type) {
      case SubscriptionType.clashVerge:
        clashVergeURL = value;
      case SubscriptionType.shadowrocket:
        shadowrocketURL = value;
      case SubscriptionType.other:
        otherURL = value;
    }
  }
}
