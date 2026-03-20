import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift.dart';
import '../api/shift_api.dart';

class ShiftProvider extends ChangeNotifier {
  Shift?        _shift;
  ShiftPreFill? _preFill;
  bool          _loading   = false;
  String?       _error;
  bool          _fromCache = false;

  Shift?        get shift      => _shift;
  ShiftPreFill? get preFill    => _preFill;
  bool          get loading    => _loading;
  String?       get error      => _error;
  bool          get hasOpen    => _shift?.isOpen ?? false;
  bool          get fromCache  => _fromCache;

  Future<void> load(String branchId) async {
    _set(true);
    try {
      _preFill    = await shiftApi.current(branchId);
      _shift      = _preFill?.openShift;
      _error      = null;
      _fromCache  = false;
      if (_shift != null) await _saveShift(_shift!);
    } catch (_) {
      // Try cache
      final cached = await _loadShift(branchId);
      if (cached != null) {
        _shift     = cached;
        _fromCache = true;
        _error     = null;
      } else {
        _error = 'Could not load shift — check connection';
      }
    }
    _set(false);
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    _set(true);
    try {
      _shift     = await shiftApi.open(branchId, openingCash);
      _error     = null;
      _fromCache = false;
      await _saveShift(_shift!);
      _set(false);
      return true;
    } catch (e) {
      _error = _friendly(e);
      _set(false);
      return false;
    }
  }

  Future<bool> closeShift({
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (_shift == null) return false;
    _set(true);
    try {
      _shift     = await shiftApi.close(
        _shift!.id,
        closingCash: closingCash, note: note,
        inventoryCounts: inventoryCounts,
      );
      _error     = null;
      _fromCache = false;
      // Clear cached shift since it's now closed
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shift_${_shift!.branchId}');
      _set(false);
      return true;
    } catch (e) {
      _error = _friendly(e);
      _set(false);
      return false;
    }
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  Future<void> _saveShift(Shift s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shift_${s.branchId}', _shiftToJson(s));
    } catch (_) {}
  }

  Future<Shift?> _loadShift(String branchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('shift_$branchId');
      if (raw == null) return null;
      return _shiftFromJson(raw);
    } catch (_) { return null; }
  }

  String _shiftToJson(Shift s) => jsonEncode({
    'id':                    s.id,
    'branch_id':             s.branchId,
    'teller_id':             s.tellerId,
    'teller_name':           s.tellerName,
    'status':                s.status,
    'opening_cash':          s.openingCash,
    'closing_cash_declared': s.closingCashDeclared,
    'closing_cash_system':   s.closingCashSystem,
    'cash_discrepancy':      s.cashDiscrepancy,
    'opened_at':             s.openedAt.toIso8601String(),
    'closed_at':             s.closedAt?.toIso8601String(),
  });

  Shift _shiftFromJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Shift(
      id:                  j['id'],
      branchId:            j['branch_id'],
      tellerId:            j['teller_id'],
      tellerName:          j['teller_name'],
      status:              j['status'],
      openingCash:         j['opening_cash'],
      closingCashDeclared: j['closing_cash_declared'],
      closingCashSystem:   j['closing_cash_system'],
      cashDiscrepancy:     j['cash_discrepancy'],
      openedAt:            DateTime.parse(j['opened_at']),
      closedAt:            j['closed_at'] != null
          ? DateTime.parse(j['closed_at']) : null,
    );
  }

  void _set(bool v) { _loading = v; notifyListeners(); }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'Session expired — please sign in again';
    if (s.contains('409')) return 'A shift is already open for this branch';
    if (s.contains('404')) return 'Shift not found';
    return 'Something went wrong — please try again';
  }
}

