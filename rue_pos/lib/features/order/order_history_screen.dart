import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Order History',
            style: cairo(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
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
          ? _placeholder('No open shift', icon: Icons.lock_outline_rounded)
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
                          icon: Icons.receipt_long_outlined)
                      : _buildList(history.orders),
    );
  }

  Widget _buildList(List<Order> orders) {
    // Summary bar at top
    final total = orders
        .where((o) => o.status != 'voided')
        .fold(0, (s, o) => s + o.totalAmount);
    final count = orders.where((o) => o.status != 'voided').length;

    return Column(children: [
      // Summary bar
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          _StatChip(
            label: 'Orders',
            value: '$count',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Total Sales',
            value: egp(total),
            color: AppColors.success,
          ),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (_, i) => _OrderTile(order: orders[i]),
        ),
      ),
    ]);
  }

  Widget _placeholder(String msg, {required IconData icon}) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(msg, style: cairo(fontSize: 15, color: AppColors.textSecondary)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
//  STAT CHIP
// ─────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: cairo(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8),
              )),
          const SizedBox(width: 8),
          Text(value,
              style: cairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              )),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
//  ORDER TILE  — fetches full order on tap
// ─────────────────────────────────────────────────────────────
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
        _OrderDetailSheet.show(context, full);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isVoided = o.status == 'voided';

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isVoided ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isVoided ? AppColors.border : const Color(0xFFEEEEEE),
          ),
          boxShadow: isVoided
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Order number badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isVoided
                      ? AppColors.border
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${o.orderNumber}',
                  style: cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isVoided ? AppColors.textMuted : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _PaymentBadge(method: o.paymentMethod, voided: isVoided),
                      if (isVoided) ...[
                        const SizedBox(width: 6),
                        _VoidedBadge(),
                      ],
                      const Spacer(),
                      Text(
                        timeShort(o.createdAt),
                        style: cairo(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      egp(o.totalAmount),
                      style: cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isVoided
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration:
                            isVoided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (o.customerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        o.customerName!,
                        style: cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),

          // Loading overlay
          if (_loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary),
                ),
              ),
            ),
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: cairo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: voided ? AppColors.textMuted : AppColors.primary,
            letterSpacing: 0.2,
          )),
    );
  }
}

class _VoidedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('VOIDED',
            style: cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              letterSpacing: 0.3,
            )),
      );
}

// ─────────────────────────────────────────────────────────────
//  ORDER DETAIL SHEET
//  Shows full order with items fetched from GET /orders/:id
// ─────────────────────────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});

  static void show(BuildContext ctx, Order order) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderDetailSheet(order: order),
      );

  @override
  Widget build(BuildContext context) {
    final isVoided = order.status == 'voided';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${order.orderNumber}',
                  style: cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 2),
              Text(dateTime(order.createdAt),
                  style: cairo(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            if (isVoided)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('VOIDED',
                    style: cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                      letterSpacing: 0.4,
                    )),
              ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Scrollable body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Items
              if (order.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No item details available',
                      style: cairo(fontSize: 13, color: AppColors.textMuted)),
                )
              else
                ...order.items.map((item) => _ItemRow(item: item)),

              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),

              // Totals
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
                        style: cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        )),
                    Text(egp(order.totalAmount),
                        style: cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isVoided
                              ? AppColors.textMuted
                              : AppColors.primary,
                          decoration:
                              isVoided ? TextDecoration.lineThrough : null,
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),

              // Meta
              LabelValue(
                  'Payment',
                  order.paymentMethod[0].toUpperCase() +
                      order.paymentMethod.substring(1)),
              if (order.customerName != null)
                LabelValue('Customer', order.customerName!),
              LabelValue('Time', timeShort(order.createdAt)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ITEM ROW
// ─────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Qty badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('${item.quantity}',
                style: cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                )),
          ),
          const SizedBox(width: 10),

          // Name + addons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName +
                      (item.sizeLabel != null ? ' · ${item.sizeLabel}' : ''),
                  style: cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
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
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                a.unitPrice > 0
                                    ? '${a.addonName} +${egp(a.unitPrice)}'
                                    : a.addonName,
                                style: cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),
          Text(egp(item.lineTotal),
              style: cairo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}
