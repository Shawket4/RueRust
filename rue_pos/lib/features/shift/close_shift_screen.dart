import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/label_value.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});
  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Map<String, TextEditingController> _invCtrs = {};
  final Map<String, bool> _zeroWarn = {};

  bool _loadingInv = true;
  bool _submitting = false;
  String? _error;
  int _declaredCash = 0;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_updateDeclared);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(shiftProvider.notifier).loadSystemCash();
      await _loadInventory();
    });
  }

  @override
  void dispose() {
    _cashCtrl
      ..removeListener(_updateDeclared)
      ..dispose();
    _noteCtrl.dispose();
    for (final c in _invCtrs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateDeclared() {
    final raw = double.tryParse(_cashCtrl.text);
    setState(() => _declaredCash = raw != null ? (raw * 100).round() : 0);
  }

  Future<void> _loadInventory() async {
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) {
      setState(() => _loadingInv = false);
      return;
    }
    await ref.read(shiftProvider.notifier).loadInventory(branchId);
    if (!mounted) return;
    final items = ref.read(shiftProvider).inventory;
    setState(() {
      _loadingInv = false;
      for (final i in items) {
        _invCtrs[i.id] =
            TextEditingController(text: i.currentStock.toStringAsFixed(2))
              ..addListener(() {
                final v = double.tryParse(_invCtrs[i.id]?.text ?? '');
                final was = _zeroWarn[i.id] ?? false;
                final is0 = v == 0.0;
                if (was != is0) setState(() => _zeroWarn[i.id] = is0);
              });
      }
    });
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }

    final inv = ref.read(shiftProvider).inventory;
    final zeroItems = inv
        .where((i) {
          final v = double.tryParse(_invCtrs[i.id]?.text ?? '');
          return v == null || v == 0.0;
        })
        .map((i) => i.name)
        .toList();

    if (zeroItems.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Zero Stock Warning',
              style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'The following items have 0 stock:\n\n${zeroItems.join(", ")}'
            '\n\nAre you sure you want to submit?',
            style: cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Go Back', style: cairo(color: AppColors.primary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Submit Anyway',
                    style: cairo(
                        color: AppColors.danger, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final counts = _invCtrs.entries
        .map((e) => {
              'inventory_item_id': e.key,
              'actual_stock': double.tryParse(e.value.text) ?? 0.0,
            })
        .toList();

    final branchId = ref.read(authProvider).user!.branchId!;
    final ok = await ref.read(shiftProvider.notifier).closeShift(
          branchId: branchId,
          closingCash: (raw * 100).round(),
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          inventoryCounts: counts,
        );

    if (!mounted) return;

    if (ok) {
      // Shift is now closed — check if we should logout (user came from logout guard)
      final canNowLogout = await ref.read(authProvider.notifier).canLogout();
      if (!mounted) return;
      if (canNowLogout) {
        // Logout was pending, complete it now
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.go('/login');
      } else {
        context.go('/home');
      }
    } else {
      setState(() {
        _error = ref.read(shiftProvider).error ?? 'Failed to close shift';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = ref.watch(shiftProvider).shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Close Shift',
            style: cairo(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
              ? _buildTablet(shift)
              : _buildPhone(shift),
    );
  }

  Widget _buildPhone(dynamic shift) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SummaryCard(shift: shift),
              const SizedBox(height: 16),
              _CashCard(state: this),
              const SizedBox(height: 16),
              _InventoryCard(state: this),
              const SizedBox(height: 16),
              _SubmitSection(state: this),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      );

  Widget _buildTablet(dynamic shift) => Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(children: [
                _SummaryCard(shift: shift),
                const SizedBox(height: 16),
                _CashCard(state: this),
              ])),
              const SizedBox(width: 20),
              Expanded(child: _InventoryCard(state: this)),
            ]),
          ),
        ),
        Container(
          color: AppColors.bg,
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: _SubmitSection(state: this),
        ),
      ]);
}

// ── Sub-cards ───────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final dynamic shift;
  const _SummaryCard({required this.shift});
  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.summarize_outlined,
                    color: AppColors.primary, size: 18)),
            const SizedBox(width: 12),
            Text('Shift Summary',
                style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          LabelValue('Teller', shift.tellerName),
          LabelValue('Opening Cash', egp(shift.openingCash)),
          LabelValue('Opened At', dateTime(shift.openedAt)),
        ]),
      );
}

class _CashCard extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _CashCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemCash = ref.watch(shiftProvider.select((s) => s.systemCash));
    final cashLoading =
        ref.watch(shiftProvider.select((s) => s.systemCashLoading));
    final discrepancy = state._declaredCash - systemCash;
    final showDiscrep = !cashLoading && state._cashCtrl.text.isNotEmpty;

    return CardContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.payments_outlined,
                  color: AppColors.success, size: 18)),
          const SizedBox(width: 12),
          Text('Cash Count',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('System Cash',
                      style: cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 3),
                  Text('Opening + cash orders + movements',
                      style: cairo(fontSize: 11, color: AppColors.textMuted)),
                ])),
            cashLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : Text(egp(systemCash),
                    style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('ACTUAL CASH IN DRAWER',
            style: cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0)),
        const SizedBox(height: 8),
        TextField(
          controller: state._cashCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: cairo(fontSize: 28, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: 'EGP  ',
            prefixStyle: cairo(fontSize: 20, color: AppColors.textSecondary),
            hintText: '0',
            hintStyle: cairo(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.border),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: showDiscrep
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DiscrepancyRow(
                      discrepancy: discrepancy, systemCash: systemCash))
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
      ]),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _InventoryCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(shiftProvider.select((s) => s.inventory));
    return CardContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.warning, size: 18)),
          const SizedBox(width: 12),
          Text('Inventory Count',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        if (state._loadingInv)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.primary)))
        else if (inventory.isEmpty)
          Text('No inventory items',
              style: cairo(fontSize: 13, color: AppColors.textMuted))
        else
          ...inventory.map((item) {
            final warn = state._zeroWarn[item.id] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.name,
                          style:
                              cairo(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('System: ${item.currentStock} ${item.unit}',
                          style: cairo(
                              fontSize: 12, color: AppColors.textSecondary)),
                      if (warn)
                        Text('⚠ Value is 0 — confirm this is correct',
                            style:
                                cairo(fontSize: 11, color: AppColors.warning)),
                    ])),
                const SizedBox(width: 12),
                SizedBox(
                    width: 130,
                    child: TextField(
                      controller: state._invCtrs[item.id],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              warn ? AppColors.warning : AppColors.textPrimary),
                      decoration: InputDecoration(
                        suffixText: item.unit,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: warn
                                    ? AppColors.warning
                                    : AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2)),
                      ),
                    )),
              ]),
            );
          }),
      ]),
    );
  }
}

class _SubmitSection extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _SubmitSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    return Column(children: [
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
                      border:
                          Border.all(color: AppColors.danger.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(state._error!,
                            style:
                                cairo(fontSize: 13, color: AppColors.danger))),
                  ]),
                ))
            : const SizedBox.shrink(),
      ),
      if (!isOnline)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD700))),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 14, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Internet required to close a shift.',
                      style:
                          cairo(fontSize: 12, color: const Color(0xFF856404)))),
            ]),
          ),
        ),
      AppButton(
        label: 'Close Shift',
        variant: BtnVariant.danger,
        loading: state._submitting,
        width: double.infinity,
        icon: Icons.lock_outline_rounded,
        onTap: (!isOnline || state._submitting) ? null : state._close,
      ),
    ]);
  }
}

class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy, systemCash;
  const _DiscrepancyRow({required this.discrepancy, required this.systemCash});

  @override
  Widget build(BuildContext context) {
    final isExact = discrepancy == 0;
    final isOver = discrepancy > 0;
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
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style:
                cairo(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        if (!isExact)
          Text('System: ${egp(systemCash)}',
              style: cairo(fontSize: 11, color: color.withOpacity(0.8))),
      ]),
    );
  }
}
