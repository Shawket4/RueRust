import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BtnVariant { primary, danger, outline, ghost }

class AppButton extends StatefulWidget {
  final String        label;
  final VoidCallback? onTap;
  final bool          loading;
  final BtnVariant    variant;
  final double?       width;
  final IconData?     icon;
  final double        height;

  const AppButton({
    super.key, required this.label, this.onTap, this.loading = false,
    this.variant = BtnVariant.primary, this.width, this.icon, this.height = 48,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _enabled => !widget.loading && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (widget.variant) {
      BtnVariant.primary => (AppColors.primary,       Colors.white),
      BtnVariant.danger  => (AppColors.danger,          Colors.white),
      BtnVariant.outline => (Colors.transparent,        AppColors.primary),
      BtnVariant.ghost   => (Colors.transparent,        AppColors.textSecondary),
    };
    final hasBorder = widget.variant == BtnVariant.outline;

    return GestureDetector(
      onTapDown:   (_) { if (_enabled) _ctrl.forward(); },
      onTapUp:     (_) { if (_enabled) { _ctrl.reverse(); widget.onTap!(); } },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: widget.width, height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color:        _enabled ? bg : bg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: hasBorder
                  ? Border.all(color: AppColors.primary) : null,
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 17, color: fg),
                      const SizedBox(width: 7),
                    ],
                    Text(widget.label,
                        style: cairo(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
                  ]),
          ),
        ),
      ),
    );
  }
}
