import 'package:flutter/material.dart';

/// 轻玻璃拟态配色（与 clash-verg 的 Theme.swift 一致）
///
/// 主色：浅冰青蓝 `#87D8F5`
class AppTheme {
  static const Color cyan = Color(0xFF87D8F5);
  static const Color cyanDeep = Color(0xFF4FC3F0);
  static const Color blue = Color(0xFF6FB3E8);
  static const Color green = Color(0xFF5FD9C0);
  static const Color purple = Color(0xFFA9A6F0);
  static const Color danger = Color(0xFFF08B9B);

  // 浅色
  static const Color _lightBgTop = Color(0xFFFBFDFE);
  static const Color _lightBgMid = Color(0xFFF3F8FB);
  static const Color _lightBgBottom = Color(0xFFEAF3F8);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightCardHi = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF2A3440);
  static const Color _lightTextDim = Color(0xFF7B8996);
  static const Color _lightLogText = Color(0xFF3A7D6E);

  // 深色
  static const Color _darkBgTop = Color(0xFF151D27);
  static const Color _darkBgMid = Color(0xFF1A2430);
  static const Color _darkBgBottom = Color(0xFF213041);
  static const Color _darkCard = Color(0xFF233140);
  static const Color _darkCardHi = Color(0xFF2B3B4D);
  static const Color _darkText = Color(0xFFE7EDF3);
  static const Color _darkTextDim = Color(0xFF8E9BA8);
  static const Color _darkLogText = Color(0xFF8FD0C3);

  static const LinearGradient connectGradient = LinearGradient(
    colors: [Color(0xFF38AEE0), cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient disconnectGradient = LinearGradient(
    colors: [Color(0xFF3FC9B0), Color(0xFF8FE0D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [cyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 根据亮度取色
  static Color adaptive(
    BuildContext context, {
    required Color light,
    required Color dark,
  }) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  static ThemeData lightTheme() => _build(Brightness.light);
  static ThemeData darkTheme() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyan,
        brightness: brightness,
      ),
      fontFamily: 'PingFang SC',
    );
  }
}

/// 主题色快捷访问
class AppColors {
  static Color bgTop(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightBgTop, dark: AppTheme._darkBgTop);
  static Color bgMid(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightBgMid, dark: AppTheme._darkBgMid);
  static Color bgBottom(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightBgBottom, dark: AppTheme._darkBgBottom);
  static Color card(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightCard, dark: AppTheme._darkCard);
  static Color cardHi(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightCardHi, dark: AppTheme._darkCardHi);
  static Color text(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightText, dark: AppTheme._darkText);
  static Color textDim(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightTextDim, dark: AppTheme._darkTextDim);
  static Color logText(BuildContext c) => AppTheme.adaptive(c,
      light: AppTheme._lightLogText, dark: AppTheme._darkLogText);
  static Color stroke(BuildContext c) => AppTheme.cyan.withOpacity(0.35);
  static Color strokeStrong(BuildContext c) => AppTheme.cyan.withOpacity(0.7);
}
