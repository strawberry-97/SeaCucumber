/// 订阅协议风格（与 clash-verg 的 SubscriptionType 保持一致）
enum SubscriptionType {
  clashVerge,
  shadowrocket,
  other;

  String get title => switch (this) {
        SubscriptionType.clashVerge => 'Clash Verge',
        SubscriptionType.shadowrocket => '小火箭',
        SubscriptionType.other => '其它',
      };

  String get userAgent => switch (this) {
        SubscriptionType.clashVerge => 'clash-verge/2.5.1',
        SubscriptionType.shadowrocket => 'Shadowrocket/2.2.12',
        SubscriptionType.other =>
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      };

  String get acceptHeader => switch (this) {
        SubscriptionType.clashVerge => 'application/yaml, text/yaml, */*',
        SubscriptionType.shadowrocket => 'text/plain, */*',
        SubscriptionType.other => '*/*',
      };
}

/// 外观模式
enum AppAppearance {
  system,
  light,
  dark;

  String get title => switch (this) {
        AppAppearance.system => '跟随系统',
        AppAppearance.light => '浅色',
        AppAppearance.dark => '深色',
      };
}
