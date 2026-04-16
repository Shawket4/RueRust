import 'package:flutter/material.dart';
import '../../../core/models/menu.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import 'shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OPTIONAL FIELDS CARD — flat list under "Optional" header
// ─────────────────────────────────────────────────────────────────────────────
class OptionalFieldsCard extends StatelessWidget {
  final List<OptionalField> fields;
  final Set<String> selected;
  final String? sizeLabel;
  final void Function(String) onToggle;

  const OptionalFieldsCard({
    super.key,
    required this.fields,
    required this.selected,
    required this.sizeLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Show only fields that match current size (or have no size restriction)
    final visible = fields
        .where((f) => f.sizeLabel == null || f.sizeLabel == sizeLabel)
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    final selCount =
        selected.where((id) => visible.any((f) => f.id == id)).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: selCount > 0
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Text('OPTIONAL',
                style: cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.7)),
            const SizedBox(width: 6),
            Pill('Optional', AppColors.primary),
            const Spacer(),
            if (selCount > 0) CountBadge(count: selCount),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: visible.map((f) {
              final sel = selected.contains(f.id);
              return GestureDetector(
                onTap: () => onToggle(f.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        sel
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 14,
                        color: sel ? Colors.white : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(f.name,
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textPrimary)),
                    if (f.hasIngredient && !sel) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.science_outlined,
                          size: 11, color: AppColors.textMuted.withOpacity(0.6)),
                    ],
                    if (!f.isFree) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: sel
                                ? Colors.white.withOpacity(0.2)
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('+${egp(f.price)}',
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.primary)),
                      ),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
