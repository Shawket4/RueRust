import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final String pin;
  final int maxLength;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const PinPad({
    super.key,
    required this.pin,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final keySize = isTablet ? 76.0 : 68.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── PIN dots ──────────────────────────────────────────────────────────
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(maxLength, (i) {
          final filled = i < pin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: filled ? 14 : 12,
            height: filled ? 14 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: filled ? AppColors.primary : AppColors.border,
                width: 2,
              ),
              boxShadow: filled ? AppShadows.primaryGlow() : [],
            ),
          );
        }),
      ),
      const SizedBox(height: 32),

      // ── Keys ──────────────────────────────────────────────────────────────
      ..._rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((k) {
                if (k.isEmpty) {
                  return SizedBox(
                      width: keySize,
                      height: keySize,
                      child: const SizedBox.shrink());
                }
                return _Key(
                  label: k,
                  size: keySize,
                  onTap: () => k == '⌫' ? onBackspace() : onDigit(k),
                  isBack: k == '⌫',
                );
              }).toList(),
            ),
          )),
    ]);
  }
}

class _Key extends StatefulWidget {
  final String label;
  final double size;
  final VoidCallback onTap;
  final bool isBack;

  const _Key({
    required this.label,
    required this.size,
    required this.onTap,
    this.isBack = false,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pressed
                    ? AppColors.primary.withOpacity(0.06)
                    : AppColors.surface,
                border: Border.all(
                  color: _pressed
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: _pressed ? [] : AppShadows.card,
              ),
              alignment: Alignment.center,
              child: widget.isBack
                  ? Icon(Icons.backspace_outlined,
                      size: 20, color: AppColors.textSecondary)
                  : Text(
                      widget.label,
                      style: cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _pressed
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      );
}
