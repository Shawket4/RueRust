import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: cairo(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.7));
}

// ─────────────────────────────────────────────────────────────────────────────
//  PILL (tiny badge)
// ─────────────────────────────────────────────────────────────────────────────
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.xs)),
      child: Text(text,
          style: cairo(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  COUNT BADGE
// ─────────────────────────────────────────────────────────────────────────────
class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({super.key, required this.count});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$count',
          style: cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  SELECTABLE CHIP
// ─────────────────────────────────────────────────────────────────────────────
class SelectableChip extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final bool checkbox;
  final bool enabled;
  final VoidCallback onTap;
  final Color? accentColor;
  const SelectableChip({
    super.key,
    required this.label,
    this.sublabel,
    required this.selected,
    required this.checkbox,
    this.enabled = true,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    final isDisabled = !enabled && !selected;

    return GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: selected
                  ? accent
                  : isDisabled
                      ? AppColors.bg.withOpacity(0.6)
                      : AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                  color: selected
                      ? accent
                      : isDisabled
                          ? AppColors.border.withOpacity(0.5)
                          : AppColors.border,
                  width: selected ? 1.5 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (checkbox) ...[
              Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 14,
                  color: selected
                      ? Colors.white
                      : isDisabled
                          ? AppColors.border
                          : AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : isDisabled
                            ? AppColors.textMuted
                            : AppColors.textPrimary)),
            if (sublabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.2)
                        : accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(sublabel!,
                    style: cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : accent)),
              ),
            ],
          ]),
        ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QTY BUTTON (± inside footer)
// ─────────────────────────────────────────────────────────────────────────────
class QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const QtyBtn({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  INLINE BUTTON (small cart row ± buttons)
// ─────────────────────────────────────────────────────────────────────────────
class InlineBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const InlineBtn({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: Icon(icon, size: 13, color: AppColors.textPrimary)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  ICON BUTTON (top bar)
// ─────────────────────────────────────────────────────────────────────────────
class SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const SmallIconBtn({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIELD LABEL (checkout forms)
// ─────────────────────────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text,
      style: cairo(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2));
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.border),
          const SizedBox(height: 12),
          Text(message,
              style: cairo(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const skeletonBase = Color(0xFFEEF0F4);
const skeletonHighlight = Color(0xFFE4E7ED);
