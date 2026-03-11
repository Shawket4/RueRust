import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> getCurrentShift(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data);
  }

  Future<Shift> openShift(String branchId, int openingCash) async {
    final res = await dio.post('/shifts/branches/$branchId/open', data: {
      'opening_cash': openingCash,
    });
    return Shift.fromJson(res.data);
  }

  Future<Shift> closeShift(
    String shiftId, {
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    final res = await dio.post('/shifts/$shiftId/close', data: {
      'closing_cash_declared': closingCash,
      'cash_note': note,
      'inventory_counts': inventoryCounts,
    });
    return Shift.fromJson(res.data);
  }

  Future<void> addCashMovement(String shiftId, int amount, String note) async {
    await dio.post('/shifts/$shiftId/cash-movements', data: {
      'amount': amount,
      'note': note,
    });
  }
}

final shiftApi = ShiftApi();
