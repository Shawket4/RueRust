import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../api/shift_api.dart';
import '../api/client.dart';
import '../models/order.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../storage/storage_service.dart';
import 'connectivity_service.dart';

const _kMaxRetries = 5;

class OfflineQueueState {
  final List<PendingAction> queue;
  final bool isSyncing;

  const OfflineQueueState({
    this.queue = const [],
    this.isSyncing = false,
  });

  int get orderCount => queue.whereType<PendingOrder>().length;
  int get shiftOpenCount => queue.whereType<PendingShiftOpen>().length;
  int get shiftCloseCount => queue.whereType<PendingShiftClose>().length;
  int get voidCount => queue.whereType<PendingVoidOrder>().length;
  int get cashCount => queue.whereType<PendingCashMovement>().length;
  int get totalCount => queue.length;
  int get stuckCount => queue.where((a) => a.retryCount >= _kMaxRetries).length;
  bool get hasStuck => stuckCount > 0;
  bool get isEmpty => queue.isEmpty;

  OfflineQueueState copyWith({
    List<PendingAction>? queue,
    bool? isSyncing,
  }) =>
      OfflineQueueState(
        queue: queue ?? this.queue,
        isSyncing: isSyncing ?? this.isSyncing,
      );
}

class OfflineQueueNotifier extends Notifier<OfflineQueueState> {
  void Function(Order order, String localId)? onOrderSynced;
  void Function(Shift)? onShiftOpenSynced;
  void Function(Shift)? onShiftCloseSynced;
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
    state = state.copyWith(queue: raw.map(PendingAction.fromJson).toList());
  }

  Future<void> _persist() async {
    await ref.read(storageServiceProvider)
        .savePendingActions(state.queue.map((a) => a.toJson()).toList());
  }

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

  Future<void> enqueueCashMovement(PendingCashMovement action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> syncAll() async {
    if (state.isSyncing || state.isEmpty) return;
    state = state.copyWith(isSyncing: true);

    final shiftApi = ref.read(shiftApiProvider);
    final orderApi = ref.read(orderApiProvider);

    final toProcess = List<PendingAction>.of(state.queue);
    final succeeded = <String>{};
    final blockedShifts = <String>{};

    for (final action in toProcess) {
      if (action.retryCount >= _kMaxRetries) continue;

      if (action is! PendingVoidOrder) {
        String? targetShiftId;
        if (action is PendingShiftOpen) targetShiftId = action.shiftId;
        if (action is PendingOrder) targetShiftId = action.shiftId;
        if (action is PendingShiftClose) targetShiftId = action.shiftId;
        if (action is PendingCashMovement) targetShiftId = action.shiftId;
        
        if (targetShiftId != null && blockedShifts.contains(targetShiftId)) continue;
      }

      try {
        switch (action) {
          case PendingShiftOpen():
            final shift = await shiftApi.openWithId(
              branchId: action.branchId, shiftId: action.shiftId,
              openingCash: action.openingCash, openedAt: action.openedAt,
            );
            succeeded.add(action.localId);
            onShiftOpenSynced?.call(shift);

          case PendingOrder():
            final order = await orderApi.create(
              branchId: action.branchId, shiftId: action.shiftId,
              paymentMethod: action.paymentMethod, items: action.items,
              customerName: action.customerName, discountType: action.discountType,
              discountValue: action.discountValue, discountId: action.discountId,
              amountTendered: action.amountTendered, tipAmount: action.tipAmount,
              tipPaymentMethod: action.tipPaymentMethod, paymentSplits: action.paymentSplits,
              idempotencyKey: action.localId, createdAt: action.orderedAt,
            );
            succeeded.add(action.localId);
            onOrderSynced?.call(order, action.localId);

          case PendingShiftClose():
            final shift = await shiftApi.close(
              action.shiftId, closingCash: action.closingCash,
              note: action.cashNote, inventoryCounts: action.inventoryCounts, closedAt: action.closedAt,
            );
            succeeded.add(action.localId);
            onShiftCloseSynced?.call(shift);

          case PendingVoidOrder():
            final order = await orderApi.voidOrder(
              action.orderId, reason: action.reason,
              restoreInventory: action.restoreInventory, voidedAt: action.voidedAt,
            );
            succeeded.add(action.localId);
            onVoidSynced?.call(order);

          case PendingCashMovement():
            await shiftApi.addCashMovement(action.shiftId, action.amount, action.note);
            succeeded.add(action.localId);
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 409) {
          succeeded.add(action.localId);
          continue;
        }

        final errMessage = friendlyError(e);

        final idx = state.queue.indexWhere((a) => a.localId == action.localId);
        if (idx >= 0) {
          final updated = List<PendingAction>.of(state.queue);
          updated[idx] = updated[idx].withIncrementedRetry(errMessage);
          state = state.copyWith(queue: updated);
        }
        
        if (action is PendingShiftOpen) blockedShifts.add(action.shiftId);
        if (action is PendingShiftClose) blockedShifts.add(action.shiftId);
      }
    }

    state = state.copyWith(
      queue: state.queue.where((a) => !succeeded.contains(a.localId)).toList(),
      isSyncing: false,
    );
    await _persist();
  }

  Future<void> discard(String localId) async {
    state = state.copyWith(queue: state.queue.where((a) => a.localId != localId).toList());
    await _persist();
  }

  Future<void> resetRetry(String localId) async {
    state = state.copyWith(
      queue: state.queue.map((a) => a.localId == localId ? a.withResetRetry() : a).toList(),
    );
    await _persist();
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, OfflineQueueState>(OfflineQueueNotifier.new);
