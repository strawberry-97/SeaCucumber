import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 干净渐变背景 + 柔和光斑
class TechBackground extends StatelessWidget {
  const TechBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 渐变背景
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bgTop(context),
                  AppColors.bgMid(context),
                  AppColors.bgBottom(context),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // 柔和弥散光斑
        Positioned(
          top: -160,
          left: -140,
          child: _blurCircle(AppTheme.cyan.withOpacity(0.16), 340),
        ),
        Positioned(
          bottom: -100,
          right: -120,
          child: _blurCircle(AppTheme.purple.withOpacity(0.12), 300),
        ),
        Positioned(
          bottom: -80,
          left: -120,
          child: _blurCircle(AppTheme.green.withOpacity(0.10), 240),
        ),
      ],
    );
  }

  Widget _blurCircle(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 110, spreadRadius: 0),
          ],
        ),
      );
}

/// 磨砂玻璃卡片
class TechCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double cornerRadius;

  const TechCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.cornerRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.78),
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: AppColors.stroke(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 脉冲圆点
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, required this.color, this.size = 9});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: widget.size * 2,
          height: widget.size * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * 2,
                height: widget.size * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.30 * (1 - t)),
                ),
                transform: Matrix4.identity()
                  ..scale(0.7 + 1.1 * t),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 小标签
class TechChip extends StatelessWidget {
  final String text;
  final Color color;

  const TechChip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 状态胶囊
class StatusPill extends StatelessWidget {
  final bool connected;
  final String text;

  const StatusPill({super.key, required this.connected, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppTheme.green : AppColors.textDim(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: connected
            ? AppTheme.green.withOpacity(0.12)
            : AppColors.card(context).withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: connected
              ? AppTheme.green.withOpacity(0.45)
              : AppColors.stroke(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: color, size: 5),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 发光效果包装
class SoftGlow extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const SoftGlow({
    super.key,
    required this.child,
    this.color = AppTheme.cyan,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: radius,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 自定义分段控件
class SegmentPicker<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T) titleOf;
  final ValueChanged<T> onChanged;

  const SegmentPicker({
    super.key,
    required this.items,
    required this.selected,
    required this.titleOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke(context)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: selected == item
                        ? AppTheme.connectGradient
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    titleOf(item),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected == item
                          ? Colors.white
                          : AppColors.textDim(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
