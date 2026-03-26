import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/models/pending_action.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';

class VoidOrderSheet extends ConsumerStatefulWidget {
  final Order order;
  final void Function(Order) onVoided;
  const VoidOrderSheet(
      {super.key, required this.order, required this.onVoided});

  static Future<void> show(
      BuildContext ctx, Order order, void Function(Order) onVoided) =>
      showModalBottomSheet(
          context: ctx, isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => VoidOrderSheet(order: order, onVoided: onVoided));

  @override
  ConsumerState<VoidOrderSheet> createState() => _VoidOrderSheetState();
}

class _VoidOrderSheetState extends ConsumerState<VoidOrderSheet> {
  String? _reason;
  bool    _restore = true, _loading = false;
  String? _error;

  static const _reasons = [
    ('customer_request', 'Customer request'),
    ('wrong_order',      'Wrong order'),
    ('quality_issue',    'Quality issue'),
    ('other',            'Other'),
  ];

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Please select a reason');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final isOnline = ConnectivityService.instance.isOnline;
    final now      = DateTime.now();

    try {
      if (isOnline) {
        // Online: void immediately
        final updated = await ref.read(orderApiProvider).voidOrder(
          widget.order.id,
          reason:           _reason!,
          restoreInventory: _restore,
          voidedAt:         now,
        );
        if (mounted) { Navigator.pop(context); widget.onVoided(updated); }
      } else {
        // Offline: queue the void and update local state optimistically
        await ref.read(offlineQueueProvider.notifier).enqueueVoid(
          PendingVoidOrder(
            localId:          const Uuid().v4(),
            createdAt:        now,
            orderId:          widget.order.id,
            reason:           _reason!,
            restoreInventory: _restore,
            voidedAt:         now,
          ),
        );
        // Create an optimistic voided order for the UI
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
          voidReason:     _reason,
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
          onChanged: (v) => setState(() => _reason = v),
          title: Text(r.$2, style: cairo(fontSize: 14)),
          contentPadding: EdgeInsets.zero, dense: true,
        ))),
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
