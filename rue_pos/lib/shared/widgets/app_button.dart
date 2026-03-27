import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BtnVariant { primary, danger, outline, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final BtnVariant variant;
  final double? width;
  final IconData? icon;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.variant = BtnVariant.primary,
    this.width,
    this.icon,
    this.height = 50,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _enabled => !widget.loading && widget.onTap != null;

  Color get _bg => switch (widget.variant) {
        BtnVariant.primary => AppColors.primary,
        BtnVariant.danger => AppColors.danger,
        BtnVariant.outline => Colors.transparent,
        BtnVariant.ghost => Colors.transparent,
      };

  Color get _fg => switch (widget.variant) {
        BtnVariant.primary => Colors.white,
        BtnVariant.danger => Colors.white,
        BtnVariant.outline => AppColors.primary,
        BtnVariant.ghost => AppColors.textSecondary,
      };

  List<BoxShadow> get _shadows {
    if (!_enabled) return [];
    return switch (widget.variant) {
      BtnVariant.primary => AppShadows.primaryGlow(),
      BtnVariant.danger => [
          BoxShadow(
              color: AppColors.danger.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      _ => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasBorder = widget.variant == BtnVariant.outline;

    return GestureDetector(
      onTapDown: (_) {
        if (_enabled) _ctrl.forward();
      },
      onTapUp: (_) {
        if (_enabled) {
          _ctrl.reverse();
          widget.onTap!();
        }
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _enabled ? _bg : _bg.withOpacity(0.45),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: hasBorder
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
              boxShadow: _enabled ? _shadows : [],
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2.5, color: _fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 17, color: _fg),
                      const SizedBox(width: 8),
                    ],
                    Text(widget.label,
                        style: cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _fg)),
                  ]),
          ),
        ),
      ),
    );
  }
}
