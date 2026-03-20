import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../api/client.dart' show prefs, friendlyError;
import '../api/order_api.dart';
import '../models/order.dart';
import '../models/pending_order.dart';

const _kPendingKey  = 'offline_pending_orders';
const _kMaxRetries  = 5;

/// Called after each order is successfully synced so the history list updates.
typedef OnOrderSynced = void Function(Order order);

class OfflineSyncService extends ChangeNotifier {
  List<PendingOrder> _pending   = [];
  bool               _syncing   = false;
  bool               _isOnline  = true;
  String?            _lastError;

  /// Wired up by main.dart after providers are ready.
  OnOrderSynced? onOrderSynced;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  List<PendingOrder> get pending   => List.unmodifiable(_pending);
  bool               get syncing   => _syncing;
  bool               get isOnline  => _isOnline;
  int                get count     => _pending.length;
  String?            get lastError => _lastError;

  Future<void> init() async {
    await _load();
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wentOnline = online && !_isOnline;
      _isOnline = online;
      notifyListeners();
      if (wentOnline && _pending.isNotEmpty) syncAll();
    });

    // Attempt sync on startup if online
    if (_isOnline && _pending.isNotEmpty) {
      // Defer until after runApp so providers are ready
      Future.microtask(syncAll);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> savePending(PendingOrder order) async {
    _pending.add(order);
    await _persist();
    notifyListeners();
    // Opportunistically sync right away if online
    if (_isOnline) syncAll();
  }

  /// Sync all pending orders.
  /// - Skips orders that have hit the retry ceiling (shows them as "stuck").
  /// - Continues past individual failures so one bad order doesn't block others.
  Future<void> syncAll() async {
    if (_syncing || _pending.isEmpty) return;
    _syncing   = true;
    _lastError = null;
    notifyListeners();

    final toProcess = List.of(_pending);
    final succeeded = <String>[];

    for (final p in toProcess) {
      // Skip permanently-broken orders
      if (p.retryCount >= _kMaxRetries) continue;

      try {
        final order = await orderApi.create(
          branchId:      p.branchId,
          shiftId:       p.shiftId,
          paymentMethod: p.paymentMethod,
          items:         p.items,
          customerName:  p.customerName,
          discountType:  p.discountType,
          discountValue: p.discountValue,
          idempotencyKey: p.localId,      // prevents duplicate creation
        );
        succeeded.add(p.localId);
        onOrderSynced?.call(order);
      } catch (e) {
        // Increment retry counter for this order and continue to next
        final idx = _pending.indexWhere((x) => x.localId == p.localId);
        if (idx != -1) {
          _pending[idx] = _pending[idx].copyWith(
            retryCount: _pending[idx].retryCount + 1,
          );
        }
        _lastError = friendlyError(e);
        // Don't break — keep trying subsequent orders
      }
    }

    _pending.removeWhere((p) => succeeded.contains(p.localId));
    await _persist();
    _syncing = false;
    notifyListeners();
  }

  /// How many orders are permanently stuck (>= max retries).
  int get stuckCount =>
      _pending.where((p) => p.retryCount >= _kMaxRetries).length;

  /// Discard a stuck order by localId.
  Future<void> discard(String localId) async {
    _pending.removeWhere((p) => p.localId == localId);
    await _persist();
    notifyListeners();
  }

  /// Reset retry counter so a stuck order can be re-attempted.
  Future<void> resetRetry(String localId) async {
    final idx = _pending.indexWhere((p) => p.localId == localId);
    if (idx != -1) {
      _pending[idx] = _pending[idx].copyWith(retryCount: 0);
      await _persist();
      notifyListeners();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final p   = await prefs;
      final raw = p.getString(_kPendingKey);
      if (raw != null) {
        _pending = (jsonDecode(raw) as List)
            .map((e) => PendingOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) { _pending = []; }
  }

  Future<void> _persist() async {
    try {
      final p = await prefs;
      await p.setString(_kPendingKey,
          jsonEncode(_pending.map((x) => x.toJson()).toList()));
    } catch (_) {}
  }
}

final offlineSyncService = OfflineSyncService();
