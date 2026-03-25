// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/label_value.dart';
import 'void_order_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final shiftId = context.read<ShiftProvider>().shift?.id;
    if (shiftId == null) return;
    await context
        .read<OrderHistoryProvider>()
        .loadForShift(shiftId, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<OrderHistoryProvider>();
    final shift = context.watch<ShiftProvider>().shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: Text('Order History',
            style: cairo(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0EDE8))),
        actions: [
          if (shift != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh',
              onPressed: () =>
                  context.read<OrderHistoryProvider>().refresh(shift.id),
            ),
        ],
      ),
      body: shift == null
          ? _Placeholder(
              icon: Icons.lock_outline_rounded,
              message: 'No open shift',
              isTablet: isTablet)
          : history.loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : history.error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          ErrorBanner(message: history.error!, onRetry: _load))
                  : history.orders.isEmpty
                      ? _Placeholder(
                          icon: Icons.receipt_long_outlined,
                          message: 'No orders yet for this shift',
                          isTablet: isTablet,
                          useLottie: true)
                      : _OrderList(orders: history.orders, isTablet: isTablet),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUMMARY BAR + LIST
// ─────────────────────────────────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final bool isTablet;
  const _OrderList({required this.orders, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final active = orders.where((o) => o.status != 'voided').toList();
    final total = active.fold(0, (s, o) => s + o.totalAmount);
    final cash = active
        .where((o) => o.paymentMethod == 'cash')
        .fold(0, (s, o) => s + o.totalAmount);
    final card = active
        .where((o) => o.paymentMethod == 'card')
        .fold(0, (s, o) => s + o.totalAmount);

    return Column(children: [
      Container(
        color: Colors.white,
        padding:
            EdgeInsets.fromLTRB(isTablet ? 24 : 16, 14, isTablet ? 24 : 16, 14),
        child: Row(children: [
          _StatChip(
              label: 'Orders',
              value: '${active.length}',
              color: AppColors.primary),
          const SizedBox(width: 8),
          _StatChip(
              label: 'Total', value: egp(total), color: AppColors.success),
          if (cash > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
                label: 'Cash',
                value: egp(cash),
                color: const Color(0xFF6B7280)),
          ],
          if (card > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
                label: 'Card',
                value: egp(card),
                color: const Color(0xFF7C3AED)),
          ],
        ]),
      ),
      Container(height: 1, color: const Color(0xFFF0EDE8)),
      Expanded(
        child: isTablet
            ? GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.6,
                ),
                itemCount: orders.length,
                itemBuilder: (_, i) => _OrderTile(order: orders[i]))
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: orders.length,
                itemBuilder: (_, i) => _OrderTile(order: orders[i])),
      ),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.75))),
          const SizedBox(width: 7),
          Text(value,
              style: cairo(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER TILE
// ─────────────────────────────────────────────────────────────────────────────
class _OrderTile extends StatefulWidget {
  final Order order;
  const _OrderTile({required this.order});
  @override
  State<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<_OrderTile> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final full = await orderApi.get(widget.order.id);
      if (mounted) {
        setState(() => _loading = false);
        _show(full);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _show(widget.order);
      }
    }
  }

  void _show(Order o) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: isTablet
          ? BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.88)
          : null,
      builder: (_) => _OrderDetailSheet(order: o),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isVoided = o.status == 'voided';

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isVoided ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isVoided ? const Color(0xFFEEEAE4) : const Color(0xFFF0EDE8)),
          boxShadow: isVoided
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: isVoided
                        ? const Color(0xFFF0EDE8)
                        : AppColors.primary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(13)),
                alignment: Alignment.center,
                child: Text('#${o.orderNumber}',
                    style: cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isVoided
                            ? AppColors.textMuted
                            : AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      _PaymentBadge(method: o.paymentMethod, voided: isVoided),
                      if (isVoided) ...[
                        const SizedBox(width: 6),
                        const _VoidedBadge()
                      ],
                      const Spacer(),
                      Text(timeShort(o.createdAt),
                          style:
                              cairo(fontSize: 11, color: AppColors.textMuted)),
                    ]),
                    const SizedBox(height: 5),
                    Text(egp(o.totalAmount),
                        style: cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isVoided
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            decoration:
                                isVoided ? TextDecoration.lineThrough : null)),
                    if (o.customerName != null) ...[
                      const SizedBox(height: 2),
                      Text(o.customerName!,
                          style: cairo(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
          if (_loading)
            Positioned.fill(
                child: Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary)),
            )),
        ]),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String method;
  final bool voided;
  const _PaymentBadge({required this.method, required this.voided});

  @override
  Widget build(BuildContext context) {
    final label = switch (method) {
      'cash' => 'Cash',
      'card' => 'Card',
      'digital_wallet' => 'Wallet',
      'mixed' => 'Mixed',
      _ => method[0].toUpperCase() + method.substring(1),
    };
    final color = switch (method) {
      'cash' => const Color(0xFF059669),
      'card' => const Color(0xFF7C3AED),
      'digital_wallet' => const Color(0xFF0EA5E9),
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: voided ? const Color(0xFFF0EDE8) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: voided ? AppColors.textMuted : color,
              letterSpacing: 0.2)),
    );
  }
}

class _VoidedBadge extends StatelessWidget {
  const _VoidedBadge();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text('VOIDED',
          style: cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              letterSpacing: 0.3)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _OrderDetailSheet extends StatefulWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});
  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  late Order _order;
  bool _printing = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter || bp.printerIp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No printer configured for this branch'),
        backgroundColor: AppColors.warning,
        duration: Duration(seconds: 3),
      ));
      return;
    }
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.print(
      ip: bp.printerIp!,
      port: bp.printerPort,
      order: _order,
      branchName: bp.branchName,
      brand: bp.printerBrand!,
    );
    if (mounted)
      setState(() {
        _printing = false;
        _printError = err;
      });
  }

  void _onVoided(Order voided) {
    // Update locally so the sheet reflects the void immediately
    setState(() => _order = voided);
    // Update the list in the provider
    context.read<OrderHistoryProvider>().updateOrder(voided);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final isVoided = order.status == 'voided';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
          color: Color(0xFFFAF8F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // Handle
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFDDD8D0),
                        borderRadius: BorderRadius.circular(2))))),

        // Header
        Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text('Order #${order.orderNumber}',
                          style:
                              cairo(fontSize: 18, fontWeight: FontWeight.w800)),
                      if (isVoided) ...[
                        const SizedBox(width: 8),
                        const _VoidedBadge(),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(dateTime(order.createdAt),
                        style: cairo(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (order.tellerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('by ${order.tellerName}',
                          style:
                              cairo(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ])),

              // Action buttons — only shown when not voided
              if (!isVoided) ...[
                // Print button
                _printing
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary)))
                    : GestureDetector(
                        onTap: _print,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: (_printError != null
                                      ? AppColors.danger
                                      : AppColors.primary)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.print_rounded,
                                size: 14,
                                color: _printError != null
                                    ? AppColors.danger
                                    : AppColors.primary),
                            const SizedBox(width: 5),
                            Text(_printError != null ? 'Retry' : 'Print',
                                style: cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _printError != null
                                        ? AppColors.danger
                                        : AppColors.primary)),
                          ]),
                        )),
                const SizedBox(width: 8),
                // Void button
                GestureDetector(
                  onTap: () => VoidOrderSheet.show(context, order, _onVoided),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cancel_outlined,
                          size: 14, color: AppColors.danger),
                      const SizedBox(width: 5),
                      Text('Void',
                          style: cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger)),
                    ]),
                  ),
                ),
              ],
            ])),

        Container(height: 1, color: const Color(0xFFECE8E0)),

        // Scrollable content
        Expanded(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Items
            if (order.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECE8E0))),
                child: Text('No item details available',
                    style: cairo(fontSize: 13, color: AppColors.textMuted)),
              )
            else
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECE8E0))),
                child: Column(children: [
                  for (int i = 0; i < order.items.length; i++) ...[
                    _ItemRow(item: order.items[i]),
                    if (i < order.items.length - 1)
                      const Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: Color(0xFFF0EDE8)),
                  ],
                ]),
              ),

            const SizedBox(height: 14),

            // Totals
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECE8E0))),
              child: Column(children: [
                _TotalRow('Subtotal', egp(order.subtotal), muted: true),
                if (order.discountAmount > 0) ...[
                  const SizedBox(height: 6),
                  _TotalRow('Discount', '− ${egp(order.discountAmount)}',
                      valueColor: AppColors.success),
                ],
                if (order.taxAmount > 0) ...[
                  const SizedBox(height: 6),
                  _TotalRow('Tax (14%)', egp(order.taxAmount), muted: true),
                ],
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child:
                        Container(height: 1, color: const Color(0xFFF0EDE8))),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style:
                              cairo(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(egp(order.totalAmount),
                          style: cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isVoided
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                              decoration: isVoided
                                  ? TextDecoration.lineThrough
                                  : null)),
                    ]),
              ]),
            ),

            const SizedBox(height: 14),

            // Meta
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECE8E0))),
              child: Column(children: [
                _MetaRow(Icons.payments_outlined, 'Payment',
                    _paymentLabel(order.paymentMethod)),
                if (order.customerName != null) ...[
                  const SizedBox(height: 10),
                  _MetaRow(Icons.person_outline_rounded, 'Customer',
                      order.customerName!),
                ],
                const SizedBox(height: 10),
                _MetaRow(Icons.access_time_rounded, 'Time',
                    timeShort(order.createdAt)),
                // Show void reason if voided
                if (isVoided && order.voidReason != null) ...[
                  const SizedBox(height: 10),
                  _MetaRow(Icons.cancel_outlined, 'Void Reason',
                      _voidReasonLabel(order.voidReason!)),
                ],
              ]),
            ),
          ],
        )),
      ]),
    );
  }

  String _paymentLabel(String method) => switch (method) {
        'cash' => 'Cash',
        'card' => 'Card',
        'digital_wallet' => 'Digital Wallet',
        'mixed' => 'Mixed',
        _ => method,
      };

  String _voidReasonLabel(String reason) => switch (reason) {
        'customer_request' => 'Customer request',
        'wrong_order' => 'Wrong order',
        'quality_issue' => 'Quality issue',
        'other' => 'Other',
        _ => reason,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM ROW
// ─────────────────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('${item.quantity}',
                style: cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    item.itemName +
                        (item.sizeLabel != null
                            ? ' · ${normaliseName(item.sizeLabel!)}'
                            : ''),
                    style: cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: item.addons.map((a) {
                        final hasQty = a.quantity > 1;
                        final hasPrice = a.unitPrice > 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (hasQty)
                              Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('×${a.quantity}',
                                    style: cairo(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            Text(
                                normaliseName(a.addonName) +
                                    (hasPrice ? '  +${egp(a.lineTotal)}' : ''),
                                style: cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ]),
                        );
                      }).toList()),
                ],
              ])),
          const SizedBox(width: 10),
          Text(egp(item.lineTotal),
              style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED DETAIL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _TotalRow extends StatelessWidget {
  final String label, value;
  final bool muted;
  final Color? valueColor;
  const _TotalRow(this.label, this.value,
      {this.muted = false, this.valueColor});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: cairo(
                fontSize: 13,
                color:
                    muted ? AppColors.textSecondary : AppColors.textPrimary)),
        Text(value,
            style: cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ??
                    (muted ? AppColors.textSecondary : AppColors.textPrimary))),
      ]);
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MetaRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(label, style: cairo(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: cairo(fontSize: 12, fontWeight: FontWeight.w700)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PLACEHOLDER
// ─────────────────────────────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isTablet;
  final bool useLottie;
  const _Placeholder(
      {required this.icon,
      required this.message,
      required this.isTablet,
      this.useLottie = false});

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (useLottie)
          SizedBox(
              width: isTablet ? 180 : 150,
              height: isTablet ? 180 : 150,
              child: Lottie.asset('assets/lottie/no_orders.json',
                  fit: BoxFit.contain, repeat: true))
        else ...[
          Icon(icon, size: isTablet ? 52 : 44, color: const Color(0xFFD5CFC7)),
          const SizedBox(height: 12),
        ],
        Text(message,
            style: cairo(
                fontSize: isTablet ? 16 : 14, color: AppColors.textSecondary)),
      ]));
}
