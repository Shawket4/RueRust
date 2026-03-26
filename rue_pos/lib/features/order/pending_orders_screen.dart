import 'package:flutter/material.dart';
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
    final queue    = ref.watch(offlineQueueProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: Text('Pending Sync',
            style: cairo(fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        backgroundColor: Colors.white, elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
        actions: [
          if (queue.isSyncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: () => ref.read(offlineQueueProvider.notifier).syncAll(),
              tooltip: 'Sync now',
            ),
        ],
      ),
      body: queue.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 56, color: AppColors.success),
              const SizedBox(height: 12),
              Text('All synced', style: cairo(fontSize: 16,
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ]))
          : Column(children: [
              // Summary bar
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
                  if (queue.hasStuck) ...[
                    const SizedBox(width: 8),
                    _Chip('${queue.stuckCount} stuck', AppColors.danger),
                  ],
                ]),
              ),
              Container(height: 1, color: AppColors.border),
              if (queue.lastError != null)
                Container(
                  width: double.infinity,
                  color: AppColors.danger.withOpacity(0.07),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(queue.lastError!,
                        style: cairo(fontSize: 12, color: AppColors.danger))),
                  ]),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 20 : 14),
                  itemCount: queue.queue.length,
                  itemBuilder: (_, i) {
                    final action = queue.queue[i];
                    final isStuck = action.retryCount >= 5;
                    return _ActionTile(
                      action:  action,
                      isStuck: isStuck,
                      onDiscard: () => ref.read(offlineQueueProvider.notifier)
                          .discard(action.localId),
                      onRetry: isStuck
                          ? () => ref.read(offlineQueueProvider.notifier)
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
  final String label; final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: cairo(fontSize: 11,
        fontWeight: FontWeight.w700, color: color)),
  );
}

class _ActionTile extends StatelessWidget {
  final PendingAction action;
  final bool          isStuck;
  final VoidCallback  onDiscard;
  final VoidCallback? onRetry;
  const _ActionTile({required this.action, required this.isStuck,
      required this.onDiscard, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (action) {
      PendingShiftOpen()  => (Icons.play_arrow_rounded,  'Open Shift',   AppColors.primary),
      PendingOrder()      => (Icons.receipt_rounded,      'Order',        AppColors.success),
      PendingShiftClose() => (Icons.lock_outline_rounded, 'Close Shift',  AppColors.warning),
      PendingVoidOrder()  => (Icons.cancel_outlined,      'Void Order',   AppColors.danger),
      _                   => (Icons.help_outline_rounded, 'Unknown',      AppColors.textMuted),
    };

    final subtitle = switch (action) {
      PendingOrder() => '${(action as PendingOrder).items.length} item(s) · '
          '${egp((action as PendingOrder).items.fold(0, (s, i) => s + i.lineTotal))}',
      PendingShiftOpen() => 'Opening cash: ${egp((action as PendingShiftOpen).openingCash)}',
      PendingShiftClose() => 'Closing cash: ${egp((action as PendingShiftClose).closingCash)}',
      PendingVoidOrder() => 'Reason: ${(action as PendingVoidOrder).reason.replaceAll("_", " ")}',
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isStuck
            ? AppColors.danger.withOpacity(0.3) : AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color:        color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(label, style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: cairo(fontSize: 12, color: AppColors.textSecondary)),
          Text(dateTime(action.createdAt),
              style: cairo(fontSize: 11, color: AppColors.textMuted)),
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
              child: Text('Retry', style: cairo(fontSize: 12,
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.danger),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Discard?', style: cairo(fontWeight: FontWeight.w800)),
      content: Text('This action will be permanently removed from the queue.',
          style: cairo(fontSize: 14, color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: cairo(color: AppColors.textSecondary))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); onDiscard(); },
          child: Text('Discard', style: cairo(
              color: AppColors.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
