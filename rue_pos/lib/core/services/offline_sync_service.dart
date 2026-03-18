import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/order_api.dart';
import '../models/pending_order.dart';

const _kPendingKey = 'offline_pending_orders';

/// Manages offline order queue.
/// - Saves orders when offline
/// - Auto-syncs when connectivity restored
/// - Notifies listeners of pending count and sync state
class OfflineSyncService extends ChangeNotifier {
  List<PendingOrder> _pending  = [];
  bool               _syncing  = false;
  bool               _isOnline = true;
  String?            _lastError;
  StreamSubscription? _sub;

  List<PendingOrder> get pending   => List.unmodifiable(_pending);
  bool               get syncing   => _syncing;
  bool               get isOnline  => _isOnline;
  int                get count     => _pending.length;
  String?            get lastError => _lastError;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadFromPrefs();
    // Check initial connectivity
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;

    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;
      if (online && !_isOnline && _pending.isNotEmpty) {
        // Just came online and we have pending orders — sync
        syncAll();
      }
      _isOnline = online;
      notifyListeners();
    });

    // Try to sync any leftover pending on startup
    if (_isOnline && _pending.isNotEmpty) {
      syncAll();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Save a pending order ──────────────────────────────────────────────────
  Future<void> savePending(PendingOrder order) async {
    _pending.add(order);
    await _saveToPrefs();
    notifyListeners();
  }

  // ── Sync all pending orders ───────────────────────────────────────────────
  Future<void> syncAll() async {
    if (_syncing || _pending.isEmpty) return;
    _syncing    = true;
    _lastError  = null;
    notifyListeners();

    final toRemove = <String>[];

    for (final pending in List.of(_pending)) {
      try {
        await orderApi.create(
          shiftId:       pending.shiftId,
          paymentMethod: pending.paymentMethod,
          customerName:  pending.customerName,
          notes:         pending.notes,
          discountType:  pending.discountType,
          discountValue: pending.discountValue,
          items:         pending.items,
        );
        toRemove.add(pending.localId);
      } catch (e) {
        // Stop on first failure — will retry next time online
        _lastError = 'Sync failed: $e';
        break;
      }
    }

    _pending.removeWhere((p) => toRemove.contains(p.localId));
    await _saveToPrefs();
    _syncing = false;
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kPendingKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _pending = list.map((e) => PendingOrder.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _pending = [];
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingKey, jsonEncode(_pending.map((p) => p.toJson()).toList()));
  }
}

final offlineSyncService = OfflineSyncService();

