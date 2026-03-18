import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/inventory_api.dart';
import '../../core/api/shift_api.dart';
import '../../core/models/inventory.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/label_value.dart';

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});
  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<InventoryItem> _inv = [];
  final Map<String, TextEditingController> _ctrs = {};

  bool _loadingInv = true;
  bool _loadingCash = true;
  bool _submitting = false;
  String? _error;

  int _systemCash = 0;
  int _cashDiscrepancy = 0;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_updateDiscrepancy);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSystemCash();
      _loadInventory();
    });
  }

  @override
  void dispose() {
    _cashCtrl.removeListener(_updateDiscrepancy);
    _cashCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _ctrs.values) c.dispose();
    super.dispose();
  }

  void _updateDiscrepancy() {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null) {
      setState(() => _cashDiscrepancy = 0);
      return;
    }
    final declared = (raw * 100).round();
    setState(() => _cashDiscrepancy = declared - _systemCash);
  }

  Future<void> _loadSystemCash() async {
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) {
      setState(() => _loadingCash = false);
      return;
    }
    try {
      final system = await shiftApi.getSystemCash(shift.id, shift.openingCash);
      if (mounted) {
        setState(() {
          _systemCash = system;
          _loadingCash = false;
        });
        _updateDiscrepancy();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCash = false);
    }
  }

  Future<void> _loadInventory() async {
    final branchId = context.read<ShiftProvider>().shift?.branchId;
    if (branchId == null) {
      setState(() => _loadingInv = false);
      return;
    }
    try {
      final items = await inventoryApi.items(branchId);
      if (!mounted) return;
      setState(() {
        _inv = items;
        _loadingInv = false;
        for (final i in items) {
          _ctrs[i.id] =
              TextEditingController(text: i.currentStock.toStringAsFixed(2));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingInv = false);
    }
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final counts = _ctrs.entries
        .map((e) => {
              'inventory_item_id': e.key,
              'actual_stock': double.tryParse(e.value.text) ?? 0.0,
            })
        .toList();

    final ok = await context.read<ShiftProvider>().closeShift(
          closingCash: (raw * 100).round(),
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          inventoryCounts: counts,
        );

    if (mounted) {
      if (ok) {
        context.go('/home');
      } else {
        setState(() {
          _error =
              context.read<ShiftProvider>().error ?? 'Failed to close shift';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>().shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Close Shift',
          style:
              cairo(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : isTablet
              ? _TabletLayout(state: this, shift: shift)
              : _PhoneLayout(state: this, shift: shift),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PHONE LAYOUT  (single column)
// ─────────────────────────────────────────────────────────────
class _PhoneLayout extends StatelessWidget {
  final _CloseShiftScreenState state;
  final dynamic shift;
  const _PhoneLayout({required this.state, required this.shift});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShiftSummaryCard(shift: shift),
              const SizedBox(height: 16),
              _CashCard(state: state),
              const SizedBox(height: 16),
              _InventoryCard(state: state),
              const SizedBox(height: 16),
              _SubmitSection(state: state),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TABLET LAYOUT  (two columns)
// ─────────────────────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  final _CloseShiftScreenState state;
  final dynamic shift;
  const _TabletLayout({required this.state, required this.shift});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column — summary + cash
          Expanded(
            child: Column(children: [
              _ShiftSummaryCard(shift: shift),
              const SizedBox(height: 16),
              _CashCard(state: state),
              const SizedBox(height: 16),
              _SubmitSection(state: state),
            ]),
          ),
          const SizedBox(width: 20),
          // Right column — inventory
          Expanded(
            child: _InventoryCard(state: state),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHIFT SUMMARY CARD
// ─────────────────────────────────────────────────────────────
class _ShiftSummaryCard extends StatelessWidget {
  final dynamic shift;
  const _ShiftSummaryCard({required this.shift});

  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.summarize_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Shift Summary',
                style: cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            LabelValue('Teller', shift.tellerName),
            LabelValue('Opening Cash', egp(shift.openingCash)),
            LabelValue('Opened At', dateTime(shift.openedAt)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  CASH CARD
// ─────────────────────────────────────────────────────────────
class _CashCard extends StatelessWidget {
  final _CloseShiftScreenState state;
  const _CashCard({required this.state});

  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Cash Count',
                style: cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // System cash info row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Cash',
                          style: cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        'Opening + cash orders + movements',
                        style: cairo(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                state._loadingCash
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        egp(state._systemCash),
                        style: cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ]),
            ),
            const SizedBox(height: 16),

            Text(
              'ACTUAL CASH IN DRAWER',
              style: cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state._cashCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: cairo(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: 'EGP  ',
                prefixStyle:
                    cairo(fontSize: 20, color: AppColors.textSecondary),
                hintText: '0',
                hintStyle: cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.border,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),

            // Discrepancy indicator
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: !state._loadingCash && state._cashCtrl.text.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _DiscrepancyRow(
                        discrepancy: state._cashDiscrepancy,
                        systemCash: state._systemCash,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 14),
            TextField(
              controller: state._noteCtrl,
              decoration: InputDecoration(
                hintText: 'Cash note (optional)',
                hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.notes_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  INVENTORY CARD
// ─────────────────────────────────────────────────────────────
class _InventoryCard extends StatelessWidget {
  final _CloseShiftScreenState state;
  const _InventoryCard({required this.state});

  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Inventory Count',
                style: cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (state._loadingInv)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (state._inv.isEmpty)
              Text('No inventory items',
                  style: cairo(fontSize: 13, color: AppColors.textMuted))
            else
              ...state._inv.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              )),
                          Text(
                            'System: ${item.currentStock} ${item.unit}',
                            style: cairo(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: state._ctrs[item.id],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.center,
                        style: cairo(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          suffixText: item.unit,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  SUBMIT SECTION
// ─────────────────────────────────────────────────────────────
class _SubmitSection extends StatelessWidget {
  final _CloseShiftScreenState state;
  const _SubmitSection({required this.state});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: state._error != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 15, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(state._error!,
                              style:
                                  cairo(fontSize: 13, color: AppColors.danger)),
                        ),
                      ]),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          AppButton(
            label: 'Close Shift',
            variant: BtnVariant.danger,
            loading: state._submitting,
            width: double.infinity,
            icon: Icons.lock_outline_rounded,
            onTap: state._close,
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  DISCREPANCY ROW  — now takes systemCash as param (no ancestor lookup)
// ─────────────────────────────────────────────────────────────
class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy;
  final int systemCash;
  const _DiscrepancyRow({required this.discrepancy, required this.systemCash});

  @override
  Widget build(BuildContext context) {
    final isOver = discrepancy > 0;
    final isExact = discrepancy == 0;

    final color = isExact
        ? AppColors.success
        : isOver
            ? AppColors.warning
            : AppColors.danger;

    final icon = isExact
        ? Icons.check_circle_rounded
        : isOver
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    final label = isExact
        ? 'Exact match'
        : isOver
            ? 'Over by ${egp(discrepancy.abs())}'
            : 'Short by ${egp(discrepancy.abs())}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            )),
        const Spacer(),
        if (!isExact)
          Text(
            'System: ${egp(systemCash)}',
            style: cairo(fontSize: 11, color: color.withOpacity(0.8)),
          ),
      ]),
    );
  }
}
