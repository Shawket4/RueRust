import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  // ── Token ──────────────────────────────────────────────────────────────────
  String? get token          => _prefs.getString('auth_token');
  Future<void> saveToken(String t) => _prefs.setString('auth_token', t);
  Future<void> removeToken()       => _prefs.remove('auth_token');

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

  // ── Menu ───────────────────────────────────────────────────────────────────
  Future<void> saveMenu(String orgId, Map<String, dynamic> j) =>
      _prefs.setString('menu_v2_$orgId', jsonEncode(j));

  Map<String, dynamic>? loadMenu(String orgId) {
    final raw = _prefs.getString('menu_v2_$orgId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  Future<void> saveOrders(String shiftId, List<Map<String, dynamic>> orders) =>
      _prefs.setString('orders_$shiftId', jsonEncode(orders));

  List<Map<String, dynamic>>? loadOrders(String shiftId) {
    final raw = _prefs.getString('orders_$shiftId');
    if (raw == null) return null;
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return null; }
  }

  // ── Pending (offline queue) ────────────────────────────────────────────────
  static const _pendingKey = 'offline_pending_v2';

  Future<void> savePending(List<Map<String, dynamic>> pending) =>
      _prefs.setString(_pendingKey, jsonEncode(pending));

  List<Map<String, dynamic>> loadPending() {
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

// Seeded in main.dart with the real SharedPreferences instance.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});
