import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> current(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await dio.post('/shifts/branches/$branchId/open',
        data: {'opening_cash': openingCash});
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> close(
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
    // Backend returns { shift: {...}, inventory_counts: [...] }
    final body = res.data as Map<String, dynamic>;
    return Shift.fromJson(body['shift'] as Map<String, dynamic>);
  }

  /// Calculates expected system cash:
  /// opening_cash + sum(cash orders) + sum(cash movements)
  /// Mirrors the backend logic in close_shift handler.
  Future<int> getSystemCash(String shiftId, int openingCash) async {
    // Fetch all orders for this shift
    final ordersRes =
        await dio.get('/orders', queryParameters: {'shift_id': shiftId});
    final orders = ordersRes.data as List;

    final cashFromOrders = orders
        .where((o) =>
            o['payment_method'] == 'cash' &&
            o['status'] != 'voided' &&
            o['status'] != 'refunded')
        .fold<int>(0, (sum, o) => sum + (o['total_amount'] as int));

    // Fetch cash movements
    final movRes = await dio.get('/shifts/$shiftId/cash-movements');
    final movements = movRes.data as List;

    final cashMovements =
        movements.fold<int>(0, (sum, m) => sum + (m['amount'] as int));

    return openingCash + cashFromOrders + cashMovements;
  }
}

final shiftApi = ShiftApi();
