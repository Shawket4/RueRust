import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../models/cart.dart';
import '../api/shift_api.dart';
import '../models/order.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../storage/storage_service.dart';
import 'connectivity_service.dart';

const _kMaxRetries = 5;

class OfflineQueueState {
  final List<PendingAction> queue;
  final bool isSyncing;
  final String? lastError;

  const OfflineQueueState({
    this.queue = const [],
    this.isSyncing = false,
    this.lastError,
  });

  // Counts by type
  int get orderCount => queue.whereType<PendingOrder>().length;
  int get shiftOpenCount => queue.whereType<PendingShiftOpen>().length;
  int get shiftCloseCount => queue.whereType<PendingShiftClose>().length;
  int get voidCount => queue.whereType<PendingVoidOrder>().length;
  int get totalCount => queue.length;
  int get stuckCount => queue.where((a) => a.retryCount >= _kMaxRetries).length;
  bool get hasStuck => stuckCount > 0;
  bool get isEmpty => queue.isEmpty;

  OfflineQueueState copyWith({
    List<PendingAction>? queue,
    bool? isSyncing,
    String? lastError,
    bool clearError = false,
  }) =>
      OfflineQueueState(
        queue: queue ?? this.queue,
        isSyncing: isSyncing ?? this.isSyncing,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

class OfflineQueueNotifier extends Notifier<OfflineQueueState> {
  /// Called when an order is successfully synced.
  void Function(Order)? onOrderSynced;

  /// Called when a shift open is successfully synced.
  void Function(Shift)? onShiftOpenSynced;

  /// Called when a shift close is successfully synced.
  void Function(Shift)? onShiftCloseSynced;

  /// Called when a void is successfully synced.
  void Function(Order)? onVoidSynced;

  StreamSubscription<bool>? _connectivitySub;

  @override
  OfflineQueueState build() {
    ref.onDispose(() => _connectivitySub?.cancel());
    return const OfflineQueueState();
  }

  Future<void> init() async {
    _loadFromStorage();
    _connectivitySub = ConnectivityService.instance.stream.listen((online) {
      if (online && !state.isEmpty) syncAll();
    });
    if (ConnectivityService.instance.isOnline && !state.isEmpty) {
      await syncAll();
    }
  }

  void _loadFromStorage() {
    final raw = ref.read(storageServiceProvider).loadPendingActions();
    state = state.copyWith(
      queue: raw.map(PendingAction.fromJson).toList(),
    );
  }

  Future<void> _persist() async {
    await ref
        .read(storageServiceProvider)
        .savePendingActions(state.queue.map((a) => a.toJson()).toList());
  }

  // ── Enqueue actions ────────────────────────────────────────────────────────

  Future<void> enqueueShiftOpen(PendingShiftOpen action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueOrder(PendingOrder action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueShiftClose(PendingShiftClose action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueVoid(PendingVoidOrder action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  // ── Sequential sync ────────────────────────────────────────────────────────
  //
  // Actions are processed STRICTLY in order. If one fails it stops — we
  // cannot process a later action that depends on an earlier one succeeding
  // (e.g. cannot submit orders if the shift open failed).
  //
  // Exception: voidOrder actions are independent and can skip past a stuck
  // shift chain.

  Future<void> syncAll() async {
    if (state.isSyncing || state.isEmpty) return;
    state = state.copyWith(isSyncing: true, clearError: true);

    final shiftApi = ref.read(shiftApiProvider);
    final orderApi = ref.read(orderApiProvider);

    final toProcess = List<PendingAction>.of(state.queue);
    final succeeded = <String>{};
    String? lastErr;
    bool chainBlocked =
        false; // if a shift open/close fails, block dependent actions

    for (final action in toProcess) {
      if (action.retryCount >= _kMaxRetries) continue;

      // If chain is blocked, only void orders can still proceed
      if (chainBlocked && action is! PendingVoidOrder) continue;

      try {
        switch (action) {
          case PendingShiftOpen():
            final shift = await shiftApi.openWithId(
              branchId: action.branchId,
              shiftId: action.shiftId,
              openingCash: action.openingCash,
              openedAt: action.openedAt,
            );
            succeeded.add(action.localId);
            chainBlocked = false;
            onShiftOpenSynced?.call(shift);

          case PendingOrder():
            final body = {
              'branch_id': action.branchId,
              'shift_id': action.shiftId,
              'payment_method': action.paymentMethod,
              'customer_name': action.customerName,
              'discount_type': action.discountType,
              'discount_value': action.discountValue,
              'items': action.items.map((i) => i.toApiJson()).toList(),
              'created_at': action.orderedAt.toIso8601String(),
            };
            debugPrint('FULL BODY: ${jsonEncode(body)}');
            final order = await orderApi.create(
              branchId: action.branchId,
              shiftId: action.shiftId,
              paymentMethod: action.paymentMethod,
              items: action.items,
              customerName: action.customerName,
              discountType: action.discountType,
              discountValue: action.discountValue,
              discountId: action.discountId,
              amountTendered: action.amountTendered,
              tipAmount: action.tipAmount,
              paymentSplits: action.paymentSplits != null
                  ? action.paymentSplits!.map((s) =>
                      PaymentSplit(method: s['method'] as String, amount: s['amount'] as int)).toList()
                  : null,
              idempotencyKey: action.localId,
              createdAt: action.orderedAt,
            );
            succeeded.add(action.localId);
            onOrderSynced?.call(order);

          case PendingShiftClose():
            final shift = await shiftApi.close(
              action.shiftId,
              closingCash: action.closingCash,
              note: action.cashNote,
              inventoryCounts: action.inventoryCounts,
              closedAt: action.closedAt,
            );
            succeeded.add(action.localId);
            chainBlocked = false;
            onShiftCloseSynced?.call(shift);

          case PendingVoidOrder():
            final order = await orderApi.voidOrder(
              action.orderId,
              reason: action.reason,
              restoreInventory: action.restoreInventory,
              voidedAt: action.voidedAt,
            );
            succeeded.add(action.localId);
            onVoidSynced?.call(order);
        }
      } catch (e) {
        lastErr = _friendlyError(e);
        if (e is DioException) {
          print(
              'SYNC ERROR: ${e.response?.statusCode} ${e.response?.data} for action ${action.type}');
        }
        // Increment retry for this action
        final idx = state.queue.indexWhere((a) => a.localId == action.localId);
        if (idx >= 0) {
          final updated = List<PendingAction>.of(state.queue);
          updated[idx] = updated[idx].withIncrementedRetry();
          state = state.copyWith(queue: updated);
        }
        // If it's a shift open or close that failed, block orders/closes
        // that come after it (they depend on it)
        if (action is PendingShiftOpen || action is PendingShiftClose) {
          chainBlocked = true;
        }
        // Don't break — continue for void orders which are independent
      }
    }

    state = state.copyWith(
      queue: state.queue.where((a) => !succeeded.contains(a.localId)).toList(),
      isSyncing: false,
      lastError: lastErr,
    );
    await _persist();
  }

  // ── Management ─────────────────────────────────────────────────────────────

  Future<void> discard(String localId) async {
    state = state.copyWith(
      queue: state.queue.where((a) => a.localId != localId).toList(),
    );
    await _persist();
  }

  Future<void> resetRetry(String localId) async {
    state = state.copyWith(
      queue: state.queue
          .map((a) => a.localId == localId ? a.withResetRetry() : a)
          .toList(),
    );
    await _persist();
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'Session expired';
      if (code == 409) return 'Conflict — resource already exists';
      if (code != null && code >= 500) return 'Server error';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) return 'No connection';
    }
    return e.toString();
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, OfflineQueueState>(
        OfflineQueueNotifier.new);
