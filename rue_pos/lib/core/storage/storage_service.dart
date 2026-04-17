import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  String? get token => _prefs.getString('auth_token');
  Future<void> saveToken(String t) => _prefs.setString('auth_token', t);
  Future<void> removeToken() => _prefs.remove('auth_token');

  Future<void> saveUser(Map<String, dynamic> j) => _prefs.setString('cached_user', jsonEncode(j));
  Map<String, dynamic>? loadUser() {
    final raw = _prefs.getString('cached_user');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('cached_user'); return null; 
    }
  }
  Future<void> removeUser() => _prefs.remove('cached_user');

  Future<void> saveBranch(String id, Map<String, dynamic> j) => _prefs.setString('branch_$id', jsonEncode(j));
  Map<String, dynamic>? loadBranch(String id) {
    final raw = _prefs.getString('branch_$id');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('branch_$id'); return null; 
    }
  }

  Future<void> saveShift(String branchId, Map<String, dynamic> j) => _prefs.setString('shift_$branchId', jsonEncode(j));
  Map<String, dynamic>? loadShift(String branchId) {
    final raw = _prefs.getString('shift_$branchId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('shift_$branchId'); return null; 
    }
  }
  Future<void> removeShift(String branchId) => _prefs.remove('shift_$branchId');

  Future<void> saveMenu(String orgId, Map<String, dynamic> j) async {
    await _prefs.setString('menu_v2_$orgId', jsonEncode(j));
    await _prefs.setString('menu_cached_at_$orgId', DateTime.now().toIso8601String());
  }
  Map<String, dynamic>? loadMenu(String orgId) {
    final raw = _prefs.getString('menu_v2_$orgId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('menu_v2_$orgId'); return null; 
    }
  }
  DateTime? menuCachedAt(String orgId) {
    final raw = _prefs.getString('menu_cached_at_$orgId');
    if (raw == null) return null;
    try { return DateTime.parse(raw); } catch (_) { return null; }
  }

  Future<void> saveDiscounts(String orgId, List<Map<String, dynamic>> discounts) =>
      _prefs.setString('discounts_$orgId', jsonEncode(discounts));

  List<Map<String, dynamic>> loadDiscounts(String orgId) {
    final raw = _prefs.getString('discounts_$orgId');
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { 
      _prefs.remove('discounts_$orgId'); return []; 
    }
  }

  Future<void> saveOrders(String shiftId, List<Map<String, dynamic>> orders) =>
      _prefs.setString('orders_$shiftId', jsonEncode(orders));

  List<Map<String, dynamic>>? loadOrders(String shiftId) {
    final raw = _prefs.getString('orders_$shiftId');
    if (raw == null) return null;
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { 
      _prefs.remove('orders_$shiftId'); return null; 
    }
  }

  static const _pendingKey = 'offline_pending_actions_v2';

  Future<void> savePendingActions(List<Map<String, dynamic>> actions) =>
      _prefs.setString(_pendingKey, jsonEncode(actions));

  List<Map<String, dynamic>> loadPendingActions() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { 
      _prefs.remove(_pendingKey); return []; 
    }
  }

  Future<void> clearAuth() async {
    await removeToken();
    await removeUser();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});
