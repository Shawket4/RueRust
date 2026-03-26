#!/usr/bin/env bash
# =============================================================================
#  RuePOS — Offline improvements patch
#  Run from your Flutter project root.
#  Usage: bash rue_pos_offline_patch.sh
# =============================================================================
set -euo pipefail
echo "🔧  Applying offline improvements..."

mkdir -p lib/core/{models,services,providers,repositories}
mkdir -p lib/features/{order,home}
mkdir -p lib/shared/widgets

# =============================================================================
# 1. TYPED ACTION QUEUE MODEL
#    Every offline action is one of: ShiftOpen, Order, ShiftClose, Void
#    They are stored in strict sequence and synced in order.
# =============================================================================

cat > lib/core/models/pending_action.dart << 'DART'
import 'dart:convert';
import 'cart.dart';

// ---------------------------------------------------------------------------
// Action types
// ---------------------------------------------------------------------------
enum PendingActionType { shiftOpen, order, shiftClose, voidOrder }

// ---------------------------------------------------------------------------
// Base class
// ---------------------------------------------------------------------------
abstract class PendingAction {
  final String             localId;   // UUID — used as idempotency key
  final PendingActionType  type;
  final DateTime           createdAt;
  final int                retryCount;

  const PendingAction({
    required this.localId,
    required this.type,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingAction withIncrementedRetry();
  PendingAction withResetRetry();
  Map<String, dynamic> toJson();

  factory PendingAction.fromJson(Map<String, dynamic> j) {
    final type = PendingActionType.values.byName(j['type'] as String);
    return switch (type) {
      PendingActionType.shiftOpen  => PendingShiftOpen.fromJson(j),
      PendingActionType.order      => PendingOrder.fromJson(j),
      PendingActionType.shiftClose => PendingShiftClose.fromJson(j),
      PendingActionType.voidOrder  => PendingVoidOrder.fromJson(j),
    };
  }
}

// ---------------------------------------------------------------------------
// Shift open
// ---------------------------------------------------------------------------
class PendingShiftOpen extends PendingAction {
  final String   branchId;
  final String   shiftId;     // client-generated UUID — becomes the real ID
  final int      openingCash;
  final DateTime openedAt;

  const PendingShiftOpen({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    required this.branchId,
    required this.shiftId,
    required this.openingCash,
    required this.openedAt,
  }) : super(type: PendingActionType.shiftOpen);

  @override
  PendingShiftOpen withIncrementedRetry() => PendingShiftOpen(
    localId: localId, createdAt: createdAt, branchId: branchId,
    shiftId: shiftId, openingCash: openingCash, openedAt: openedAt,
    retryCount: retryCount + 1,
  );

  @override
  PendingShiftOpen withResetRetry() => PendingShiftOpen(
    localId: localId, createdAt: createdAt, branchId: branchId,
    shiftId: shiftId, openingCash: openingCash, openedAt: openedAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'local_id':    localId,
    'type':        type.name,
    'created_at':  createdAt.toIso8601String(),
    'retry_count': retryCount,
    'branch_id':   branchId,
    'shift_id':    shiftId,
    'opening_cash': openingCash,
    'opened_at':   openedAt.toIso8601String(),
  };

  factory PendingShiftOpen.fromJson(Map<String, dynamic> j) => PendingShiftOpen(
    localId:     j['local_id']    as String,
    createdAt:   DateTime.parse(j['created_at'] as String),
    retryCount:  (j['retry_count'] as int?) ?? 0,
    branchId:    j['branch_id']   as String,
    shiftId:     j['shift_id']    as String,
    openingCash: j['opening_cash'] as int,
    openedAt:    DateTime.parse(j['opened_at'] as String),
  );
}

// ---------------------------------------------------------------------------
// Order
// ---------------------------------------------------------------------------
class PendingOrder extends PendingAction {
  final String         branchId;
  final String         shiftId;
  final String         paymentMethod;
  final String?        customerName;
  final String?        discountType;
  final int?           discountValue;
  final List<CartItem> items;
  final DateTime       orderedAt;

  const PendingOrder({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    required this.branchId,
    required this.shiftId,
    required this.paymentMethod,
    this.customerName,
    this.discountType,
    this.discountValue,
    required this.items,
    required this.orderedAt,
  }) : super(type: PendingActionType.order);

  @override
  PendingOrder withIncrementedRetry() => PendingOrder(
    localId: localId, createdAt: createdAt, branchId: branchId,
    shiftId: shiftId, paymentMethod: paymentMethod, customerName: customerName,
    discountType: discountType, discountValue: discountValue,
    items: items, orderedAt: orderedAt, retryCount: retryCount + 1,
  );

  @override
  PendingOrder withResetRetry() => PendingOrder(
    localId: localId, createdAt: createdAt, branchId: branchId,
    shiftId: shiftId, paymentMethod: paymentMethod, customerName: customerName,
    discountType: discountType, discountValue: discountValue,
    items: items, orderedAt: orderedAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'local_id':       localId,
    'type':           type.name,
    'created_at':     createdAt.toIso8601String(),
    'retry_count':    retryCount,
    'branch_id':      branchId,
    'shift_id':       shiftId,
    'payment_method': paymentMethod,
    'customer_name':  customerName,
    'discount_type':  discountType,
    'discount_value': discountValue,
    'ordered_at':     orderedAt.toIso8601String(),
    'items':          items.map((i) => i.toStorageJson()).toList(),
  };

  factory PendingOrder.fromJson(Map<String, dynamic> j) => PendingOrder(
    localId:       j['local_id']       as String,
    createdAt:     DateTime.parse(j['created_at'] as String),
    retryCount:    (j['retry_count']   as int?) ?? 0,
    branchId:      (j['branch_id']     as String?) ?? '',
    shiftId:       j['shift_id']       as String,
    paymentMethod: j['payment_method'] as String,
    customerName:  j['customer_name']  as String?,
    discountType:  j['discount_type']  as String?,
    discountValue: j['discount_value'] as int?,
    orderedAt:     DateTime.parse((j['ordered_at'] as String?) ?? j['created_at'] as String),
    items: (j['items'] as List)
        .map((i) => CartItem.fromStorageJson(i as Map<String, dynamic>))
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// Shift close
// ---------------------------------------------------------------------------
class PendingShiftClose extends PendingAction {
  final String                         branchId;
  final String                         shiftId;
  final int                            closingCash;
  final String?                        cashNote;
  final List<Map<String, dynamic>>     inventoryCounts;
  final DateTime                       closedAt;

  const PendingShiftClose({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    required this.branchId,
    required this.shiftId,
    required this.closingCash,
    this.cashNote,
    required this.inventoryCounts,
    required this.closedAt,
  }) : super(type: PendingActionType.shiftClose);

  @override
  PendingShiftClose withIncrementedRetry() => PendingShiftClose(
    localId: localId, createdAt: createdAt, branchId: branchId,
    shiftId: shiftId, closingCash: closingCash, cashNote: cashNote,
    inventoryCounts: inventoryCounts, closedAt: closedAt,
    retryCount: retryCount + 1,
  );

  @override
  PendingShiftClose withResetRetry() => PendingShiftClose(
    localId: localId, createdAt: createdAt, branchId: branchId,
    shiftId: shiftId, closingCash: closingCash, cashNote: cashNote,
    inventoryCounts: inventoryCounts, closedAt: closedAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'local_id':         localId,
    'type':             type.name,
    'created_at':       createdAt.toIso8601String(),
    'retry_count':      retryCount,
    'branch_id':        branchId,
    'shift_id':         shiftId,
    'closing_cash':     closingCash,
    'cash_note':        cashNote,
    'inventory_counts': inventoryCounts,
    'closed_at':        closedAt.toIso8601String(),
  };

  factory PendingShiftClose.fromJson(Map<String, dynamic> j) => PendingShiftClose(
    localId:         j['local_id']     as String,
    createdAt:       DateTime.parse(j['created_at'] as String),
    retryCount:      (j['retry_count'] as int?) ?? 0,
    branchId:        j['branch_id']    as String,
    shiftId:         j['shift_id']     as String,
    closingCash:     j['closing_cash'] as int,
    cashNote:        j['cash_note']    as String?,
    inventoryCounts: (j['inventory_counts'] as List)
        .cast<Map<String, dynamic>>(),
    closedAt:        DateTime.parse(j['closed_at'] as String),
  );
}

// ---------------------------------------------------------------------------
// Void order
// ---------------------------------------------------------------------------
class PendingVoidOrder extends PendingAction {
  final String   orderId;
  final String   reason;
  final bool     restoreInventory;
  final DateTime voidedAt;

  const PendingVoidOrder({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    required this.orderId,
    required this.reason,
    required this.restoreInventory,
    required this.voidedAt,
  }) : super(type: PendingActionType.voidOrder);

  @override
  PendingVoidOrder withIncrementedRetry() => PendingVoidOrder(
    localId: localId, createdAt: createdAt, orderId: orderId,
    reason: reason, restoreInventory: restoreInventory, voidedAt: voidedAt,
    retryCount: retryCount + 1,
  );

  @override
  PendingVoidOrder withResetRetry() => PendingVoidOrder(
    localId: localId, createdAt: createdAt, orderId: orderId,
    reason: reason, restoreInventory: restoreInventory, voidedAt: voidedAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'local_id':          localId,
    'type':              type.name,
    'created_at':        createdAt.toIso8601String(),
    'retry_count':       retryCount,
    'order_id':          orderId,
    'reason':            reason,
    'restore_inventory': restoreInventory,
    'voided_at':         voidedAt.toIso8601String(),
  };

  factory PendingVoidOrder.fromJson(Map<String, dynamic> j) => PendingVoidOrder(
    localId:          j['local_id']          as String,
    createdAt:        DateTime.parse(j['created_at'] as String),
    retryCount:       (j['retry_count']       as int?) ?? 0,
    orderId:          j['order_id']           as String,
    reason:           j['reason']             as String,
    restoreInventory: (j['restore_inventory'] as bool?) ?? false,
    voidedAt:         DateTime.parse(j['voided_at'] as String),
  );
}
DART

# =============================================================================
# 2. OFFLINE QUEUE NOTIFIER  — sequential typed sync
# =============================================================================

cat > lib/core/services/offline_queue.dart << 'DART'
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../api/shift_api.dart';
import '../models/order.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../storage/storage_service.dart';
import 'connectivity_service.dart';

const _kMaxRetries = 5;

class OfflineQueueState {
  final List<PendingAction> queue;
  final bool                isSyncing;
  final String?             lastError;

  const OfflineQueueState({
    this.queue     = const [],
    this.isSyncing = false,
    this.lastError,
  });

  // Counts by type
  int get orderCount      => queue.whereType<PendingOrder>().length;
  int get shiftOpenCount  => queue.whereType<PendingShiftOpen>().length;
  int get shiftCloseCount => queue.whereType<PendingShiftClose>().length;
  int get voidCount       => queue.whereType<PendingVoidOrder>().length;
  int get totalCount      => queue.length;
  int get stuckCount      => queue.where((a) => a.retryCount >= _kMaxRetries).length;
  bool get hasStuck       => stuckCount > 0;
  bool get isEmpty        => queue.isEmpty;

  OfflineQueueState copyWith({
    List<PendingAction>? queue,
    bool?                isSyncing,
    String?              lastError,
    bool                 clearError = false,
  }) => OfflineQueueState(
    queue:     queue     ?? this.queue,
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
    await ref.read(storageServiceProvider)
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

    final toProcess  = List<PendingAction>.of(state.queue);
    final succeeded  = <String>{};
    String? lastErr;
    bool    chainBlocked = false; // if a shift open/close fails, block dependent actions

    for (final action in toProcess) {
      if (action.retryCount >= _kMaxRetries) continue;

      // If chain is blocked, only void orders can still proceed
      if (chainBlocked && action is! PendingVoidOrder) continue;

      try {
        switch (action) {
          case PendingShiftOpen():
            final shift = await shiftApi.openWithId(
              branchId:    action.branchId,
              shiftId:     action.shiftId,
              openingCash: action.openingCash,
              openedAt:    action.openedAt,
            );
            succeeded.add(action.localId);
            chainBlocked = false;
            onShiftOpenSynced?.call(shift);

          case PendingOrder():
            final order = await orderApi.create(
              branchId:       action.branchId,
              shiftId:        action.shiftId,
              paymentMethod:  action.paymentMethod,
              items:          action.items,
              customerName:   action.customerName,
              discountType:   action.discountType,
              discountValue:  action.discountValue,
              idempotencyKey: action.localId,
              createdAt:      action.orderedAt,
            );
            succeeded.add(action.localId);
            onOrderSynced?.call(order);

          case PendingShiftClose():
            final shift = await shiftApi.close(
              action.shiftId,
              closingCash:     action.closingCash,
              note:            action.cashNote,
              inventoryCounts: action.inventoryCounts,
              closedAt:        action.closedAt,
            );
            succeeded.add(action.localId);
            chainBlocked = false;
            onShiftCloseSynced?.call(shift);

          case PendingVoidOrder():
            final order = await orderApi.voidOrder(
              action.orderId,
              reason:           action.reason,
              restoreInventory: action.restoreInventory,
              voidedAt:         action.voidedAt,
            );
            succeeded.add(action.localId);
            onVoidSynced?.call(order);
        }
      } catch (e) {
        lastErr = _friendlyError(e);
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
      queue:     state.queue.where((a) => !succeeded.contains(a.localId)).toList(),
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
DART

# =============================================================================
# 3. STORAGE SERVICE  — add pending actions + menu cache timestamp
# =============================================================================

cat > lib/core/storage/storage_service.dart << 'DART'
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  // ── Token ──────────────────────────────────────────────────────────────────
  String? get token              => _prefs.getString('auth_token');
  Future<void> saveToken(String t)   => _prefs.setString('auth_token', t);
  Future<void> removeToken()         => _prefs.remove('auth_token');

  // ── User ───────────────────────────────────────────────────────────────────
  Future<void> saveUser(Map<String, dynamic> j) =>
      _prefs.setString('cached_user', jsonEncode(j));

  Map<String, dynamic>? loadUser() {
    final raw = _prefs.getString('cached_user');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  Future<void> removeUser() => _prefs.remove('cached_user');

  // ── Branch ─────────────────────────────────────────────────────────────────
  Future<void> saveBranch(String id, Map<String, dynamic> j) =>
      _prefs.setString('branch_$id', jsonEncode(j));

  Map<String, dynamic>? loadBranch(String id) {
    final raw = _prefs.getString('branch_$id');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  // ── Shift ──────────────────────────────────────────────────────────────────
  Future<void> saveShift(String branchId, Map<String, dynamic> j) =>
      _prefs.setString('shift_$branchId', jsonEncode(j));

  Map<String, dynamic>? loadShift(String branchId) {
    final raw = _prefs.getString('shift_$branchId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  Future<void> removeShift(String branchId) => _prefs.remove('shift_$branchId');

  // ── Menu (with cache timestamp) ────────────────────────────────────────────
  Future<void> saveMenu(String orgId, Map<String, dynamic> j) async {
    await _prefs.setString('menu_v2_$orgId', jsonEncode(j));
    await _prefs.setString(
        'menu_cached_at_$orgId', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? loadMenu(String orgId) {
    final raw = _prefs.getString('menu_v2_$orgId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  DateTime? menuCachedAt(String orgId) {
    final raw = _prefs.getString('menu_cached_at_$orgId');
    if (raw == null) return null;
    try { return DateTime.parse(raw); } catch (_) { return null; }
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  Future<void> saveOrders(String shiftId, List<Map<String, dynamic>> orders) =>
      _prefs.setString('orders_$shiftId', jsonEncode(orders));
//
  List<Map<String, dynamic>>? loadOrders(String shiftId) {
    final raw = _prefs.getString('orders_$shiftId');
    if (raw == null) return null;
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return null; }
  }

  // ── Pending action queue ───────────────────────────────────────────────────
  static const _pendingKey = 'offline_pending_actions_v2';

  Future<void> savePendingActions(List<Map<String, dynamic>> actions) =>
      _prefs.setString(_pendingKey, jsonEncode(actions));

  List<Map<String, dynamic>> loadPendingActions() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return []; }
  }

  // ── Clear auth ─────────────────────────────────────────────────────────────
  Future<void> clearAuth() async {
    await removeToken();
    await removeUser();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});
DART

# =============================================================================
# 4. SHIFT API  — add openWithId and updated close signature
# =============================================================================

cat > lib/core/api/shift_api.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';
import 'client.dart';

class ShiftApi {
  final DioClient _c;
  ShiftApi(this._c);

  Future<ShiftPreFill> current(String branchId) async {
    final res = await _c.dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Shift>> list(String branchId) async {
    final res = await _c.dio.get('/shifts/branches/$branchId');
    return (res.data as List).map((s) => Shift.fromJson(s)).toList();
  }

  /// Standard online open — server generates the UUID.
  Future<Shift> open(String branchId, int openingCash) async {
    final res = await _c.dio.post(
      '/shifts/branches/$branchId/open',
      data: {'opening_cash': openingCash},
    );
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  /// Offline-aware open — client supplies its own UUID and timestamp.
  /// Idempotent: safe to call multiple times with the same shiftId.
  Future<Shift> openWithId({
    required String   branchId,
    required String   shiftId,
    required int      openingCash,
    required DateTime openedAt,
  }) async {
    final res = await _c.dio.post(
      '/shifts/branches/$branchId/open',
      data: {
        'id':           shiftId,
        'opening_cash': openingCash,
        'opened_at':    openedAt.toIso8601String(),
      },
    );
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  /// Close shift. Accepts optional closedAt for offline scenarios.
  /// Idempotent: returns existing close data if already closed.
  Future<Shift> close(
    String shiftId, {
    required int                       closingCash,
    String?                            note,
    required List<Map<String, dynamic>> inventoryCounts,
    DateTime?                          closedAt,
  }) async {
    final res = await _c.dio.post('/shifts/$shiftId/close', data: {
      'closing_cash_declared': closingCash,
      'cash_note':             note,
      'inventory_counts':      inventoryCounts,
      if (closedAt != null) 'closed_at': closedAt.toIso8601String(),
    });
    final body = res.data as Map<String, dynamic>;
    return Shift.fromJson(body['shift'] as Map<String, dynamic>);
  }

  Future<int> systemCash(String shiftId, int openingCash) async {
    final ordersRes = await _c.dio.get('/orders',
        queryParameters: {'shift_id': shiftId});
    final orders = (ordersRes.data as List).cast<Map<String, dynamic>>();
    final cashFromOrders = orders
        .where((o) => o['payment_method'] == 'cash' &&
            o['status'] != 'voided' && o['status'] != 'refunded')
        .fold<int>(0, (s, o) => s + (o['total_amount'] as int));

    int movements = 0;
    try {
      final movRes = await _c.dio.get('/shifts/$shiftId/cash-movements');
      movements = (movRes.data as List)
          .fold<int>(0, (s, m) => s + (m['amount'] as int));
    } catch (_) {}

    return openingCash + cashFromOrders + movements;
  }
}

final shiftApiProvider = Provider<ShiftApi>(
    (ref) => ShiftApi(ref.watch(dioClientProvider)));
DART

# =============================================================================
# 5. ORDER API  — add createdAt and voidedAt timestamp params
# =============================================================================

cat > lib/core/api/order_api.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/order.dart';
import 'client.dart';

class OrderApi {
  final DioClient _c;
  OrderApi(this._c);

  Future<Order> create({
    required String         branchId,
    required String         shiftId,
    required String         paymentMethod,
    required List<CartItem> items,
    String?                 customerName,
    String?                 discountType,
    int?                    discountValue,
    required String         idempotencyKey,
    DateTime?               createdAt,
  }) async {
    final res = await _c.dio.post(
      '/orders',
      data: {
        'branch_id':      branchId,
        'shift_id':       shiftId,
        'payment_method': paymentMethod,
        'customer_name':  customerName,
        'discount_type':  discountType,
        'discount_value': discountValue,
        'items':          items.map((i) => i.toApiJson()).toList(),
        if (createdAt != null) 'created_at': createdAt.toIso8601String(),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId  != null) params['shift_id']  = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await _c.dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> get(String id) async {
    final res = await _c.dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> voidOrder(
    String id, {
    required String reason,
    bool    restoreInventory = false,
    DateTime? voidedAt,
  }) async {
    final res = await _c.dio.post('/orders/$id/void', data: {
      'reason':            reason,
      'restore_inventory': restoreInventory,
      if (voidedAt != null) 'voided_at': voidedAt.toIso8601String(),
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

final orderApiProvider = Provider<OrderApi>(
    (ref) => OrderApi(ref.watch(dioClientProvider)));
DART

# =============================================================================
# 6. SHIFT NOTIFIER  — offline open/close with local state
# =============================================================================

cat > lib/core/providers/shift_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/inventory.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue.dart';
import '../storage/storage_service.dart';

class ShiftState {
  final bool               isLoading;
  final Shift?             shift;
  final int                suggestedOpeningCash;
  final List<InventoryItem> inventory;
  final int                systemCash;
  final bool               systemCashLoading;
  final String?            error;
  final bool               fromCache;
  /// True if the current shift was opened offline and not yet synced.
  final bool               isLocalShift;

  const ShiftState({
    this.isLoading            = false,
    this.shift,
    this.suggestedOpeningCash = 0,
    this.inventory            = const [],
    this.systemCash           = 0,
    this.systemCashLoading    = false,
    this.error,
    this.fromCache            = false,
    this.isLocalShift         = false,
  });

  bool get hasOpenShift => shift?.isOpen ?? false;

  ShiftState copyWith({
    bool?               isLoading,
    Shift?              shift,
    int?                suggestedOpeningCash,
    List<InventoryItem>? inventory,
    int?                systemCash,
    bool?               systemCashLoading,
    String?             error,
    bool?               fromCache,
    bool?               isLocalShift,
    bool                clearShift = false,
    bool                clearError = false,
  }) => ShiftState(
    isLoading:            isLoading            ?? this.isLoading,
    shift:                clearShift ? null    : (shift ?? this.shift),
    suggestedOpeningCash: suggestedOpeningCash ?? this.suggestedOpeningCash,
    inventory:            inventory            ?? this.inventory,
    systemCash:           systemCash           ?? this.systemCash,
    systemCashLoading:    systemCashLoading    ?? this.systemCashLoading,
    error:                clearError ? null    : (error ?? this.error),
    fromCache:            fromCache            ?? this.fromCache,
    isLocalShift:         isLocalShift         ?? this.isLocalShift,
  );
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() => const ShiftState();

  Future<void> load(String branchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preFill = await ref.read(shiftRepositoryProvider)
          .currentShift(branchId);
      state = state.copyWith(
        isLoading:            false,
        shift:                preFill.openShift,
        suggestedOpeningCash: preFill.suggestedOpeningCash,
        fromCache:            false,
        isLocalShift:         false,
        clearShift:           preFill.openShift == null,
      );
    } catch (_) {
      // Try cache
      final cached = ref.read(storageServiceProvider).loadShift(branchId);
      if (cached != null) {
        state = state.copyWith(
          isLoading: false, fromCache: true,
          shift: Shift.fromJson(cached),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load shift — check connection',
        );
      }
    }
  }

  /// Open shift. Works offline — generates local UUID and queues.
  Future<bool> openShift(String branchId, int openingCash) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final isOnline = ConnectivityService.instance.isOnline;

    if (isOnline) {
      try {
        final shift = await ref.read(shiftRepositoryProvider)
            .openShift(branchId, openingCash);
        state = state.copyWith(
            isLoading: false, shift: shift, isLocalShift: false);
        return true;
      } catch (e) {
        state = state.copyWith(isLoading: false, error: _friendly(e));
        return false;
      }
    }

    // ── OFFLINE ──────────────────────────────────────────────
    final shiftId  = const Uuid().v4();
    final now      = DateTime.now();
    final localShift = Shift(
      id:           shiftId,
      branchId:     branchId,
      tellerId:     '',        // filled on sync
      tellerName:   '',
      status:       'open',
      openingCash:  openingCash,
      openedAt:     now,
    );

    // Persist locally so the app continues to work
    await ref.read(storageServiceProvider)
        .saveShift(branchId, localShift.toJson());

    // Enqueue for sync
    await ref.read(offlineQueueProvider.notifier).enqueueShiftOpen(
      PendingShiftOpen(
        localId:     const Uuid().v4(),
        createdAt:   now,
        branchId:    branchId,
        shiftId:     shiftId,
        openingCash: openingCash,
        openedAt:    now,
      ),
    );

    state = state.copyWith(
        isLoading: false, shift: localShift, isLocalShift: true);
    return true;
  }

  /// Close shift. Works offline — queues the close payload.
  Future<bool> closeShift({
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (state.shift == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    final isOnline = ConnectivityService.instance.isOnline;
    final shiftId  = state.shift!.id;
    final now      = DateTime.now();

    if (isOnline) {
      try {
        await ref.read(shiftRepositoryProvider).closeShift(
          shiftId,
          branchId:        branchId,
          closingCash:     closingCash,
          note:            note,
          inventoryCounts: inventoryCounts,
        );
        await ref.read(storageServiceProvider).removeShift(branchId);
        state = state.copyWith(
            isLoading: false, clearShift: true, systemCash: 0);
        return true;
      } catch (e) {
        state = state.copyWith(isLoading: false, error: _friendly(e));
        return false;
      }
    }

    // ── OFFLINE ──────────────────────────────────────────────
    await ref.read(offlineQueueProvider.notifier).enqueueShiftClose(
      PendingShiftClose(
        localId:         const Uuid().v4(),
        createdAt:       now,
        branchId:        branchId,
        shiftId:         shiftId,
        closingCash:     closingCash,
        cashNote:        note,
        inventoryCounts: inventoryCounts,
        closedAt:        now,
      ),
    );

    // Mark shift as closed locally
    await ref.read(storageServiceProvider).removeShift(branchId);
    state = state.copyWith(
        isLoading: false, clearShift: true, systemCash: 0);
    return true;
  }

  Future<void> loadSystemCash() async {
    final shift = state.shift;
    if (shift == null) return;
    state = state.copyWith(systemCashLoading: true);
    try {
      final cash = await ref.read(shiftRepositoryProvider)
          .getSystemCash(shift.id, shift.openingCash);
      state = state.copyWith(systemCash: cash, systemCashLoading: false);
    } catch (_) {
      state = state.copyWith(systemCashLoading: false);
    }
  }

  Future<void> loadInventory(String branchId) async {
    final items = await ref.read(shiftRepositoryProvider)
        .getInventory(branchId);
    state = state.copyWith(inventory: items);
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('409')) return 'A shift is already open for this branch';
    if (s.contains('404')) return 'Shift not found';
    if (s.contains('401')) return 'Session expired — please sign in again';
    return 'Something went wrong — please try again';
  }
}

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
DART

# =============================================================================
# 7. MENU NOTIFIER  — expose cachedAt timestamp
# =============================================================================

cat > lib/core/providers/menu_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu.dart';
import '../repositories/menu_repository.dart';
import '../storage/storage_service.dart';

class MenuState {
  final List<Category> categories;
  final List<MenuItem> items;
  final String?        selectedCategoryId;
  final bool           isLoading;
  final bool           fromCache;
  final String?        error;
  final String?        loadedOrgId;
  final DateTime?      cachedAt;

  const MenuState({
    this.categories        = const [],
    this.items             = const [],
    this.selectedCategoryId,
    this.isLoading         = false,
    this.fromCache         = false,
    this.error,
    this.loadedOrgId,
    this.cachedAt,
  });

  List<MenuItem> get filtered => selectedCategoryId == null
      ? items
      : items.where((i) => i.categoryId == selectedCategoryId).toList();

  MenuState copyWith({
    List<Category>? categories,
    List<MenuItem>? items,
    String?         selectedCategoryId,
    bool?           isLoading,
    bool?           fromCache,
    String?         error,
    String?         loadedOrgId,
    DateTime?       cachedAt,
    bool            clearError = false,
  }) => MenuState(
    categories:         categories         ?? this.categories,
    items:              items              ?? this.items,
    selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    isLoading:          isLoading          ?? this.isLoading,
    fromCache:          fromCache          ?? this.fromCache,
    error:              clearError ? null  : (error ?? this.error),
    loadedOrgId:        loadedOrgId        ?? this.loadedOrgId,
    cachedAt:           cachedAt           ?? this.cachedAt,
  );
}

class MenuNotifier extends Notifier<MenuState> {
  @override
  MenuState build() => const MenuState();

  Future<void> load(String orgId, {bool force = false}) async {
    if (!force &&
        state.loadedOrgId == orgId &&
        state.items.isNotEmpty &&
        !state.fromCache) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(menuRepositoryProvider).fetchMenu(orgId);
      final cachedAt = ref.read(storageServiceProvider).menuCachedAt(orgId);
      state = state.copyWith(
        isLoading:          false,
        categories:         result.categories,
        items:              result.items,
        fromCache:          result.fromCache,
        loadedOrgId:        orgId,
        cachedAt:           cachedAt,
        selectedCategoryId: result.categories.isNotEmpty
            ? result.categories.first.id : null,
      );
    } catch (_) {
      state = state.copyWith(
          isLoading: false,
          error: 'No connection and no cached menu available');
    }
  }

  void selectCategory(String id) =>
      state = state.copyWith(selectedCategoryId: id);
}

final menuProvider =
    NotifierProvider<MenuNotifier, MenuState>(MenuNotifier.new);
DART

# =============================================================================
# 8. VOID ORDER SHEET  — offline void support
# =============================================================================

cat > lib/features/order/void_order_sheet.dart << 'DART'
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
DART

# =============================================================================
# 9. PENDING ORDERS SCREEN
# =============================================================================

cat > lib/features/order/pending_orders_screen.dart << 'DART'
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
DART

# =============================================================================
# 10. ROUTER — add /pending-orders route
# =============================================================================

cat > lib/core/router/router.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/order/order_history_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/order/pending_orders_screen.dart';
import '../../features/shift/close_shift_screen.dart';
import '../../features/shift/open_shift_screen.dart';
import '../../features/shift/shift_history_screen.dart';
import '../providers/auth_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth    = ref.read(authProvider);
      final authed  = auth.isAuthenticated;
      final onLogin = state.matchedLocation == '/login';
      if (!authed && !onLogin) return '/login';
      if (authed  &&  onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home',            builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/open-shift',      builder: (_, __) => const OpenShiftScreen()),
      GoRoute(path: '/close-shift',     builder: (_, __) => const CloseShiftScreen()),
      GoRoute(path: '/shift-history',   builder: (_, __) => const ShiftHistoryScreen()),
      GoRoute(path: '/order',           builder: (_, __) => const OrderScreen()),
      GoRoute(path: '/order-history',   builder: (_, __) => const OrderHistoryScreen()),
      GoRoute(path: '/pending-orders',  builder: (_, __) => const PendingOrdersScreen()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
DART

# =============================================================================
# 11. MAIN  — wire new queue callbacks
# =============================================================================

cat > lib/main.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/auth_notifier.dart';
import 'core/providers/order_history_notifier.dart';
import 'core/providers/shift_notifier.dart';
import 'core/router/router.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_queue.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  await ConnectivityService.instance.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(StorageService(prefs)),
    ],
    child: const _App(),
  ));
}

class _App extends ConsumerStatefulWidget {
  const _App();
  @override
  ConsumerState<_App> createState() => _AppState();
}

class _AppState extends ConsumerState<_App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queue        = ref.read(offlineQueueProvider.notifier);
      final history      = ref.read(orderHistoryProvider.notifier);
      final shiftNotif   = ref.read(shiftProvider.notifier);

      // Wire up sync callbacks
      queue.onOrderSynced      = history.addOrder;
      queue.onVoidSynced       = history.updateOrder;
      queue.onShiftOpenSynced  = (shift) {
        // If the shift that just synced matches our local shift, update state
        final current = ref.read(shiftProvider).shift;
        if (current != null && current.id == shift.id) {
          // Replace local shift with real synced shift
          shiftNotif.state = shiftNotif.state.copyWith(
            shift:        shift,
            isLocalShift: false,
          );
        }
      };
      queue.onShiftCloseSynced = (_) {
        // Shift close synced — nothing extra needed, shift already cleared locally
      };

      queue.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final router = ref.watch(routerProvider);

    if (auth.isLoading) return const _SplashScreen();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Rue POS',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/TheRue.png', height: 64),
        const SizedBox(height: 32),
        const SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary)),
      ])),
    ),
  );
}
DART

echo ""
echo "✅  Offline improvements patch complete."
echo ""
echo "📋  Also apply these backend files:"
echo "    src/shifts/handlers.rs  → shifts_handlers.rs"
echo "    src/orders/handlers.rs  → orders_handlers.rs"
echo ""
echo "📋  Run the migration:"
echo "    psql \$DATABASE_URL < migration_offline.sql"
echo ""
echo "📋  Add /pending-orders button to home screen:"
echo "    In home_screen.dart add a _CardBtn with"
echo "    icon: Icons.pending_actions_rounded"
echo "    onTap: () => context.go('/pending-orders')"
echo "    alongside the other action buttons."
echo ""
echo "📋  Show menu cached_at in order_screen.dart sync button:"
echo "    ref.watch(menuProvider).cachedAt → format with timeShort()"