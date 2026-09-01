import 'package:flutter/material.dart';

import '../models/subscription_type.dart';
import '../services/file_service.dart';
import '../services/vpn_engine.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

/// 设置页（订阅管理 + 外观 + 信息 + 网络规则）
class SettingsPage extends StatelessWidget {
  final AppState state;
  final VpnEngine vpn;

  const SettingsPage({super.key, required this.state, required this.vpn});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        _SubscriptionCard(state: state, vpn: vpn),
        const SizedBox(height: 12),
        _AppearanceCard(state: state),
        const SizedBox(height: 12),
        _InfoCard(state: state),
        const SizedBox(height: 12),
        const _AboutCard(),
        const SizedBox(height: 12),
        const _RulesCard(),
      ],
    );
  }
}

// MARK: - 订阅

class _SubscriptionCard extends StatelessWidget {
  final AppState state;
  final VpnEngine vpn;

  const _SubscriptionCard({required this.state, required this.vpn});

  @override
  Widget build(BuildContext context) {
    return TechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '订阅', Icons.link),
          const SizedBox(height: 12),
          SegmentPicker<SubscriptionType>(
            items: SubscriptionType.values,
            selected: state.subscriptionType,
            titleOf: (t) => t.title,
            onChanged: state.setSubscriptionType,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subscriptionController(state),
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '粘贴订阅地址（首次使用需输入）',
              hintStyle: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.textDim(context),
              ),
              filled: true,
              fillColor: AppColors.card(context).withOpacity(0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.stroke(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.stroke(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.cyanDeep),
              ),
            ),
            onChanged: state.updateSubscriptionURL,
          ),
          const SizedBox(height: 12),
          _GradientButton(
            label: state.isImporting ? '正在导入…' : '导入订阅',
            icon: state.isImporting ? null : Icons.download_rounded,
            loading: state.isImporting,
            onTap: () async {
              if (vpn.isConnected) {
                await _confirmDisconnectAndImport(context);
              } else {
                await state.importSubscription();
              }
            },
          ),
        ],
      ),
    );
  }

  /// 断开并导入（有连接时需要先断开，网络才能直连）
  Future<void> _confirmDisconnectAndImport(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要断开 VPN'),
        content: const Text('导入订阅会更新节点配置，需先断开当前 VPN。断开后请手动重新连接。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('断开并导入',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await vpn.disconnect();
      await Future.delayed(const Duration(milliseconds: 800));
      await state.importSubscription();
    }
  }

  /// 订阅地址输入框控制器（切换类型时内容跟随变化）
  TextEditingController _subscriptionController(AppState state) {
    // 用一次性控制器即可，onChanged 同步回 state
    final c = TextEditingController(text: state.currentSubscriptionURL);
    c.addListener(() {
      if (c.text != state.currentSubscriptionURL) {
        state.updateSubscriptionURL(c.text);
      }
    });
    return c;
  }
}

// MARK: - 外观

class _AppearanceCard extends StatelessWidget {
  final AppState state;
  const _AppearanceCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return TechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '外观', Icons.contrast),
          const SizedBox(height: 12),
          SegmentPicker<AppAppearance>(
            items: AppAppearance.values,
            selected: state.appearance,
            titleOf: (a) => a.title,
            onChanged: state.setAppearance,
          ),
        ],
      ),
    );
  }
}

// MARK: - 信息

class _InfoCard extends StatelessWidget {
  final AppState state;
  const _InfoCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return TechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '信息', Icons.info_outline),
          const SizedBox(height: 10),
          _infoRow(context, '节点数量', '${state.nodes.length}'),
          _infoRow(context, '当前节点', state.selectedNode?.name ?? '—'),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await FileService.writeDiagnostic(
                  nodesCount: state.nodes.length,
                  selectedNode: state.selectedNode?.name,
                  subscriptionTitle: state.subscriptionType.title,
                );
                state.showMessage('诊断已写入应用文档目录');
              },
              icon: const Icon(Icons.monitor_heart_outlined,
                  size: 16, color: AppTheme.cyanDeep),
              label: const Text(
                '写入诊断文件',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cyanDeep),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: - 关于

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return TechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '关于', Icons.memory),
          const SizedBox(height: 10),
          _infoRow(context, '版本', '0.1.0'),
          _infoRow(context, '核心', 'sing-box'),
          _infoRow(context, '模式', '分流直连'),
        ],
      ),
    );
  }
}

// MARK: - 网络规则

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return TechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, '网络规则', Icons.alt_route),
          const SizedBox(height: 10),
          _ruleRow(context, '国内网站（域名）', '直连'),
          _ruleRow(context, '国内 IP', '直连'),
          _ruleRow(context, '局域网 / 私有地址', '直连'),
          _ruleRow(context, '其他（国外）', '代理', highlight: true),
          Divider(color: AppColors.stroke(context)),
          _sectionHeader(context, 'DNS 解析', Icons.public),
          const SizedBox(height: 10),
          _ruleRow(context, '国内域名', '本地解析'),
          _ruleRow(context, '其他', '远程解析'),
        ],
      ),
    );
  }
}

// MARK: - 通用组件

Widget _sectionHeader(BuildContext context, String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 11, color: AppTheme.cyanDeep),
      const SizedBox(width: 6),
      Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          color: AppColors.text(context),
        ),
      ),
    ],
  );
}

Widget _infoRow(BuildContext context, String key, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(key,
            style: TextStyle(fontSize: 12, color: AppColors.textDim(context))),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.text(context),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _ruleRow(BuildContext context, String key, String value,
    {bool highlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(key,
            style: TextStyle(fontSize: 12, color: AppColors.textDim(context))),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: highlight ? AppTheme.cyanDeep : AppColors.text(context),
          ),
        ),
      ],
    ),
  );
}

/// 渐变按钮
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    this.icon,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.connectGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
