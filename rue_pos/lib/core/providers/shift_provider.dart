import 'package:flutter/foundation.dart';
import '../models/shift.dart';
import '../api/shift_api.dart';

class ShiftProvider extends ChangeNotifier {
  Shift?        _shift;
  ShiftPreFill? _preFill;
  bool          _loading = false;
  String?       _error;

  Shift?        get shift   => _shift;
  ShiftPreFill? get preFill => _preFill;
  bool          get loading => _loading;
  String?       get error   => _error;
  bool          get hasOpen => _shift?.isOpen ?? false;

  Future<void> load(String branchId) async {
    _set(true);
    try {
      _preFill = await shiftApi.current(branchId);
      _shift   = _preFill?.openShift;
      _error   = null;
    } catch (e) {
      _error = _friendly(e);
    }
    _set(false);
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    _set(true);
    try {
      _shift = await shiftApi.open(branchId, openingCash);
      _error = null;
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
      _shift = await shiftApi.close(
        _shift!.id,
        closingCash:     closingCash,
        note:            note,
        inventoryCounts: inventoryCounts,
      );
      _error = null;
      _set(false);
      return true;
    } catch (e) {
      _error = _friendly(e);
      _set(false);
      return false;
    }
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
