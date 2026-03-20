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
    await context.read<OrderHistoryProvider>().loadForShift(shiftId);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<OrderHistoryProvider>();
    final shift = context.watch<ShiftProvider>().shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
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
            child: Container(height: 1, color: const Color(0xFFF0F0F0))),
        actions: [
          if (shift != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () =>
                  context.read<OrderHistoryProvider>().refresh(shift.id),
            ),
        ],
      ),
      body: shift == null
          ? _placeholder('No open shift',
              icon: Icons.lock_outline_rounded, isTablet: isTablet)
          : history.loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : history.error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          ErrorBanner(message: history.error!, onRetry: _load))
                  : history.orders.isEmpty
                      ? _placeholder('No orders yet for this shift',
                          icon: Icons.receipt_long_outlined,
                          isTablet: isTablet,
                          useLottie: true)
                      : _buildList(history.orders, isTablet),
    );
  }

  Widget _buildList(List<Order> orders, bool isTablet) {
    final total = orders
        .where((o) => o.status != 'voided')
        .fold(0, (s, o) => s + o.totalAmount);
    final count = orders.where((o) => o.status != 'voided').length;

    return Column(children: [
      Container(
        width: double.infinity,
        color: Colors.white,
        padding:
            EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 14),
        child: Row(children: [
          _StatChip(label: 'Orders', value: '$count', color: AppColors.primary),
          const SizedBox(width: 10),
          _StatChip(
              label: 'Total Sales',
              value: egp(total),
              color: AppColors.success),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),
      Expanded(
          child: isTablet
              ? _TwoColumnList(orders: orders)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _OrderTile(order: orders[i]))),
    ]);
  }

  Widget _placeholder(String msg,
          {required IconData icon,
          required bool isTablet,
          bool useLottie = false}) =>
      Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (useLottie)
          SizedBox(
              width: isTablet ? 200 : 160,
              height: isTablet ? 200 : 160,
              child: Lottie.asset('assets/lottie/no_orders.json',
                  fit: BoxFit.contain, repeat: true))
        else ...[
          Icon(icon, size: isTablet ? 56 : 48, color: AppColors.border),
          const SizedBox(height: 12),
        ],
        Text(msg,
            style: cairo(
                fontSize: isTablet ? 17 : 15, color: AppColors.textSecondary)),
      ]));
}

// ── Two-column list — no fixed mainAxisExtent, cards auto-size ────────────────
class _TwoColumnList extends StatelessWidget {
  final List<Order> orders;
  const _TwoColumnList({required this.orders});
  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 520,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.8, // wide cards, height auto-scales with content
        ),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderTile(order: orders[i]),
      );
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.8))),
          const SizedBox(width: 8),
          Text(value,
              style: cairo(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

// ── Order Tile ────────────────────────────────────────────────────────────────
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
      // Fall back to the summary order we already have
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
              maxHeight: MediaQuery.of(context).size.height * 0.85)
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
              color: isVoided ? AppColors.border : const Color(0xFFEEEEEE)),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: isVoided
                        ? AppColors.border
                        : AppColors.primary.withOpacity(0.08),
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
                        _VoidedBadge()
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
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
          if (_loading)
            Positioned.fill(
                child: Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
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
    final label = method[0].toUpperCase() + method.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: voided
              ? AppColors.borderLight
              : AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: voided ? AppColors.textMuted : AppColors.primary,
              letterSpacing: 0.2)),
    );
  }
}

class _VoidedBadge extends StatelessWidget {
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

// ── Order Detail Sheet ────────────────────────────────────────────────────────
class _OrderDetailSheet extends StatefulWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});
  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _printing = false;
  String? _printError;

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
      order: widget.order,
      branchName: bp.branchName,
      brand: bp.printerBrand!,
    );
    if (mounted)
      setState(() {
        _printing = false;
        _printError = err;
      });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isVoided = order.status == 'voided';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2))))),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Order #${order.orderNumber}',
                    style: cairo(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(dateTime(order.createdAt),
                    style: cairo(fontSize: 12, color: AppColors.textSecondary)),
              ]),
              const Spacer(),
              if (!isVoided)
                _printing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
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
                                size: 15,
                                color: _printError != null
                                    ? AppColors.danger
                                    : AppColors.primary),
                            const SizedBox(width: 6),
                            Text(_printError != null ? 'Retry' : 'Print',
                                style: cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _printError != null
                                        ? AppColors.danger
                                        : AppColors.primary)),
                          ]),
                        )),
              if (isVoided)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('VOIDED',
                      style: cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                          letterSpacing: 0.4)),
                ),
            ])),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
            child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (order.items.isEmpty)
              Text('No item details available',
                  style: cairo(fontSize: 13, color: AppColors.textMuted))
            else
              ...order.items.map((item) => _ItemRow(item: item)),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            LabelValue('Subtotal', egp(order.subtotal)),
            if (order.discountAmount > 0)
              LabelValue('Discount', '− ${egp(order.discountAmount)}',
                  valueColor: AppColors.success),
            if (order.taxAmount > 0) LabelValue('Tax', egp(order.taxAmount)),
            const SizedBox(height: 4),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style:
                              cairo(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(egp(order.totalAmount),
                          style: cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isVoided
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                              decoration: isVoided
                                  ? TextDecoration.lineThrough
                                  : null)),
                    ])),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            LabelValue(
                'Payment',
                order.paymentMethod[0].toUpperCase() +
                    order.paymentMethod.substring(1)),
            if (order.customerName != null)
              LabelValue('Customer', order.customerName!),
            if (order.tellerName.isNotEmpty)
              LabelValue('Teller', order.tellerName),
            LabelValue('Time', timeShort(order.createdAt)),
          ],
        )),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('${item.quantity}',
                style: cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    item.itemName +
                        (item.sizeLabel != null ? ' · ${item.sizeLabel}' : ''),
                    style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: item.addons
                          .map((a) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(5)),
                                child: Text(
                                    a.unitPrice > 0
                                        ? '${a.addonName} +${egp(a.unitPrice)}'
                                        : a.addonName,
                                    style: cairo(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ))
                          .toList()),
                ],
              ])),
          const SizedBox(width: 12),
          Text(egp(item.lineTotal),
              style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
}
