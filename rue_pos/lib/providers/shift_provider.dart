import 'package:flutter/foundation.dart';
import '../models/shift.dart';
import '../api/shift_api.dart';

class ShiftProvider extends ChangeNotifier {
  Shift? _currentShift;
  ShiftPreFill? _preFill;
  bool _loading = false;
  String? _error;

  Shift? get currentShift => _currentShift;
  ShiftPreFill? get preFill => _preFill;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasOpenShift => _currentShift?.status == 'open';

  Future<void> loadCurrentShift(String branchId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _preFill = await shiftApi.getCurrentShift(branchId);
      _currentShift = _preFill?.openShift;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> openShift(String branchId, int openingCash) async {
    _loading = true;
    notifyListeners();
    try {
      _currentShift = await shiftApi.openShift(branchId, openingCash);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> closeShift(
    String shiftId, {
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      _currentShift = await shiftApi.closeShift(
        shiftId,
        closingCash: closingCash,
        note: note,
        inventoryCounts: inventoryCounts,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _currentShift = null;
    _preFill = null;
    notifyListeners();
  }
}
