import 'package:flutter/material.dart';

import '../models/vless_node.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/vpn_engine.dart';
import 'widgets.dart';

/// 节点列表页
class NodesPage extends StatelessWidget {
  final AppState state;
  final VpnEngine vpn;

  const NodesPage({super.key, required this.state, required this.vpn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '节点列表',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: AppColors.textDim(context),
              ),
            ),
            const Spacer(),
            Text(
              '${state.nodes.length} NODES',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: AppTheme.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: state.nodes.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 2, top: 2),
                  itemCount: state.nodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final node = state.nodes[i];
                    return NodeCard(
                      node: node,
                      isSelected: state.selectedNode == node,
                      isConnected:
                          vpn.isConnected && state.selectedNode == node,
                      onTap: () => state.select(node),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hub_outlined,
              size: 40, color: AppColors.textDim(context)),
          const SizedBox(height: 14),
          Text('暂无节点',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textDim(context))),
          const SizedBox(height: 6),
          Text('前往「设置」导入订阅',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.textDim(context).withOpacity(0.7),
              )),
        ],
      ),
    );
  }
}

/// 节点卡片
class NodeCard extends StatelessWidget {
  final VlessNode node;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback onTap;

  const NodeCard({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? AppColors.strokeStrong(context) : AppColors.stroke(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.cyan.withOpacity(0.14)
              : AppColors.card(context).withOpacity(0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyan.withOpacity(isSelected ? 0.12 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左侧渐变装饰条
            Container(
              width: 4,
              margin: const EdgeInsets.only(left: 14, top: 14, bottom: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: isSelected
                      ? [AppTheme.cyan, AppTheme.purple]
                      : [
                          AppColors.textDim(context).withOpacity(0.4),
                          AppColors.textDim(context).withOpacity(0.1),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  node.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text(context),
                                  ),
                                ),
                              ),
                              if (isConnected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.green.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppTheme.green.withOpacity(0.6),
                                    ),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                      color: AppTheme.green,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.dns_outlined,
                                  size: 9,
                                  color: AppColors.textDim(context)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${node.server}:${node.port}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: AppColors.textDim(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              TechChip(text: 'VLESS', color: AppTheme.cyan),
                              TechChip(
                                text: node.transportLabel,
                                color: AppTheme.purple,
                              ),
                              TechChip(
                                text: node.fingerprint.toUpperCase(),
                                color: AppColors.textDim(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SelectionIndicator(isSelected: isSelected),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  const _SelectionIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? AppTheme.cyanDeep
              : AppColors.textDim(context).withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cyanDeep,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyan,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
