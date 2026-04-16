import 'package:flutter/material.dart';
import '../../../core/models/menu.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../helpers/payment_helpers.dart';
import 'shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ADDON CARD  — one per addon type (slotted or unslotted)
// ─────────────────────────────────────────────────────────────────────────────
class AddonCard extends StatefulWidget {
  final String title;
  final bool isRequired;
  final bool isMulti;
  final int? maxSelections;
  final List<AddonItem> items;
  final String? selectedSingle;
  final Map<String, int> selectedMulti;
  final void Function(String) onToggleSingle;
  final void Function(String) onToggleMulti;
  final void Function(String) onIncrement;
  final void Function(String) onDecrement;
  final Color? accentColor;

  const AddonCard({
    super.key,
    required this.title,
    required this.isRequired,
    required this.isMulti,
    required this.maxSelections,
    required this.items,
    required this.selectedSingle,
    required this.selectedMulti,
    required this.onToggleSingle,
    required this.onToggleMulti,
    required this.onIncrement,
    required this.onDecrement,
    this.accentColor,
  });

  @override
  State<AddonCard> createState() => _AddonCardState();
}

class _AddonCardState extends State<AddonCard> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isSelected(String id) => widget.selectedMulti.containsKey(id);

  int _qty(String id) => widget.selectedMulti[id] ?? 1;

  int get _selCount {
    if (!widget.isMulti) return widget.selectedSingle != null ? 1 : 0;
    return widget.selectedMulti.length;
  }

  bool get _atMax =>
      widget.isMulti &&
      widget.maxSelections != null &&
      _selCount >= widget.maxSelections!;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;
    final showSearch = widget.items.length > 5;
    final opts = _query.isEmpty
        ? widget.items
        : widget.items
            .where((o) => o.name.toLowerCase().contains(_query))
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: _selCount > 0
                ? accent.withOpacity(0.25)
                : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(
                child: Row(children: [
              // Type color dot
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: accent, shape: BoxShape.circle),
              ),
              Text(widget.title.toUpperCase(),
                  style: cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.7)),
              const SizedBox(width: 6),
              if (widget.isRequired) Pill('Required', AppColors.danger),
              if (widget.isMulti) ...[
                const SizedBox(width: 4),
                Pill('Multi', accent),
              ],
              if (widget.maxSelections != null) ...[
                const SizedBox(width: 4),
                Pill('Max ${widget.maxSelections}', AppColors.textSecondary),
              ],
            ])),
            if (_selCount > 0) CountBadge(count: _selCount),
          ]),
        ),

        // Search
        if (showSearch) ...[
          const SizedBox(height: 10),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: AppColors.border)),
                child: TextField(
                    controller: _searchCtrl,
                    style: cairo(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search options…',
                      hintStyle:
                          cairo(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 15, color: AppColors.textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: _searchCtrl.clear,
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: AppColors.textMuted))
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      isDense: true,
                      filled: false,
                    )),
              )),
        ],

        // Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: opts.isEmpty
              ? Text('No match for "$_query"',
                  style: cairo(fontSize: 12, color: AppColors.textMuted))
              : Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: opts.map((opt) {
                    final sel = widget.isMulti
                        ? _isSelected(opt.id)
                        : widget.selectedSingle == opt.id;
                    final qty = _qty(opt.id);

                    // Multi-select selected chip: show qty stepper inline
                    if (widget.isMulti && sel) {
                      return QtyChip(
                        label: normaliseName(opt.name),
                        price: opt.defaultPrice,
                        qty: qty,
                        accentColor: accent,
                        onIncrement: () => widget.onIncrement(opt.id),
                        onDecrement: () => widget.onDecrement(opt.id),
                      );
                    }

                    // Disable unselected chips when at max
                    final canSelect = !_atMax || sel;

                    return SelectableChip(
                      label: normaliseName(opt.name),
                      sublabel: opt.defaultPrice > 0
                          ? '+${egp(opt.defaultPrice)}'
                          : null,
                      selected: sel,
                      checkbox: widget.isMulti,
                      enabled: canSelect,
                      accentColor: accent,
                      onTap: () => widget.isMulti
                          ? widget.onToggleMulti(opt.id)
                          : widget.onToggleSingle(opt.id),
                    );
                  }).toList()),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QTY CHIP  — selected multi addon with inline +/- stepper
// ─────────────────────────────────────────────────────────────────────────────
class QtyChip extends StatelessWidget {
  final String label;
  final int price;
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final Color? accentColor;

  const QtyChip({
    super.key,
    required this.label,
    required this.price,
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: accent, width: 1.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Decrement / remove
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 30,
            height: 34,
            alignment: Alignment.center,
            child: const Icon(Icons.remove, size: 13, color: Colors.white),
          ),
        ),
        // Label + qty
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            if (price > 0)
              Text('+${egp(price * qty)}',
                  style: cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.8))),
          ]),
        ),
        // Qty badge
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4)),
          child: Text('$qty',
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        // Increment
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 30,
            height: 34,
            alignment: Alignment.center,
            child: const Icon(Icons.add, size: 13, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}
