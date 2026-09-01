import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/file_service.dart';
import '../theme/app_theme.dart';

/// 隧道日志页（终端风格）
class LogsPage extends StatefulWidget {
  final ValueChanged<String> onMessage;

  const LogsPage({super.key, required this.onMessage});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String _log = '';
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final log = await FileService.readLog();
    if (mounted) setState(() => _log = log);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _log.isEmpty ? '> 暂无日志' : _log;
    final lineCount = _log.isEmpty ? 0 : _log.split('\n').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '隧道日志',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: AppColors.textDim(context),
              ),
            ),
            const Spacer(),
            _toolbarButton(context, '刷新', Icons.refresh, _refresh),
            const SizedBox(width: 8),
            _toolbarButton(context, '复制', Icons.copy, () async {
              await _refresh();
              await Clipboard.setData(ClipboardData(text: text));
              widget.onMessage(_log.isEmpty ? '日志为空' : '已复制到剪贴板');
            }),
            const SizedBox(width: 8),
            _toolbarButton(context, '清空', Icons.delete_outline, () async {
              await FileService.clearLog();
              await _refresh();
              widget.onMessage('日志已清空');
            }),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _terminal(context, text, lineCount)),
      ],
    );
  }

  Widget _terminal(BuildContext context, String text, int lineCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card(context).withOpacity(0.45),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const _Dot(color: Color(0xFFFF5A5A)),
                const SizedBox(width: 5),
                const _Dot(color: Color(0xFFFFBF40)),
                const SizedBox(width: 5),
                const _Dot(color: Color(0xFF4DD964)),
                const Spacer(),
                Text('tunnel.log',
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppColors.textDim(context))),
                const Spacer(),
                Text('$lineCount LINES',
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppColors.textDim(context))),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.stroke(context)),
          // 日志内容
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.logText(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton(BuildContext context, String title, IconData icon,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardHi(context).withOpacity(0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.stroke(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 10, color: AppTheme.cyanDeep),
            const SizedBox(width: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cyanDeep)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
