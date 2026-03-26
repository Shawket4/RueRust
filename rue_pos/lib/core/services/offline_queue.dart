import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../models/order.dart';
import '../models/pending_order.dart';
import '../storage/storage_service.dart';
import 'connectivity_service.dart';

const _kMaxRetries = 5;

class OfflineQueueState {
  final List<PendingOrder> pending;
  final bool               isSyncing;
  final String?            lastError;

  const OfflineQueueState({
    this.pending   = const [],
    this.isSyncing = false,
    this.lastError,
  });

  int  get count      => pending.length;
  int  get stuckCount => pending.where((p) => p.retryCount >= _kMaxRetries).length;
  bool get hasStuck   => stuckCount > 0;

  OfflineQueueState copyWith({
    List<PendingOrder>? pending,
    bool?               isSyncing,
    String?             lastError,
    bool                clearError = false,
  }) => OfflineQueueState(
    pending:   pending   ?? this.pending,
    isSyncing: isSyncing ?? this.isSyncing,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

class OfflineQueueNotifier extends Notifier<OfflineQueueState> {
  /// Wire this to OrderHistoryNotifier.onOrderSynced after creation.
  void Function(Order)? onOrderSynced;

  StreamSubscription<bool>? _sub;

  @override
  OfflineQueueState build() {
    ref.onDispose(() => _sub?.cancel());
    return const OfflineQueueState();
  }

  Future<void> init() async {
    _loadFromStorage();
    _sub = ConnectivityService.instance.stream.listen((online) {
      if (online && state.pending.isNotEmpty) syncAll();
    });
    if (ConnectivityService.instance.isOnline && state.pending.isNotEmpty) {
      await syncAll();
    }
  }

  void _loadFromStorage() {
    final raw = ref.read(storageServiceProvider).loadPending();
    state = state.copyWith(pending: raw.map(PendingOrder.fromJson).toList());
  }

  Future<void> _persist() async {
    await ref.read(storageServiceProvider)
        .savePending(state.pending.map((p) => p.toJson()).toList());
  }

  Future<void> enqueue(PendingOrder order) async {
    state = state.copyWith(pending: [...state.pending, order]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> syncAll() async {
    if (state.isSyncing || state.pending.isEmpty) return;
    state = state.copyWith(isSyncing: true, clearError: true);

    final api       = ref.read(orderApiProvider);
    final toProcess = List<PendingOrder>.of(state.pending);
    final synced    = <String>{};
    String? lastErr;

    for (final p in toProcess) {
      if (p.retryCount >= _kMaxRetries) continue;
      try {
        final order = await api.create(
          branchId:       p.branchId,
          shiftId:        p.shiftId,
          paymentMethod:  p.paymentMethod,
          items:          p.items,
          customerName:   p.customerName,
          discountType:   p.discountType,
          discountValue:  p.discountValue,
          idempotencyKey: p.localId,
        );
        synced.add(p.localId);
        onOrderSynced?.call(order);
      } catch (e) {
        final idx = state.pending.indexWhere((x) => x.localId == p.localId);
        if (idx >= 0) {
          final updated = List<PendingOrder>.of(state.pending);
          updated[idx] = updated[idx].withIncrementedRetry();
          state = state.copyWith(pending: updated);
        }
        lastErr = e.toString();
      }
    }

    state = state.copyWith(
      pending:   state.pending.where((p) => !synced.contains(p.localId)).toList(),
      isSyncing: false,
      lastError: lastErr,
    );
    await _persist();
  }

  Future<void> discard(String localId) async {
    state = state.copyWith(
        pending: state.pending.where((p) => p.localId != localId).toList());
    await _persist();
  }

  Future<void> resetRetry(String localId) async {
    state = state.copyWith(
      pending: state.pending
          .map((p) => p.localId == localId ? p.withResetRetry() : p)
          .toList(),
    );
    await _persist();
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, OfflineQueueState>(
        OfflineQueueNotifier.new);
