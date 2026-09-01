import 'package:flutter/material.dart';

import '../models/subscription_type.dart';
import '../services/config_generator.dart';
import '../services/file_service.dart';
import '../services/vpn_engine.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'nodes_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

/// 主页面：连接卡 + 底部标签栏
class HomePage extends StatefulWidget {
  final AppState state;
  final VpnEngine vpn;

  const HomePage({super.key, required this.state, required this.vpn});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _showToast = false;
  int _toastToken = 0;

  AppState get state => widget.state;
  VpnEngine get vpn => widget.vpn;

  bool get busy => vpn.isBusy;

  @override
  void initState() {
    super.initState();
    // 监听状态变化，显示消息
    state.addListener(_onStateChanged);
    vpn.status.addListener(_onVpnStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.autoImportIfNeeded();
    });
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    vpn.status.removeListener(_onVpnStatusChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (state.message.isNotEmpty) _showMessage(state.message);
  }

  void _onVpnStatusChanged() {}

  void _showMessage(String text) {
    _toastToken++;
    final token = _toastToken;
    setState(() => _showToast = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (token == _toastToken && mounted) {
        setState(() => _showToast = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appearance = state.appearance;
    final themeMode = switch (appearance) {
      AppAppearance.system => ThemeMode.system,
      AppAppearance.light => ThemeMode.light,
      AppAppearance.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'SC VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      // 用 Builder 拿到 MaterialApp 之下的 context，
      // 否则 _buildHome 里的 AppColors.adaptive 永远读到浅色主题，
      // 深色模式下标题/卡片文字会变成深字压深底。
      home: Builder(builder: (context) => _buildHome(context)),
    );
  }

  Widget _buildHome(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const TechBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  _header(context),
                  const SizedBox(height: 14),
                  _connectCard(context),
                  const SizedBox(height: 14),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _tab == 0
                          ? NodesPage(state: state, vpn: vpn)
                          : SettingsPage(state: state, vpn: vpn),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _tabBar(context),
                ],
              ),
            ),
          ),
          if (_showToast && state.message.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 104,
              child: _toast(context),
            ),
        ],
      ),
    );
  }

  // MARK: - 顶部

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Text(
          'SC VPN',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.text(context),
          ),
        ),
        const Spacer(),
        StatusPill(connected: vpn.isConnected, text: vpn.status.value.label),
      ],
    );
  }

  // MARK: - 连接卡片

  Widget _connectCard(BuildContext context) {
    final connected = vpn.isConnected;
    final statusColor = connected ? AppTheme.green : AppColors.textDim(context);

    return TechCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vpn.status.value.label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.selectedNode?.name ?? '未选择节点',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: AppColors.textDim(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: statusColor.withOpacity(0.22), width: 2),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: statusColor.withOpacity(0.5), width: 1),
                      ),
                    ),
                    PulseDot(color: statusColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: busy ? null : _toggleConnection,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: connected
                    ? AppTheme.disconnectGradient
                    : AppTheme.connectGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (connected ? AppTheme.green : AppTheme.cyan)
                        .withOpacity(0.35),
                    blurRadius: 9,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.power_settings_new,
                        size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _connectButtonTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _connectButtonTitle {
    if (busy) return '处理中…';
    return vpn.isConnected ? '断开连接' : '建立连接';
  }

  Future<void> _toggleConnection() async {
    if (state.selectedNode == null) {
      state.showMessage('请先在「设置」导入订阅并选择节点');
      return;
    }
    try {
      if (vpn.isConnected) {
        await vpn.disconnect();
      } else {
        // Android 需要先请求 VPN 权限
        final granted = await vpn.prepare();
        if (!granted) {
          state.showMessage('未授予 VPN 权限');
          return;
        }
        await FileService.ensureRuleSets();
        await FileService.log('connect requested');
        final config = ConfigGenerator.makeConfig(state.selectedNode!);
        await vpn.connect(config);
        await Future.delayed(const Duration(seconds: 2));
        await vpn.refreshStatus();
      }
    } catch (e) {
      final log = await vpn.readLog();
      final extra = log.isEmpty ? '' : '\n$log';
      state.showMessage('连接失败：$e$extra');
    }
  }

  // MARK: - TabBar

  Widget _tabBar(BuildContext context) {
    const tabs = [
      (Icons.hub_outlined, '节点'),
      (Icons.settings_outlined, '设置'),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                // 未选中的 tab 没有 decoration，Container 会塌陷到图标/文字大小，
                // 默认 deferToChild 会导致只能点到图标。改为 opaque 让整个区域可点。
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: _tab == i
                      ? BoxDecoration(
                          color: AppTheme.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppTheme.cyan.withOpacity(0.4)),
                        )
                      : null,
                  child: Column(
                    children: [
                      Icon(tabs[i].$1,
                          size: 18,
                          color: _tab == i
                              ? AppTheme.cyan
                              : AppColors.textDim(context)),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _tab == i
                              ? AppTheme.cyan
                              : AppColors.textDim(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // MARK: - Toast

  Widget _toast(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardHi(context).withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.strokeStrong(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withOpacity(0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info, size: 16, color: AppTheme.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 12, color: AppColors.text(context)),
            ),
          ),
        ],
      ),
    );
  }
}
