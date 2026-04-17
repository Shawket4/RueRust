#!/bin/bash

echo "Writing lib/shared/widgets/pin_pad.dart..."
cat << 'EOF' > lib/shared/widgets/pin_pad.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final keySize = isTablet ? 76.0 : 68.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
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
                  onTap: () {
                    HapticFeedback.lightImpact(); // Task 3.4
                    k == '⌫' ? onBackspace() : onDigit(k);
                  },
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
EOF

echo "Writing lib/features/order/widgets/cart_row.dart..."
cat << 'EOF' > lib/features/order/widgets/cart_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/providers/menu_notifier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import 'item_detail_sheet.dart';
import 'shared_widgets.dart';

class CartRow extends ConsumerWidget {
  final int index;
  const CartRow({super.key, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final item = cart.items[index];
    final menu = ref.watch(menuProvider);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(
                  item.itemName +
                      (item.sizeLabel != null
                          ? ' · ${normaliseName(item.sizeLabel!)}'
                          : ''),
                  style: cairo(
                      fontSize: 13, fontWeight: FontWeight.w600, height: 1.3))),
          const SizedBox(width: 8),
          Text(egp(item.lineTotal),
              style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        if (item.addons.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.addons
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(AppRadius.xs)),
                        child: Text(
                            a.priceModifier > 0
                                ? '${normaliseName(a.name)}${a.quantity > 1 ? " ×${a.quantity}" : ""} +${egp(a.priceModifier * a.quantity)}'
                                : '${normaliseName(a.name)}${a.quantity > 1 ? " ×${a.quantity}" : ""}',
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ))
                  .toList()),
        ],
        if (item.optionals.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.optionals
                  .map((o) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppRadius.xs)),
                        child: Text(
                            o.price > 0
                                ? '${o.name} +${egp(o.price)}'
                                : o.name,
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning)),
                      ))
                  .toList()),
        ],
        const SizedBox(height: 8),
        Row(children: [
          InlineBtn(
              icon: Icons.remove,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .setQty(index, item.quantity - 1)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}',
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w700))),
          InlineBtn(
              icon: Icons.add,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .setQty(index, item.quantity + 1)),
          const Spacer(),

          GestureDetector(
            onTap: () {
              final menuItem =
                  menu.items.where((m) => m.id == item.menuItemId);
              if (menuItem.isEmpty) return;
              ItemDetailSheet.show(
                context,
                menuItem.first,
                editIndex: index,
                existingItem: item,
              );
            },
            child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(AppRadius.xs)),
                alignment: Alignment.center,
                child: const Icon(Icons.edit_outlined,
                    size: 13, color: AppColors.primary)),
          ),

          // Task 3.6: Delete button with Undo SnackBar
          GestureDetector(
            onTap: () {
              ref.read(cartProvider.notifier).removeAt(index);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.itemName} removed', style: cairo(color: Colors.white, fontSize: 14)),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.primary,
                    onPressed: () => ref.read(cartProvider.notifier).restoreLastRemoved(),
                  ),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(AppRadius.xs)),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 14, color: AppColors.danger)),
          ),
        ]),
      ]),
    );
  }
}
EOF

echo "Writing lib/features/order/widgets/cart_panel.dart..."
cat << 'EOF' > lib/features/order/widgets/cart_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/label_value.dart';
import 'cart_row.dart';
import 'checkout_sheet.dart';
import 'shared_widgets.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final cartW = (w * 0.26).clamp(280.0, 360.0);
    final cart = ref.watch(cartProvider);

    return Container(
      width: cartW,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            if (!cart.isEmpty) ...[
              const SizedBox(width: 8),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: CountBadge(
                      key: ValueKey(cart.count), count: cart.count)),
            ],
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () => _confirmClear(context, ref),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(AppRadius.xs)),
                  child: Text('Clear',
                      style: cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger)),
                ),
              ),
          ]),
        ),
        Expanded(
            child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  key: const ValueKey('items'),
                  padding: const EdgeInsets.all(10),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => CartRow(index: i)),
        )),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: cart.isEmpty ? const SizedBox.shrink() : const CartFooter(),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Clear Order?',
                  style: cairo(fontWeight: FontWeight.w700)),
              content: Text('Remove all items from the cart.', style: cairo()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: cairo(color: AppColors.textSecondary))),
                TextButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact(); // Task 3.4
                      Navigator.pop(ctx);
                      ref.read(cartProvider.notifier).clear();
                    },
                    child: Text('Clear',
                        style: cairo(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700))),
              ],
            ));
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 110,
              height: 110,
              child: Lottie.asset('assets/lottie/empty_cart.json',
                  fit: BoxFit.contain, repeat: true)),
          const SizedBox(height: 8),
          Text('Cart is empty',
              style: cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text('Tap any item to add it',
              style: cairo(fontSize: 11, color: AppColors.textMuted)),
        ]),
      );
}

class CartFooter extends ConsumerWidget {
  const CartFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(children: [
        LabelValue('Subtotal', egp(cart.subtotal)),
        if (cart.discountAmount > 0)
          LabelValue('Discount', '− ${egp(cart.discountAmount)}',
              valueColor: AppColors.success),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total',
                      style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, -0.3), end: Offset.zero)
                            .animate(anim),
                        child: FadeTransition(opacity: anim, child: child)),
                    child: Text(egp(cart.total),
                        key: ValueKey(cart.total),
                        style: cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ),
                ])),
        const SizedBox(height: 2),
        AppButton(
            label: 'Checkout',
            width: double.infinity,
            height: 50,
            icon: Icons.arrow_forward_rounded,
            onTap: () => CheckoutSheet.show(context)),
      ]),
    );
  }
}

class MobileCartFab extends ConsumerWidget {
  const MobileCartFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () => _MobileCartSheet.show(context),
      backgroundColor: AppColors.primary,
      elevation: 4,
      label: Text('${cart.count} items · ${egp(cart.total)}',
          style: cairo(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      icon: const Icon(Icons.shopping_bag_outlined,
          size: 18, color: Colors.white),
    );
  }
}

class _MobileCartSheet extends ConsumerWidget {
  const _MobileCartSheet();

  static void show(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _MobileCartSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            CountBadge(count: cart.count),
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ref.read(cartProvider.notifier).clear();
                  Navigator.pop(context);
                },
                child: Text('Clear',
                    style: cairo(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: AppColors.border),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text('Cart is empty',
                      style: cairo(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => CartRow(index: i)),
        ),
        if (!cart.isEmpty) const CartFooter(),
      ]),
    );
  }
}
EOF

echo "Writing lib/features/order/widgets/checkout_sheet.dart..."
cat << 'EOF' > lib/features/order/widgets/checkout_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/client.dart';
import '../../../core/api/order_api.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/discount.dart';
import '../../../core/models/order.dart';
import '../../../core/models/pending_action.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/providers/discount_notifier.dart';
import '../../../core/providers/order_history_notifier.dart';
import '../../../core/providers/shift_notifier.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_queue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/label_value.dart';
import '../../../shared/widgets/responsive_sheet.dart';
import '../../../shared/widgets/sync_status_banner.dart';
import '../helpers/payment_helpers.dart';
import 'receipt_sheet.dart';
import 'shared_widgets.dart';

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  // Task 3.2: Use ResponsiveSheet
  static Future<void> show(BuildContext ctx) => ResponsiveSheet.show(
      context: ctx,
      builder: (_) => const CheckoutSheet());

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  bool _loading = false;
  String? _error;
  final _customerCtrl = TextEditingController();

  Discount? _selectedDiscount;

  final _tenderedCtrl = TextEditingController();
  bool _showTendered = false;

  final _tipCtrl = TextEditingController();
  String _tipPaymentMethod = 'cash';

  bool _isSplit = false;
  final Map<String, TextEditingController> _splitCtrs = {};
  final Set<String> _activeSplitMethods = {};

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _showTendered = cart.payment == 'cash' || cart.payment == 'talabat_cash';
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _tenderedCtrl.dispose();
    _tipCtrl.dispose();
    for (final c in _splitCtrs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleSplitMethod(String method) {
    setState(() {
      if (_activeSplitMethods.contains(method)) {
        _activeSplitMethods.remove(method);
        _splitCtrs[method]?.clear();
      } else {
        _activeSplitMethods.add(method);
        _splitCtrs.putIfAbsent(method, () => TextEditingController());
      }
    });
  }

  List<PaymentSplit> _buildSplits() {
    final splits = <PaymentSplit>[];
    for (final method in _activeSplitMethods) {
      final raw = double.tryParse(_splitCtrs[method]?.text ?? '');
      if (raw != null && raw > 0) {
        splits.add(PaymentSplit(method: method, amount: (raw * 100).round()));
      }
    }
    return splits;
  }

  int? get _parsedTip {
    final v = double.tryParse(_tipCtrl.text);
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }

  bool get _tipIsCash => isCashMethod(_tipPaymentMethod);

  Future<void> _place() async {
    final cart = ref.read(cartProvider);
    final shift = ref.read(shiftProvider).shift;
    final queue = ref.read(offlineQueueProvider.notifier);
    final isOnline = ref.read(isOnlineProvider);
    final customer =
        _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim();

    if (_loading) return;
    if (cart.isEmpty) {
      setState(() => _error = 'Cart is empty');
      return;
    }
    if (shift == null) {
      setState(() => _error = 'No open shift');
      return;
    }
    if (!_isSplit && cart.payment.isEmpty) {
      setState(() => _error = 'Select a payment method');
      return;
    }

    final int? tip = _parsedTip;
    final String? tipMethod = tip != null ? _tipPaymentMethod : null;

    final int? tendered = _showTendered && !_isSplit
        ? (double.tryParse(_tenderedCtrl.text) != null
            ? (double.parse(_tenderedCtrl.text) * 100).round()
            : null)
        : null;

    if (_showTendered && !_isSplit) {
      if (tendered == null || tendered == 0) {
        setState(() => _error = 'Enter the cash amount tendered');
        return;
      }
      if (tendered < cart.total) {
        setState(() => _error =
            'Tendered ${egp(tendered)} is less than total ${egp(cart.total)}');
        return;
      }
      if (tip != null && _tipIsCash) {
        final change = tendered - cart.total;
        if (tip > change) {
          setState(() =>
              _error = 'Cash tip ${egp(tip)} exceeds change ${egp(change)}');
          return;
        }
      }
    }

    List<PaymentSplit>? splits;
    if (_isSplit) {
      if (_activeSplitMethods.isEmpty) {
        setState(() => _error = 'Select at least one payment method');
        return;
      }
      splits = _buildSplits();
      if (splits.isEmpty) {
        setState(() => _error = 'Enter amounts for selected payment methods');
        return;
      }
      final splitTotal = splits.fold(0, (s, p) => s + p.amount);
      final expectedSplitTotal = cart.total - (_tipIsCash ? (tip ?? 0) : 0);
      if (splitTotal != expectedSplitTotal) {
        setState(() => _error =
            'Split total ${egp(splitTotal)} must equal ${egp(expectedSplitTotal)}');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final discountType =
        _selectedDiscount?.dtype ?? cart.discountType?.apiValue;
    final discountValue = _selectedDiscount?.value ?? cart.discountValue;
    final discountId = _selectedDiscount?.id;
    final paymentMethod = _isSplit
        ? (splits!.length == 1 ? splits.first.method : 'mixed')
        : cart.payment;

    if (!isOnline) {
      final localId = const Uuid().v4();
      await queue.enqueueOrder(PendingOrder(
        localId: localId,
        branchId: shift.branchId,
        shiftId: shift.id,
        paymentMethod: paymentMethod,
        customerName: customer,
        discountType: discountType,
        discountValue: discountValue,
        discountId: discountId,
        amountTendered: tendered,
        tipAmount: tip,
        tipPaymentMethod: tipMethod,
        paymentSplits: splits,
        items: cart.items,
        orderedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      // Task 1.5: Optimistic offline order
      final optimistic = Order(
        id: localId,
        branchId: shift.branchId,
        shiftId: shift.id,
        tellerId: ref.read(authProvider).user!.id,
        tellerName: ref.read(authProvider).user!.name,
        orderNumber: -1,
        status: 'pending_sync',
        paymentMethod: paymentMethod,
        subtotal: cart.subtotal,
        discountType: discountType,
        discountValue: discountValue ?? 0,
        discountAmount: cart.discountAmount,
        taxAmount: 0,
        totalAmount: cart.total,
        customerName: customer,
        notes: cart.notes,
        amountTendered: tendered,
        tipAmount: tip,
        tipPaymentMethod: tipMethod,
        discountId: discountId,
        createdAt: DateTime.now(),
        items: cart.items.map((ci) => OrderItem(
          id: const Uuid().v4(),
          itemName: ci.itemName,
          sizeLabel: ci.sizeLabel,
          unitPrice: ci.unitPrice,
          quantity: ci.quantity,
          lineTotal: ci.lineTotal,
          addons: ci.addons.map((a) => OrderItemAddon(
            id: const Uuid().v4(),
            orderItemId: '',
            addonItemId: a.addonItemId,
            addonName: a.name,
            unitPrice: a.priceModifier,
            quantity: a.quantity,
            lineTotal: a.priceModifier * a.quantity,
          )).toList(),
          optionals: ci.optionals.map((o) => OrderItemOptional(
            id: const Uuid().v4(),
            orderItemId: '',
            optionalFieldId: o.optionalFieldId,
            fieldName: o.name,
            price: o.price,
          )).toList(),
        )).toList(),
      );
      ref.read(orderHistoryProvider.notifier).addOrder(optimistic);

      final total = cart.total;
      ref.read(cartProvider.notifier).clear();
      
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context,
            order: optimistic,
            total: total,
            changeGiven:
                tendered != null ? (tendered - total).clamp(0, 999999) : null);
      }
      return;
    }

    try {
      final order = await ref.read(orderApiProvider).create(
            branchId: shift.branchId,
            shiftId: shift.id,
            paymentMethod: paymentMethod,
            items: cart.items,
            customerName: customer,
            discountType: discountType,
            discountValue: discountValue,
            discountId: discountId,
            amountTendered: tendered,
            tipAmount: tip,
            tipPaymentMethod: tipMethod,
            paymentSplits: splits,
            idempotencyKey: const Uuid().v4(),
          );
      ref.read(orderHistoryProvider.notifier).addOrder(order);
      final total = cart.total;
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context,
            order: order,
            total: total,
            changeGiven:
                tendered != null ? (tendered - total).clamp(0, 999999) : null);
      }
    } catch (e) {
      if (isNetworkError(e)) {
        final localId = const Uuid().v4();
        await queue.enqueueOrder(PendingOrder(
          localId: localId,
          branchId: shift.branchId,
          shiftId: shift.id,
          paymentMethod: paymentMethod,
          customerName: customer,
          discountType: discountType,
          discountValue: discountValue,
          discountId: discountId,
          amountTendered: tendered,
          tipAmount: tip,
          tipPaymentMethod: tipMethod,
          paymentSplits: splits,
          items: cart.items,
          createdAt: DateTime.now(),
          orderedAt: DateTime.now(),
        ));

        // Task 1.5: Optimistic offline order
        final optimistic = Order(
          id: localId,
          branchId: shift.branchId,
          shiftId: shift.id,
          tellerId: ref.read(authProvider).user!.id,
          tellerName: ref.read(authProvider).user!.name,
          orderNumber: -1,
          status: 'pending_sync',
          paymentMethod: paymentMethod,
          subtotal: cart.subtotal,
          discountType: discountType,
          discountValue: discountValue ?? 0,
          discountAmount: cart.discountAmount,
          taxAmount: 0,
          totalAmount: cart.total,
          customerName: customer,
          notes: cart.notes,
          amountTendered: tendered,
          tipAmount: tip,
          tipPaymentMethod: tipMethod,
          discountId: discountId,
          createdAt: DateTime.now(),
          items: cart.items.map((ci) => OrderItem(
            id: const Uuid().v4(),
            itemName: ci.itemName,
            sizeLabel: ci.sizeLabel,
            unitPrice: ci.unitPrice,
            quantity: ci.quantity,
            lineTotal: ci.lineTotal,
            addons: ci.addons.map((a) => OrderItemAddon(
              id: const Uuid().v4(),
              orderItemId: '',
              addonItemId: a.addonItemId,
              addonName: a.name,
              unitPrice: a.priceModifier,
              quantity: a.quantity,
              lineTotal: a.priceModifier * a.quantity,
            )).toList(),
          )).toList(),
        );
        ref.read(orderHistoryProvider.notifier).addOrder(optimistic);

        final total = cart.total;
        ref.read(cartProvider.notifier).clear();
        if (mounted) {
          Navigator.pop(context);
          ReceiptSheet.show(context,
            order: optimistic,
            total: total,
            changeGiven:
                tendered != null ? (tendered - total).clamp(0, 999999) : null);
        }
      } else {
        setState(() {
          _error = 'Failed to place order — please retry';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final discountState = ref.watch(discountProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height - mq.padding.top - 16;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)))),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(children: [
              Text('Checkout',
                  style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.2, 0), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child)),
                child: Container(
                  key: ValueKey(cart.total),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(egp(cart.total),
                      style: cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
            ]),
          ),
          Container(height: 1, color: AppColors.border),

          Flexible(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(24, 20, 24, mq.viewInsets.bottom + 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task 2.2: Show offline status
                  if (!isOnline)
                    const SyncStatusBanner(
                      variant: SyncBannerVariant.offline,
                      text: 'Offline — order will sync when reconnected.'
                    ),

                  _SummaryCard(cart: cart),
                  const SizedBox(height: 20),

                  const FieldLabel('CUSTOMER NAME (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: cairo(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ahmed',
                      hintStyle:
                          cairo(fontSize: 15, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          size: 18, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!discountState.isLoading && discountState.items.isNotEmpty) ...[
                    const FieldLabel('DISCOUNT (OPTIONAL)'),
                    const SizedBox(height: 8),
                    _DiscountPicker(
                      discounts: discountState.items,
                      selected: _selectedDiscount,
                      onSelect: (d) {
                        setState(() => _selectedDiscount = d);
                        if (d == null) {
                          ref
                              .read(cartProvider.notifier)
                              .setDiscount(null, null);
                        } else {
                          ref.read(cartProvider.notifier).setDiscount(
                              DiscountType.values.byName(d.dtype), d.value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  Row(children: [
                    const FieldLabel('PAYMENT'),
                    const Spacer(),
                    _SplitToggle(
                      active: _isSplit,
                      onToggle: () => setState(() {
                        _isSplit = !_isSplit;
                        if (!_isSplit) {
                          for (final c in _splitCtrs.values) c.clear();
                          _activeSplitMethods.clear();
                          final pay = ref.read(cartProvider).payment;
                          _showTendered =
                              pay == 'cash' || pay == 'talabat_cash';
                        } else {
                          _showTendered = false;
                        }
                      }),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  if (_isSplit)
                    _SplitPaymentSection(
                      activeMethods: _activeSplitMethods,
                      splitCtrs: _splitCtrs,
                      cartTotal: cart.total,
                      onToggleMethod: _toggleSplitMethod,
                      onAmountChanged: () => setState(() {}),
                      parsedTip: _parsedTip,
                      tipPaymentMethod: _tipPaymentMethod,
                    )
                  else ...[
                    _SinglePaymentGrid(
                      selected: cart.payment,
                      onSelect: (v) {
                        ref.read(cartProvider.notifier).setPayment(v);
                        setState(() =>
                            _showTendered = v == 'cash' || v == 'talabat_cash');
                      },
                    ),

                    if (_showTendered) ...[
                      const SizedBox(height: 20),
                      _CashTenderedSection(
                        tenderedCtrl: _tenderedCtrl,
                        cartTotal: cart.total,
                        onChanged: () => setState(() {}),
                        cashTip: _tipIsCash ? _parsedTip : null,
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),
                  _TipSection(
                    tipCtrl: _tipCtrl,
                    tipPaymentMethod: _tipPaymentMethod,
                    parsedTip: _parsedTip,
                    onMethodChanged: (m) =>
                        setState(() => _tipPaymentMethod = m),
                    onAmountChanged: () => setState(() {}),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.07),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xs)),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 14, color: AppColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: cairo(
                                            fontSize: 13,
                                            color: AppColors.danger))),
                              ]),
                            ))
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, mq.padding.bottom + 16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: AppButton(
              label: 'Place Order',
              loading: _loading,
              width: double.infinity,
              height: 52,
              icon: Icons.check_rounded,
              onTap: _place,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CartState cart;
  const _SummaryCard({required this.cart});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          LabelValue('Subtotal', egp(cart.subtotal)),
          if (cart.discountAmount > 0)
            LabelValue('Discount', '− ${egp(cart.discountAmount)}',
                valueColor: AppColors.success),
          const Divider(height: 16, color: AppColors.border),
          LabelValue('Total', egp(cart.total), bold: true),
        ]),
      );
}

class _SplitToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;
  const _SplitToggle({required this.active, required this.onToggle});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withOpacity(0.1) : AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
                color: active ? AppColors.primary : AppColors.border),
          ),
          child: Text('Split',
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      active ? AppColors.primary : AppColors.textSecondary)),
        ),
      );
}

class _DiscountPicker extends StatelessWidget {
  final List<Discount> discounts;
  final Discount? selected;
  final void Function(Discount?) onSelect;
  const _DiscountPicker(
      {required this.discounts,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('None', null, selected == null, AppColors.primary),
          ...discounts.map((d) =>
              _chip(d.label, d, selected?.id == d.id, AppColors.success)),
        ],
      );

  Widget _chip(String label, Discount? d, bool sel, Color color) =>
      GestureDetector(
        onTap: () => onSelect(sel ? null : d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color : AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
                color: sel ? color : AppColors.border, width: sel ? 1.5 : 1),
          ),
          child: Text(label,
              style: cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textPrimary)),
        ),
      );
}

class _SinglePaymentGrid extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _SinglePaymentGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (ctx, constraints) {
        final btnW = (constraints.maxWidth - 8) / 2;
        // Task 4.1: Use new enum logic
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PaymentMethod.values.where((m) => m != PaymentMethod.mixed).map((m) {
            final sel = selected == m.wireFormat;
            return GestureDetector(
              onTap: () => onSelect(m.wireFormat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: btnW,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                    color: sel ? m.color : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                        color: sel ? m.color : AppColors.border,
                        width: sel ? 1.5 : 1)),
                child: Row(children: [
                  Icon(m.icon, size: 20, color: sel ? Colors.white : m.color),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(m.label,
                          style: cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  sel ? Colors.white : AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  if (sel) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded,
                        size: 15, color: Colors.white)
                  ],
                ]),
              ),
            );
          }).toList(),
        );
      });
}

class _CashTenderedSection extends StatelessWidget {
  final TextEditingController tenderedCtrl;
  final int cartTotal;
  final VoidCallback onChanged;
  final int? cashTip;
  const _CashTenderedSection({
    required this.tenderedCtrl,
    required this.cartTotal,
    required this.onChanged,
    this.cashTip,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('CASH TENDERED'),
          const SizedBox(height: 8),
          TextField(
            controller: tenderedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style: cairo(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'EGP  ',
              prefixStyle: cairo(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              hintText: '0',
              hintStyle: cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.border),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
          Builder(builder: (_) {
            final tendered = double.tryParse(tenderedCtrl.text);
            if (tendered == null || tendered == 0) {
              return const SizedBox.shrink();
            }
            final tenderedP = (tendered * 100).round();
            final change = tenderedP - cartTotal - (cashTip ?? 0);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: change >= 0
                    ? AppColors.success.withOpacity(0.07)
                    : AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                    color: change >= 0
                        ? AppColors.success.withOpacity(0.25)
                        : AppColors.danger.withOpacity(0.25)),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(change >= 0 ? 'Change due:' : 'Insufficient:',
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: change >= 0
                                ? AppColors.success
                                : AppColors.danger)),
                    Text(egp(change.abs()),
                        style: cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: change >= 0
                                ? AppColors.success
                                : AppColors.danger)),
                  ]),
            );
          }),
        ],
      );
}

class _TipSection extends StatelessWidget {
  final TextEditingController tipCtrl;
  final String tipPaymentMethod;
  final int? parsedTip;
  final void Function(String) onMethodChanged;
  final VoidCallback onAmountChanged;

  const _TipSection({
    required this.tipCtrl,
    required this.tipPaymentMethod,
    required this.parsedTip,
    required this.onMethodChanged,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: parsedTip != null
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.volunteer_activism_rounded,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            const FieldLabel('TIP (OPTIONAL)'),
            const Spacer(),
            if (parsedTip != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Container(
                  key: ValueKey(parsedTip),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(egp(parsedTip!),
                      style: cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          // Task 4.1: Enum usage
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: PaymentMethod.values.where((m) => m != PaymentMethod.mixed).map((method) {
              final sel = tipPaymentMethod == method.wireFormat;
              final color = method.color;
              return GestureDetector(
                onTap: () => onMethodChanged(method.wireFormat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? color : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                        color: sel ? color : AppColors.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (sel) ...[
                      const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 4)
                    ],
                    Text(method.label,
                        style: cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                sel ? Colors.white : AppColors.textSecondary)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tipCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onAmountChanged(),
            style: cairo(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'EGP  ',
              prefixStyle: cairo(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              hintText: '0',
              hintStyle: cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.border),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
        ]),
      );
}

class _SplitPaymentSection extends StatelessWidget {
  final Set<String> activeMethods;
  final Map<String, TextEditingController> splitCtrs;
  final int cartTotal;
  final void Function(String) onToggleMethod;
  final VoidCallback onAmountChanged;
  final int? parsedTip;
  final String tipPaymentMethod;

  const _SplitPaymentSection({
    required this.activeMethods,
    required this.splitCtrs,
    required this.cartTotal,
    required this.onToggleMethod,
    required this.onAmountChanged,
    required this.parsedTip,
    required this.tipPaymentMethod,
  });

  List<PaymentSplit> _buildSplits() {
    final splits = <PaymentSplit>[];
    for (final method in activeMethods) {
      final raw = double.tryParse(splitCtrs[method]?.text ?? '');
      if (raw != null && raw > 0) {
        splits.add(PaymentSplit(method: method, amount: (raw * 100).round()));
      }
    }
    return splits;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('SELECT METHODS USED'),
          const SizedBox(height: 10),
          // Task 4.1: Enum usage
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values.where((m) => m != PaymentMethod.mixed).map((method) {
              final color = method.color;
              final active = activeMethods.contains(method.wireFormat);
              return GestureDetector(
                onTap: () => onToggleMethod(method.wireFormat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? color : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                        color: active ? color : AppColors.border,
                        width: active ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        active
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: active ? Colors.white : color),
                    const SizedBox(width: 6),
                    Text(method.label,
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                active ? Colors.white : AppColors.textPrimary)),
                  ]),
                ),
              );
            }).toList(),
          ),
          if (activeMethods.isNotEmpty) ...[
            const SizedBox(height: 16),
            const FieldLabel('ENTER AMOUNTS'),
            const SizedBox(height: 10),
            ...activeMethods.map((method) {
              final pm = PaymentMethod.fromWire(method);
              final color = pm.color;
              final ctrl = splitCtrs[method];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(pm.label,
                            style: cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ]),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => onAmountChanged(),
                        style: cairo(fontSize: 20, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'EGP  ',
                          prefixStyle: cairo(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              borderSide:
                                  BorderSide(color: color.withOpacity(0.3))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              borderSide:
                                  BorderSide(color: color.withOpacity(0.3))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              borderSide:
                                  BorderSide(color: color, width: 2)),
                          filled: true,
                          fillColor: color.withOpacity(0.03),
                        ),
                      ),
                    ]),
              );
            }),

            Builder(builder: (context) {
              final splits = _buildSplits();
              final entered = splits.fold(0, (s, p) => s + p.amount);
              final isCashTip = PaymentMethod.fromWire(tipPaymentMethod).isCash;
              final tipOffset =
                  (isCashTip && parsedTip != null) ? parsedTip! : 0;
              final diff = cartTotal - entered - tipOffset;
              final ok = diff == 0;
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ok
                      ? AppColors.success.withOpacity(0.07)
                      : AppColors.warning.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: ok
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(
                            ok
                                ? Icons.check_circle_outline_rounded
                                : Icons.pending_outlined,
                            size: 16,
                            color:
                                ok ? AppColors.success : AppColors.warning),
                        const SizedBox(width: 8),
                        Text(ok ? 'Balanced ✓' : 'Remaining',
                            style: cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ok
                                    ? AppColors.success
                                    : AppColors.warning)),
                      ]),
                      if (!ok)
                        Text(egp(diff.abs()),
                            style: cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning)),
                    ]),
              );
            }),
          ],
        ],
      );
}
EOF

echo "Writing lib/features/order/widgets/item_detail_sheet.dart..."
cat << 'EOF' > lib/features/order/widgets/item_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/menu_api.dart';
import '../../../core/api/recipe_api.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/menu.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/providers/menu_notifier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/responsive_sheet.dart';
import '../helpers/payment_helpers.dart';
import 'addon_card.dart';
import 'optional_fields_card.dart';
import 'recipe_sheet.dart';
import 'shared_widgets.dart';

class ItemDetailSheet extends ConsumerStatefulWidget {
  final MenuItem item;
  final int? editIndex;
  final CartItem? existingItem;

  const ItemDetailSheet({
    super.key,
    required this.item,
    this.editIndex,
    this.existingItem,
  });

  // Task 3.2: ResponsiveSheet
  static Future<void> show(BuildContext ctx, MenuItem item,
          {int? editIndex, CartItem? existingItem}) =>
      ResponsiveSheet.show(
          context: ctx,
          builder: (_) => ItemDetailSheet(
              item: item, editIndex: editIndex, existingItem: existingItem));

  @override
  ConsumerState<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet> {
  String? _selectedSize;
  int _qty = 1;

  final Map<String, String> _single = {};
  final Map<String, Map<String, int>> _multi = {};
  final Map<String, Map<String, int>> _extras = {};
  final Map<String, String> _extrasSingle = {};
  
  final Map<String, int> _baseSwapPrices = {};

  static const _singleSelectTypes = {'milk_type'};

  late List<OptionalField> _optionalFields;
  final Set<String> _selectedOptionals = {};

  bool _recipeLoading = false;

  bool get _isEdit => widget.editIndex != null && widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) {
      _selectedSize = widget.item.sizes.first.label;
    }

    _optionalFields = widget.item.optionalFields.where((f) => f.isActive).toList();
    _initBaseMilk();

    if (_isEdit) {
      final existing = widget.existingItem!;
      _selectedSize = existing.sizeLabel;
      _qty = existing.quantity;

      final allAddons = ref.read(menuProvider).allAddons;
      final slottedTypes =
          widget.item.addonSlots.map((s) => s.addonType).toSet();
      for (final so in existing.optionals) {
        _selectedOptionals.add(so.optionalFieldId);
      }

      for (final sa in existing.addons) {
        final addon = allAddons.where((a) => a.id == sa.addonItemId);
        if (addon.isEmpty) continue;
        final addonType = addon.first.addonType;

        final matchingSlot =
            widget.item.addonSlots.where((s) => s.addonType == addonType);

        if (matchingSlot.isNotEmpty) {
          final slot = matchingSlot.first;
          final isMulti = (slot.maxSelections ?? 2) > 1;
          if (isMulti) {
            _multi.putIfAbsent(slot.id, () => {})[sa.addonItemId] = sa.quantity;
          } else {
            _single[slot.id] = sa.addonItemId;
          }
        } else if (!slottedTypes.contains(addonType)) {
          if (_singleSelectTypes.contains(addonType)) {
            _extrasSingle[addonType] = sa.addonItemId;
          } else {
            _extras.putIfAbsent(addonType, () => {})[sa.addonItemId] =
                sa.quantity;
          }
        }
      }
    }
  }

  int get _unitPrice => widget.item.priceForSize(_selectedSize);

  int get _optionalsTotal => _optionalFields
      .where((f) => _selectedOptionals.contains(f.id))
      .fold(0, (s, f) => s + f.price);

  int _adjustedPrice(AddonItem a) {
    if (a.addonType == 'milk_type' || a.addonType == 'coffee_type') {
      final base = _baseSwapPrices[a.addonType] ?? 0;
      final diff = a.defaultPrice - base;
      return diff > 0 ? diff : 0;
    }
    return a.defaultPrice;
  }

  int get _addonsTotal {
    final allAddons = ref.read(menuProvider).allAddons;
    int t = 0;

    for (final aId in _single.values) {
      final matches = allAddons.where((a) => a.id == aId);
      if (matches.isNotEmpty) t += _adjustedPrice(matches.first);
    }
    for (final qtyMap in _multi.values) {
      for (final entry in qtyMap.entries) {
        final matches = allAddons.where((a) => a.id == entry.key);
        if (matches.isNotEmpty) t += _adjustedPrice(matches.first) * entry.value;
      }
    }
    for (final typeMap in _extras.values) {
      for (final entry in typeMap.entries) {
        final matches = allAddons.where((a) => a.id == entry.key);
        if (matches.isNotEmpty) t += _adjustedPrice(matches.first) * entry.value;
      }
    }
    for (final aId in _extrasSingle.values) {
      final matches = allAddons.where((a) => a.id == aId);
      if (matches.isNotEmpty) t += _adjustedPrice(matches.first);
    }
    return t;
  }

  int get _lineTotal => (_unitPrice + _addonsTotal + _optionalsTotal) * _qty;

  String? get _firstUnsatisfiedSlot {
    for (final s in widget.item.addonSlots) {
      if (!s.isRequired) continue;
      final min = s.minSelections.clamp(1, 999);
      final isMulti = (s.maxSelections ?? 2) > 1;
      final count = isMulti
          ? (_multi[s.id]?.length ?? 0)
          : (_single.containsKey(s.id) ? 1 : 0);
      if (count < min) return s.displayName;
    }
    return null;
  }

  bool get _canAdd => _firstUnsatisfiedSlot == null;

  void _toggleSingle(String slotId, String addonId, bool required) =>
      setState(() {
        if (_single[slotId] == addonId) {
          if (!required) _single.remove(slotId);
        } else {
          _single[slotId] = addonId;
        }
      });

  void _toggleMulti(String slotId, String addonId, int? maxSel) =>
      setState(() {
        final m = _multi.putIfAbsent(slotId, () => {});
        if (m.containsKey(addonId)) {
          m.remove(addonId);
          if (m.isEmpty) _multi.remove(slotId);
        } else {
          if (maxSel != null && m.length >= maxSel) return;
          m[addonId] = 1;
        }
      });

  void _incrementMulti(String slotId, String addonId) => setState(() {
        _multi.putIfAbsent(slotId, () => {})[addonId] =
            (_multi[slotId]![addonId] ?? 1) + 1;
      });

  void _decrementMulti(String slotId, String addonId) => setState(() {
        final m = _multi[slotId];
        if (m == null) return;
        final cur = m[addonId] ?? 1;
        if (cur <= 1) {
          m.remove(addonId);
          if (m.isEmpty) _multi.remove(slotId);
        } else {
          m[addonId] = cur - 1;
        }
      });

  void _toggleExtraSingle(String addonType, String addonId) => setState(() {
        if (_extrasSingle[addonType] == addonId) {
          _extrasSingle.remove(addonType);
        } else {
          _extrasSingle[addonType] = addonId;
        }
      });

  void _toggleExtra(String addonType, String addonId) => setState(() {
        final typeMap = _extras.putIfAbsent(addonType, () => {});
        if (typeMap.containsKey(addonId)) {
          typeMap.remove(addonId);
          if (typeMap.isEmpty) _extras.remove(addonType);
        } else {
          typeMap[addonId] = 1;
        }
      });

  void _incrementExtra(String addonType, String addonId) => setState(() {
        final typeMap = _extras.putIfAbsent(addonType, () => {});
        typeMap[addonId] = (typeMap[addonId] ?? 1) + 1;
      });

  void _decrementExtra(String addonType, String addonId) => setState(() {
        final typeMap = _extras[addonType];
        if (typeMap == null) return;
        final cur = typeMap[addonId] ?? 1;
        if (cur <= 1) {
          typeMap.remove(addonId);
          if (typeMap.isEmpty) _extras.remove(addonType);
        } else {
          typeMap[addonId] = cur - 1;
        }
      });

  void _showRecipeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => RecipeSheet(
        itemName: normaliseName(widget.item.name),
        sizeLabel: _selectedSize,
        fetchRecipe: () => ref.read(recipeApiProvider).preview(
          menuItemId:   widget.item.id,
          sizeLabel:    _selectedSize,
          addons:       _buildSelectedAddons(),
          optionals:    _buildSelectedOptionals(),
          menuItem:     widget.item,
          allAddonItems: ref.read(menuProvider).allAddons,
        ),
      ),
    );
  }

  void _initBaseMilk() {
    final defaultId = widget.item.defaultMilkAddonId;
    if (defaultId == null) return;

    final allAddons = ref.read(menuProvider).allAddons;
    final defaultMilkAddon = allAddons.where((a) => a.id == defaultId).firstOrNull;

    if (defaultMilkAddon != null) {
      _baseSwapPrices['milk_type'] = defaultMilkAddon.defaultPrice;
      if (!_isEdit && _extrasSingle['milk_type'] == null) {
        _extrasSingle['milk_type'] = defaultMilkAddon.id;
      }
    }
  }

  List<SelectedOptional> _buildSelectedOptionals() {
    return _optionalFields
        .where((f) => _selectedOptionals.contains(f.id))
        .map((f) => SelectedOptional(
              optionalFieldId: f.id,
              name: f.name,
              price: f.price,
            ))
        .toList();
  }

  List<SelectedAddon> _buildSelectedAddons() {
    final allAddons = ref.read(menuProvider).allAddons;
    final result = <SelectedAddon>[];

    AddonItem? findAddon(String id) {
      final matches = allAddons.where((a) => a.id == id);
      return matches.isNotEmpty ? matches.first : null;
    }

    for (final aId in _single.values) {
      final a = findAddon(aId);
      if (a != null) {
        result.add(SelectedAddon(
            addonItemId: a.id,
            name: a.name,
            priceModifier: _adjustedPrice(a),
            quantity: 1));
      }
    }

    for (final qtyMap in _multi.values) {
      for (final entry in qtyMap.entries) {
        final a = findAddon(entry.key);
        if (a != null) {
          result.add(SelectedAddon(
              addonItemId: a.id,
              name: a.name,
              priceModifier: _adjustedPrice(a),
              quantity: entry.value));
        }
      }
    }

    for (final typeMap in _extras.values) {
      for (final entry in typeMap.entries) {
        final a = findAddon(entry.key);
        if (a != null) {
          result.add(SelectedAddon(
              addonItemId: a.id,
              name: a.name,
              priceModifier: _adjustedPrice(a),
              quantity: entry.value));
        }
      }
    }

    for (final aId in _extrasSingle.values) {
      final a = findAddon(aId);
      if (a != null) {
        result.add(SelectedAddon(
            addonItemId: a.id,
            name: a.name,
            priceModifier: _adjustedPrice(a),
            quantity: 1));
      }
    }

    return result;
  }

  void _addToCart() {
    final addons = _buildSelectedAddons();
    final optionals = _buildSelectedOptionals();
    final cartItem = CartItem(
      menuItemId: widget.item.id,
      itemName: normaliseName(widget.item.name),
      sizeLabel: _selectedSize,
      unitPrice: _unitPrice,
      quantity: _qty,
      addons: addons,
      optionals: optionals,
    );

    final notifier = ref.read(cartProvider.notifier);
    if (_isEdit) {
      notifier.replaceAt(widget.editIndex!, cartItem);
    } else {
      notifier.add(cartItem);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final byType = ref.watch(menuProvider).addonsByType;

    final slottedTypes =
        widget.item.addonSlots.map((s) => s.addonType).toSet();

    const globalTypes = ['milk_type', 'coffee_type', 'extra'];
    final unslottedTypes = globalTypes
        .where((t) => !slottedTypes.contains(t))
        .where((t) => (byType[t] ?? []).any((a) => a.isActive))
        .toList();

    final sortedSlots = widget.item.addonSlots.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    List<AddonItem> getItemsWithAdjustedPrice(String type) {
      final list = (byType[type] ?? []).where((a) => a.isActive).toList();
      if (type == 'milk_type' || type == 'coffee_type') {
        return list.map((a) {
          return AddonItem(
            id: a.id,
            name: a.name,
            addonType: a.addonType,
            defaultPrice: _adjustedPrice(a),
            isActive: a.isActive,
            displayOrder: a.displayOrder,
            primaryIngredientId: a.primaryIngredientId,
          );
        }).toList();
      }
      return list;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.90),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: AppRadius.sheetRadius),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))))),

          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(normaliseName(widget.item.name),
                        style: cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    if (widget.item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(widget.item.description!,
                          style: cairo(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.4)),
                    ],
                  ])),
              const SizedBox(width: 10),

              GestureDetector(
                onTap: _showRecipeSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _recipeLoading
                        ? const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.primary))
                        : const Icon(Icons.science_outlined,
                            size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text('Recipe',
                        style: cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, -0.3), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child)),
                child: Container(
                  key: ValueKey(_unitPrice + _addonsTotal),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(egp(_unitPrice + _addonsTotal + _optionalsTotal),
                      style: cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
            ]),
          ),

          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.item.sizes.isNotEmpty) ...[
                const SectionLabel('Size'),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.item.sizes
                        .map((s) => SelectableChip(
                              label: normaliseName(s.label),
                              sublabel: egp(s.price),
                              selected: s.label == _selectedSize,
                              checkbox: false,
                              onTap: () => setState(() {
                                _selectedSize = s.label;
                              }),
                            ))
                        .toList()),
                const SizedBox(height: 20),
              ],

              for (final s in sortedSlots) ...[
                AddonCard(
                  title: s.displayName,
                  isRequired: s.isRequired,
                  isMulti: (s.maxSelections ?? 2) > 1,
                  maxSelections: s.maxSelections,
                  items: getItemsWithAdjustedPrice(s.addonType),
                  selectedSingle: _single[s.id],
                  selectedMulti: _multi[s.id] ?? {},
                  onToggleSingle: (aId) =>
                      _toggleSingle(s.id, aId, s.isRequired),
                  onToggleMulti: (aId) =>
                      _toggleMulti(s.id, aId, s.maxSelections),
                  onIncrement: (aId) => _incrementMulti(s.id, aId),
                  onDecrement: (aId) => _decrementMulti(s.id, aId),
                  accentColor: addonTypeColor(s.addonType),
                ),
                const SizedBox(height: 12),
              ],

              if (unslottedTypes.contains('milk_type')) ...[
                AddonCard(
                  title: addonTypeLabel('milk_type'),
                  isRequired: false,
                  isMulti: false,
                  maxSelections: null,
                  items: getItemsWithAdjustedPrice('milk_type'),
                  selectedSingle: _extrasSingle['milk_type'],
                  selectedMulti: const {},
                  onToggleSingle: (aId) =>
                      _toggleExtraSingle('milk_type', aId),
                  onToggleMulti: (_) {},
                  onIncrement: (_) {},
                  onDecrement: (_) {},
                  accentColor: addonTypeColor('milk_type'),
                ),
                const SizedBox(height: 12),
              ],

              if (_optionalFields.isNotEmpty) ...[
                OptionalFieldsCard(
                  fields: _optionalFields,
                  selected: _selectedOptionals,
                  sizeLabel: _selectedSize,
                  onToggle: (id) => setState(() {
                    if (_selectedOptionals.contains(id)) {
                      _selectedOptionals.remove(id);
                    } else {
                      _selectedOptionals.add(id);
                    }
                  }),
                ),
                const SizedBox(height: 12),
              ],

              for (final addonType in unslottedTypes.where((t) => t != 'milk_type')) ...[
                if (_singleSelectTypes.contains(addonType))
                  AddonCard(
                    title: addonTypeLabel(addonType),
                    isRequired: false,
                    isMulti: false,
                    maxSelections: null,
                    items: getItemsWithAdjustedPrice(addonType),
                    selectedSingle: _extrasSingle[addonType],
                    selectedMulti: const {},
                    onToggleSingle: (aId) =>
                        _toggleExtraSingle(addonType, aId),
                    onToggleMulti: (_) {},
                    onIncrement: (_) {},
                    onDecrement: (_) {},
                    accentColor: addonTypeColor(addonType),
                  )
                else
                  AddonCard(
                    title: addonTypeLabel(addonType),
                    isRequired: false,
                    isMulti: true,
                    maxSelections: null,
                    items: getItemsWithAdjustedPrice(addonType),
                    selectedSingle: null,
                    selectedMulti: _extras[addonType] ?? {},
                    onToggleSingle: (_) {},
                    onToggleMulti: (aId) => _toggleExtra(addonType, aId),
                    onIncrement: (aId) => _incrementExtra(addonType, aId),
                    onDecrement: (aId) => _decrementExtra(addonType, aId),
                    accentColor: addonTypeColor(addonType),
                  ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 6),
            ]),
          )),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  QtyBtn(
                      icon: Icons.remove,
                      onTap: () =>
                          setState(() => _qty = (_qty - 1).clamp(1, 99))),
                  SizedBox(
                      width: 40,
                      child: Center(
                          child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Text('$_qty',
                                  key: ValueKey(_qty),
                                  style: cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800))))),
                  QtyBtn(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => _qty = (_qty + 1).clamp(1, 99))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: AppButton(
                label: _canAdd
                    ? '${_isEdit ? "Update" : "Add"}  —  ${egp(_lineTotal)}'
                    : 'Select ${_firstUnsatisfiedSlot ?? "required options"}',
                height: 50,
                onTap: _canAdd ? _addToCart : null,
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
EOF

echo "Writing lib/features/order/widgets/receipt_sheet.dart..."
cat << 'EOF' > lib/features/order/widgets/receipt_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../core/models/order.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/label_value.dart';
import '../../../shared/widgets/responsive_sheet.dart';
import '../helpers/payment_helpers.dart';

class ReceiptSheet extends ConsumerStatefulWidget {
  final Order order;
  final int total;
  final int? changeGiven;
  const ReceiptSheet(
      {super.key, required this.order, required this.total, this.changeGiven});

  // Task 3.2: ResponsiveSheet
  static Future<void> show(BuildContext ctx,
          {required Order order, required int total, int? changeGiven}) =>
      ResponsiveSheet.show(
          context: ctx,
          builder: (_) => ReceiptSheet(
              order: order, total: total, changeGiven: changeGiven));

  @override
  ConsumerState<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<ReceiptSheet> {
  bool _printing = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _print();
    });
  }

  Future<void> _print() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) return;
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.print(
        ip: branch.printerIp!,
        port: branch.printerPort,
        brand: branch.printerBrand!,
        order: widget.order,
        branchName: branch.name);
    if (mounted) {
      setState(() {
        _printing = false;
        _printError = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        SizedBox(
            width: 110,
            height: 110,
            child: Lottie.asset('assets/lottie/success.json',
                repeat: false, fit: BoxFit.contain)),
        const SizedBox(height: 10),
        Text('Order Placed!',
            style: cairo(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Order #${o.orderNumber}',
            style: cairo(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border)),
          child: Column(children: [
            LabelValue('Payment', methodLabel(o.paymentMethod)),
            if (o.tipAmount != null && o.tipAmount! > 0)
              LabelValue('Tip',
                  '${egp(o.tipAmount!)}${o.tipPaymentMethod != null ? " · ${methodLabel(o.tipPaymentMethod!)}" : ""}',
                  valueColor: AppColors.success),
            if (o.customerName != null && o.customerName!.isNotEmpty)
              LabelValue('Customer', o.customerName!),
            LabelValue('Total', egp(o.totalAmount), bold: true),
            LabelValue('Time', timeShort(o.createdAt)),
            if (widget.changeGiven != null && widget.changeGiven! > 0)
              LabelValue('Change Given', egp(widget.changeGiven!),
                  valueColor: AppColors.success),
          ]),
        ),
        const SizedBox(height: 16),
        _printing
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Printing…',
                    style: cairo(fontSize: 13, color: AppColors.textSecondary)),
              ])
            : GestureDetector(
                onTap: _print,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: (_printError != null
                              ? AppColors.danger
                              : AppColors.primary)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.xs)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.print_rounded,
                        size: 15,
                        color: _printError != null
                            ? AppColors.danger
                            : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                        _printError != null ? 'Retry Print' : 'Reprint Receipt',
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _printError != null
                                ? AppColors.danger
                                : AppColors.primary)),
                  ]),
                ),
              ),
        const SizedBox(height: 16),
        AppButton(
            label: 'New Order',
            width: double.infinity,
            height: 52,
            icon: Icons.add_rounded,
            onTap: () => Navigator.pop(context)),
      ]),
    );
  }
}
EOF

echo "Writing lib/features/order/void_order_sheet.dart..."
cat << 'EOF' > lib/features/order/void_order_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/models/pending_action.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/responsive_sheet.dart';

class VoidOrderSheet extends ConsumerStatefulWidget {
  final Order order;
  final void Function(Order) onVoided;
  const VoidOrderSheet(
      {super.key, required this.order, required this.onVoided});

  // Task 3.2: Use ResponsiveSheet
  static Future<void> show(
      BuildContext ctx, Order order, void Function(Order) onVoided) =>
      ResponsiveSheet.show(
          context: ctx,
          builder: (_) => VoidOrderSheet(order: order, onVoided: onVoided));

  @override
  ConsumerState<VoidOrderSheet> createState() => _VoidOrderSheetState();
}

class _VoidOrderSheetState extends ConsumerState<VoidOrderSheet> {
  String? _reason;
  final _otherCtrl = TextEditingController(); // Task 3.8
  bool    _restore = true, _loading = false;
  String? _error;

  static const _reasons = [
    ('customer_request', 'Customer request'),
    ('wrong_order',      'Wrong order'),
    ('quality_issue',    'Quality issue'),
    ('other',            'Other'),
  ];

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact(); // Task 3.4

    if (_reason == null) {
      setState(() => _error = 'Please select a reason');
      return;
    }
    
    // Task 3.8: Other reasoning
    String finalReason = _reason!;
    if (_reason == 'other') {
      final otherText = _otherCtrl.text.trim();
      if (otherText.isEmpty) {
        setState(() => _error = 'Please specify the other reason');
        return;
      }
      finalReason = 'other: $otherText';
    }

    setState(() { _loading = true; _error = null; });
    final isOnline = ConnectivityService.instance.isOnline;
    final now      = DateTime.now();

    try {
      if (isOnline) {
        final updated = await ref.read(orderApiProvider).voidOrder(
          widget.order.id,
          reason:           finalReason,
          restoreInventory: _restore,
          voidedAt:         now,
        );
        if (mounted) { Navigator.pop(context); widget.onVoided(updated); }
      } else {
        await ref.read(offlineQueueProvider.notifier).enqueueVoid(
          PendingVoidOrder(
            localId:          const Uuid().v4(),
            createdAt:        now,
            orderId:          widget.order.id,
            reason:           finalReason,
            restoreInventory: _restore,
            voidedAt:         now,
          ),
        );
        final optimistic = Order(
          id:             widget.order.id,
          branchId:       widget.order.branchId,
          shiftId:        widget.order.shiftId,
          tellerId:       widget.order.tellerId,
          tellerName:     widget.order.tellerName,
          orderNumber:    widget.order.orderNumber,
          status:         'voided',
          paymentMethod:  widget.order.paymentMethod,
          subtotal:       widget.order.subtotal,
          discountType:   widget.order.discountType,
          discountValue:  widget.order.discountValue,
          discountAmount: widget.order.discountAmount,
          taxAmount:      widget.order.taxAmount,
          totalAmount:    widget.order.totalAmount,
          customerName:   widget.order.customerName,
          notes:          widget.order.notes,
          voidReason:     finalReason,
          createdAt:      widget.order.createdAt,
          items:          widget.order.items,
        );
        if (mounted) { Navigator.pop(context); widget.onVoided(optimistic); }
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ConnectivityService.instance.isOnline;
    return Container(
      margin:  const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.border,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Void Order #${widget.order.orderNumber}',
            style: cairo(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          isOnline
              ? 'This action cannot be undone'
              : 'Offline — void will be queued and applied when reconnected',
          style: cairo(fontSize: 13,
              color: isOnline ? AppColors.textSecondary : AppColors.warning),
        ),
        const SizedBox(height: 20),
        Text('Reason', style: cairo(fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ...(_reasons.map((r) => RadioListTile<String>(
          value: r.$1, groupValue: _reason,
          onChanged: (v) => setState(() {
            _reason = v;
            _error = null;
          }),
          title: Text(r.$2, style: cairo(fontSize: 14)),
          contentPadding: EdgeInsets.zero, dense: true,
          activeColor: AppColors.danger,
        ))),
        
        // Task 3.8: Conditional Other field
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _reason == 'other' 
            ? Padding(
                padding: const EdgeInsets.only(top: 8, left: 32, right: 16),
                child: TextField(
                  controller: _otherCtrl,
                  style: cairo(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Specify reason...',
                    hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        borderSide: const BorderSide(color: AppColors.danger)),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        ),

        const SizedBox(height: 12), const Divider(), const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Restore inventory',
                style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Return ingredients to stock',
                style: cairo(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Switch(value: _restore,
              onChanged: (v) => setState(() => _restore = v),
              activeColor: AppColors.primary),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withOpacity(0.2))),
              child: Text(_error!, style: cairo(fontSize: 12, color: AppColors.danger))),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textSecondary),
            child: Text('Cancel',
                style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isOnline ? 'Void Order' : 'Queue Void',
                    style: cairo(fontSize: 14, fontWeight: FontWeight.w700,
                        color: Colors.white)),
          )),
        ]),
      ]),
    );
  }
}
EOF

echo "Writing lib/features/order/pending_orders_screen.dart..."
cat << 'EOF' > lib/features/order/pending_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/pending_action.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';

class PendingOrdersScreen extends ConsumerWidget {
  const PendingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(offlineQueueProvider);
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: const Text('Pending Sync'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
        actions: [
          if (queue.isSyncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: () =>
                  ref.read(offlineQueueProvider.notifier).syncAll(),
              tooltip: 'Sync now',
            ),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 52, color: AppColors.success.withOpacity(0.5)),
              const SizedBox(height: 14),
              Text('All synced',
                  style: cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ]))
          : Column(children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16, vertical: 12),
                child: Row(children: [
                  if (queue.shiftOpenCount > 0)
                    _Chip('${queue.shiftOpenCount} shift open',
                        AppColors.primary),
                  if (queue.orderCount > 0) ...[
                    if (queue.shiftOpenCount > 0) const SizedBox(width: 8),
                    _Chip('${queue.orderCount} orders', AppColors.success),
                  ],
                  if (queue.shiftCloseCount > 0) ...[
                    const SizedBox(width: 8),
                    _Chip('${queue.shiftCloseCount} shift close',
                        AppColors.warning),
                  ],
                  if (queue.voidCount > 0) ...[
                    const SizedBox(width: 8),
                    _Chip('${queue.voidCount} voids', AppColors.danger),
                  ],
                  if (queue.cashCount > 0) ...[
                    const SizedBox(width: 8),
                    _Chip('${queue.cashCount} cash', AppColors.success),
                  ],
                  if (queue.hasStuck) ...[
                    const SizedBox(width: 8),
                    _Chip('${queue.stuckCount} stuck', AppColors.danger),
                  ],
                ]),
              ),
              Container(height: 1, color: AppColors.border),

              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 20 : 14),
                  itemCount: queue.queue.length,
                  itemBuilder: (_, i) {
                    final action = queue.queue[i];
                    final isStuck = action.retryCount >= 5;
                    return _ActionTile(
                      action: action,
                      isStuck: isStuck,
                      onDiscard: () => ref
                          .read(offlineQueueProvider.notifier)
                          .discard(action.localId),
                      onRetry: isStuck
                          ? () => ref
                              .read(offlineQueueProvider.notifier)
                              .resetRetry(action.localId)
                          : null,
                    );
                  },
                ),
              ),
            ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.xs)),
        child: Text(label,
            style:
                cairo(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class _ActionTile extends StatelessWidget {
  final PendingAction action;
  final bool isStuck;
  final VoidCallback onDiscard;
  final VoidCallback? onRetry;

  const _ActionTile({
    required this.action,
    required this.isStuck,
    required this.onDiscard,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (action) {
      PendingShiftOpen() => (
          Icons.play_arrow_rounded,
          'Open Shift',
          AppColors.primary
        ),
      PendingOrder() => (Icons.receipt_rounded, 'Order', AppColors.success),
      PendingShiftClose() => (
          Icons.lock_outline_rounded,
          'Close Shift',
          AppColors.warning
        ),
      PendingVoidOrder() => (
          Icons.cancel_outlined,
          'Void Order',
          AppColors.danger
        ),
      PendingCashMovement() => (Icons.payments_outlined, 'Cash Movement', AppColors.success),
      _ => (Icons.help_outline_rounded, 'Unknown', AppColors.textMuted),
    };

    final subtitle = switch (action) {
      PendingOrder() => '${(action as PendingOrder).items.length} item(s) · '
          '${egp((action as PendingOrder).items.fold(0, (s, i) => s + i.lineTotal))}',
      PendingShiftOpen() =>
        'Opening cash: ${egp((action as PendingShiftOpen).openingCash)}',
      PendingShiftClose() =>
        'Closing cash: ${egp((action as PendingShiftClose).closingCash)}',
      PendingVoidOrder() =>
        'Reason: ${(action as PendingVoidOrder).reason.replaceAll("_", " ")}',
      PendingCashMovement() =>
        '${(action as PendingCashMovement).amount > 0 ? "Cash In" : "Cash Out"}: ${egp((action as PendingCashMovement).amount.abs())}',
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: isStuck
                ? AppColors.danger.withOpacity(0.25)
                : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(label,
            style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: cairo(fontSize: 12, color: AppColors.textSecondary)),
          Text(dateTime(action.createdAt),
              style: cairo(fontSize: 11, color: AppColors.textMuted)),
          
          // Task 3.5: Per-action inline error message
          if (action.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Error: ${action.lastError}',
                  style: cairo(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500)),
            ),

          if (isStuck)
            Text('Failed ${action.retryCount} times — tap Retry to try again',
                style: cairo(fontSize: 11, color: AppColors.danger)),
          if (!isStuck && action.retryCount > 0)
            Text('${action.retryCount} failed attempt(s)',
                style: cairo(fontSize: 11, color: AppColors.warning)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: cairo(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 17, color: AppColors.danger),
            onPressed: () => _confirmDiscard(context),
            tooltip: 'Discard',
          ),
        ]),
      ),
    );
  }

  void _confirmDiscard(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Discard?', style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
              'This action will be permanently removed from the queue.',
              style: cairo(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: cairo(color: AppColors.textSecondary))),
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact(); // Task 3.4
                Navigator.pop(ctx);
                onDiscard();
              },
              child: Text('Discard',
                  style: cairo(
                      color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
EOF

echo "Writing lib/features/order/order_screen.dart..."
cat << 'EOF' > lib/features/order/order_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/menu_notifier.dart';
import '../../core/providers/discount_notifier.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/top_bar.dart';
import 'widgets/category_rail.dart';
import 'widgets/menu_grid.dart';
import 'widgets/cart_panel.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});
  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = ref.read(authProvider).user?.orgId;
      if (orgId != null) {
        ref.read(menuProvider.notifier).load(orgId);
        ref.read(discountProvider.notifier).load(orgId);
      }
    });

    // Task 3.3: Debounce menu search
    _searchCtrl.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _query = _searchCtrl.text.trim().toLowerCase());
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: isTablet ? null : const MobileCartFab(),
      body: SafeArea(
        child: Column(children: [
          TopBar(ctrl: _searchCtrl, query: _query),
          Expanded(
            child: isTablet
                ? Row(children: [
                    if (_query.isEmpty) const CategoryRail(),
                    Expanded(child: _contentArea()),
                    const CartPanel(),
                  ])
                : Row(children: [
                    if (_query.isEmpty) const CategoryRail(),
                    Expanded(child: _contentArea()),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _contentArea() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(anim),
            child: child,
          ),
        ),
        child: _query.isNotEmpty
            ? SearchResults(key: ValueKey(_query), query: _query)
            : const MenuGrid(key: ValueKey('grid')),
      );
}
EOF

echo "Writing lib/features/order/order_history_screen.dart..."
cat << 'EOF' > lib/features/order/order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_history_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/label_value.dart';
import 'void_order_sheet.dart';
import 'helpers/payment_helpers.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final shiftId = ref.read(shiftProvider).shift?.id;
    if (shiftId == null) return;
    await ref
        .read(orderHistoryProvider.notifier)
        .loadForShift(shiftId, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(orderHistoryProvider);
    final shift = ref.watch(shiftProvider).shift;
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: const Text('Order History'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
        actions: [
          if (shift != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(orderHistoryProvider.notifier).refresh(shift.id),
            ),
        ],
      ),
      body: shift == null
          ? _Placeholder(
              icon: Icons.lock_outline_rounded,
              message: 'No open shift',
              isTablet: isTablet)
          : history.isLoading
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
            EdgeInsets.fromLTRB(isTablet ? 24 : 16, 12, isTablet ? 24 : 16, 12),
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
                color: AppColors.textSecondary),
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
      Container(height: 1, color: AppColors.border),

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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.xs)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8))),
          const SizedBox(width: 6),
          Text(value,
              style: cairo(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class _OrderTile extends ConsumerStatefulWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  ConsumerState<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends ConsumerState<_OrderTile> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final full = await ref.read(orderApiProvider).get(widget.order.id);
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
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
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
    final isPending = o.status == 'pending_sync'; // Task 1.5

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isVoided ? AppColors.bg : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: isVoided ? AppColors.border : AppColors.borderLight),
          boxShadow: isVoided ? [] : AppShadows.card,
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
                        ? AppColors.borderLight
                        : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                alignment: Alignment.center,
                child: isPending 
                    ? const Icon(Icons.sync_rounded, color: AppColors.primary, size: 20)
                    : Text('#${o.orderNumber}',
                    style: cairo(
                        fontSize: 11,
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
                        const _VoidedBadge(),
                      ],
                      if (isPending) ...[
                        const SizedBox(width: 6),
                        const _PendingSyncBadge(),
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

              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textMuted),
            ]),
          ),

          if (_loading)
            Positioned.fill(
                child: Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(AppRadius.md)),
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
    final label = methodLabel(method);
    final color = methodColor(method);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: voided ? AppColors.borderLight : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.xs)),
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
          color: AppColors.danger.withOpacity(0.09),
          borderRadius: BorderRadius.circular(AppRadius.xs)),
      child: Text('VOIDED',
          style: cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
              letterSpacing: 0.3)));
}

// Task 1.5: Pending sync badge
class _PendingSyncBadge extends StatelessWidget {
  const _PendingSyncBadge();

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.xs)),
      child: Text('PENDING SYNC',
          style: cairo(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
              letterSpacing: 0.3)));
}

class _OrderDetailSheet extends ConsumerStatefulWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  late Order _order;
  bool _printing = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _print() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No printer configured for this branch'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.print(
        ip: branch.printerIp!,
        port: branch.printerPort,
        brand: branch.printerBrand!,
        order: _order,
        branchName: branch.name);
    if (mounted)
      setState(() {
        _printing = false;
        _printError = err;
      });
  }

  void _onVoided(Order voided) {
    setState(() => _order = voided);
    ref.read(orderHistoryProvider.notifier).updateOrder(voided);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final isVoided = order.status == 'voided';
    final isPending = order.status == 'pending_sync';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2))))),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(isPending ? 'Pending Order' : 'Order #${order.orderNumber}',
                        style:
                            cairo(fontSize: 18, fontWeight: FontWeight.w800)),
                    if (isVoided) ...[
                      const SizedBox(width: 8),
                      const _VoidedBadge(),
                    ],
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      const _PendingSyncBadge(),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(dateTime(order.createdAt),
                      style:
                          cairo(fontSize: 12, color: AppColors.textSecondary)),
                  if (order.tellerName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('by ${order.tellerName}',
                        style: cairo(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ])),
            if (!isVoided && !isPending) ...[
              _printing
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)))
                  : _SheetAction(
                      icon: Icons.print_rounded,
                      label: _printError != null ? 'Retry' : 'Print',
                      color: _printError != null
                          ? AppColors.danger
                          : AppColors.primary,
                      onTap: _print),
              const SizedBox(width: 8),
              _SheetAction(
                  icon: Icons.cancel_outlined,
                  label: 'Void',
                  color: AppColors.danger,
                  onTap: () => VoidOrderSheet.show(context, order, _onVoided)),
            ],
            if (isPending)
               _SheetAction(
                  icon: Icons.cancel_outlined,
                  label: 'Void',
                  color: AppColors.danger,
                  onTap: () => VoidOrderSheet.show(context, order, _onVoided)),
          ]),
        ),

        Container(height: 1, color: AppColors.border),

        Expanded(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _SectionCard(
              child: order.items.isEmpty
                  ? Text('No item details available',
                      style: cairo(fontSize: 13, color: AppColors.textMuted))
                  : Column(children: [
                      for (int i = 0; i < order.items.length; i++) ...[
                        _ItemRow(item: order.items[i]),
                        if (i < order.items.length - 1)
                          const Divider(
                              height: 1,
                              color: AppColors.borderLight,
                              indent: 14,
                              endIndent: 14),
                      ],
                    ]),
            ),

            const SizedBox(height: 12),

            _SectionCard(
              child: Column(children: [
                LabelValue('Subtotal', egp(order.subtotal)),
                if (order.discountAmount > 0)
                  LabelValue('Discount', '− ${egp(order.discountAmount)}',
                      valueColor: AppColors.success),
                if (order.taxAmount > 0)
                  LabelValue('Tax (14%)', egp(order.taxAmount)),
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(height: 1, color: AppColors.borderLight)),
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

            const SizedBox(height: 12),

            _SectionCard(
              child: Column(children: [
                _MetaRow(Icons.payments_outlined, 'Payment',
                    methodLabel(order.paymentMethod)),
                if (order.customerName != null) ...[
                  const SizedBox(height: 10),
                  _MetaRow(Icons.person_outline_rounded, 'Customer',
                      order.customerName!),
                ],
                const SizedBox(height: 10),
                _MetaRow(Icons.access_time_rounded, 'Time',
                    timeShort(order.createdAt)),
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

  String _voidReasonLabel(String r) {
    if (r.startsWith('other: ')) return r.substring(7);
    return switch (r) {
        'customer_request' => 'Customer request',
        'wrong_order' => 'Wrong order',
        'quality_issue' => 'Quality issue',
        'other' => 'Other',
        _ => r,
      };
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card),
        padding: const EdgeInsets.all(16),
        child: child,
      );
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.xs)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: cairo(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
}

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
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.xs)),
            alignment: Alignment.center,
            child: Text('${item.quantity}',
                style: cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
                        final hasPrice = a.unitPrice > 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.07),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs)),
                          child: Text(
                              hasPrice
                                  ? '${normaliseName(a.addonName)}  +${egp(a.lineTotal)}'
                                  : normaliseName(a.addonName),
                              style: cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
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

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MetaRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(label, style: cairo(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: cairo(fontSize: 12, fontWeight: FontWeight.w700)),
      ]);
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isTablet;
  final bool useLottie;

  const _Placeholder({
    required this.icon,
    required this.message,
    required this.isTablet,
    this.useLottie = false,
  });

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
            Icon(icon, size: isTablet ? 48 : 40, color: AppColors.border),
            const SizedBox(height: 12),
          ],
          Text(message,
              style: cairo(
                  fontSize: isTablet ? 15 : 14,
                  color: AppColors.textSecondary)),
        ]),
      );
}
EOF

echo "Batch 3 complete."