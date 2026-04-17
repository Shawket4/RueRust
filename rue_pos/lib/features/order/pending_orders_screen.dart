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
