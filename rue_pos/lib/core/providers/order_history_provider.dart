import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../api/order_api.dart' show orderApi, orderToJson;
import '../api/client.dart' show prefs;

class OrderHistoryProvider extends ChangeNotifier {
  List<Order> _orders    = [];
  bool        _loading   = false;
  String?     _error;
  String?     _shiftId;
  bool        _fromCache = false;

  List<Order> get orders    => _orders;
  bool        get loading   => _loading;
  String?     get error     => _error;
  bool        get fromCache => _fromCache;

  Future<void> loadForShift(String shiftId) async {
    if (_shiftId == shiftId && _orders.isNotEmpty) return;
    _loading   = true;
    _fromCache = false;
    _error     = null;
    notifyListeners();
    try {
      _orders    = await orderApi.list(shiftId: shiftId);
      _shiftId   = shiftId;
      _fromCache = false;
      await _save(shiftId, _orders);
    } catch (_) {
      final cached = await _loadCached(shiftId);
      if (cached != null) {
        _orders    = cached;
        _shiftId   = shiftId;
        _fromCache = true;
      } else {
        _error = 'Could not load orders — check connection';
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh(String shiftId) async {
    _shiftId = null;
    await loadForShift(shiftId);
  }

  /// Called when a new order is successfully placed (online or after sync).
  void addOrder(Order o) {
    // Avoid duplicates if synced order is also in pending list
    if (_orders.any((x) => x.id == o.id)) return;
    _orders.insert(0, o);
    notifyListeners();
    if (_shiftId != null) _save(_shiftId!, _orders);
  }

  /// Called by OfflineSyncService after a pending order syncs successfully.
  void onOrderSynced(Order o) => addOrder(o);

  // ── Persistence — uses canonical orderToJson ───────────────────────────────
  static String _key(String shiftId) => 'orders_$shiftId';

  Future<void> _save(String shiftId, List<Order> orders) async {
    try {
      final p = await prefs;
      await p.setString(_key(shiftId),
          jsonEncode(orders.map(orderToJson).toList()));
    } catch (_) {}
  }

  Future<List<Order>?> _loadCached(String shiftId) async {
    try {
      final p   = await prefs;
      final raw = p.getString(_key(shiftId));
      if (raw == null) return null;
      return (jsonDecode(raw) as List)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (_) { return null; }
  }
}
