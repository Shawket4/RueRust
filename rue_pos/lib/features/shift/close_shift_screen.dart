import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Close Shift',
            style: cairo(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Shift summary ─────────────────────────
                      CardContainer(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shift Summary',
                              style: cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 12),
                          LabelValue('Teller', shift.tellerName),
                          LabelValue('Opening Cash', egp(shift.openingCash)),
                          LabelValue('Opened At', dateTime(shift.openedAt)),
                        ],
                      )),
                      const SizedBox(height: 16),

                      // ── Cash section ──────────────────────────
                      CardContainer(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cash Count',
                              style: cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 16),

                          // System cash row
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
                                  const SizedBox(height: 4),
                                  Text(
                                    'Opening + cash orders + movements',
                                    style: cairo(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              )),
                              _loadingCash
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Text(
                                      egp(_systemCash),
                                      style: cairo(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                            ]),
                          ),
                          const SizedBox(height: 14),

                          // Declared cash input
                          Text('Actual Cash in Drawer',
                              style: cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.3,
                              )),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cashCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: cairo(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              prefixText: 'EGP ',
                              prefixStyle: cairo(
                                  fontSize: 20, color: AppColors.textSecondary),
                            ),
                          ),

                          // Discrepancy indicator
                          if (!_loadingCash && _cashCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _DiscrepancyRow(discrepancy: _cashDiscrepancy),
                          ],

                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                                hintText: 'Cash note (optional)'),
                          ),
                        ],
                      )),
                      const SizedBox(height: 16),

                      // ── Inventory count ───────────────────────
                      CardContainer(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Inventory Count',
                              style: cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 14),
                          if (_loadingInv)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            )
                          else if (_inv.isEmpty)
                            Text('No inventory items',
                                style: cairo(
                                    fontSize: 13, color: AppColors.textMuted))
                          else
                            ..._inv.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(children: [
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              fontSize: 12,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    )),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 130,
                                      child: TextField(
                                        controller: _ctrs[item.id],
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        style: cairo(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                        decoration: InputDecoration(
                                          suffixText: item.unit,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ]),
                                )),
                        ],
                      )),
                      const SizedBox(height: 16),

                      // ── Error ─────────────────────────────────
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!,
                              style: cairo(
                                  fontSize: 13, color: AppColors.danger)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Submit ────────────────────────────────
                      AppButton(
                        label: 'Close Shift',
                        variant: BtnVariant.danger,
                        loading: _submitting,
                        width: double.infinity,
                        icon: Icons.lock_outline_rounded,
                        onTap: _close,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DISCREPANCY ROW
// ─────────────────────────────────────────────────────────────
class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy;
  const _DiscrepancyRow({required this.discrepancy});

  @override
  Widget build(BuildContext context) {
    final isOver = discrepancy > 0;
    final isUnder = discrepancy < 0;
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
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
            'System: ${egp(context.findAncestorStateOfType<_CloseShiftScreenState>()!._systemCash)}',
            style: cairo(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
      ]),
    );
  }
}
