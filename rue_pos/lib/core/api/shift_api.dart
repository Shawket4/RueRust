import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> current(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Shift>> list(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId');
    return (res.data as List).map((s) => Shift.fromJson(s)).toList();
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await dio.post(
      '/shifts/branches/$branchId/open',
      data: {'opening_cash': openingCash},
    );
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
      'cash_note':             note,
      'inventory_counts':      inventoryCounts,
    });
    final body = res.data as Map<String, dynamic>;
    return Shift.fromJson(body['shift'] as Map<String, dynamic>);
  }

  Future<int> getSystemCash(String shiftId, int openingCash) async {
    final ordersRes =
        await dio.get('/orders', queryParameters: {'shift_id': shiftId});
    final orders = ordersRes.data as List;
    final cashFromOrders = orders
        .where((o) =>
            o['payment_method'] == 'cash' &&
            o['status'] != 'voided' &&
            o['status'] != 'refunded')
        .fold<int>(0, (sum, o) => sum + (o['total_amount'] as int));

    final movRes = await dio.get('/shifts/$shiftId/cash-movements');
    final movements = movRes.data as List;
    final cashMovements =
        movements.fold<int>(0, (sum, m) => sum + (m['amount'] as int));

    return openingCash + cashFromOrders + cashMovements;
  }
}

final shiftApi = ShiftApi();

