import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';
import 'client.dart';

class ShiftApi {
  final DioClient _c;
  ShiftApi(this._c);

  Future<ShiftPreFill> current(String branchId) async {
    final res = await _c.dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Shift>> list(String branchId) async {
    final res = await _c.dio.get('/shifts/branches/$branchId');
    return (res.data as List).map((s) => Shift.fromJson(s)).toList();
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await _c.dio.post('/shifts/branches/$branchId/open',
        data: {'opening_cash': openingCash});
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> close(String shiftId, {
    required int closingCash, String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    final res = await _c.dio.post('/shifts/$shiftId/close', data: {
      'closing_cash_declared': closingCash,
      'cash_note':             note,
      'inventory_counts':      inventoryCounts,
    });
    return Shift.fromJson((res.data as Map<String, dynamic>)['shift'] as Map<String, dynamic>);
  }

  Future<int> systemCash(String shiftId, int openingCash) async {
    final ordersRes = await _c.dio.get('/orders', queryParameters: {'shift_id': shiftId});
    final orders    = (ordersRes.data as List).cast<Map<String, dynamic>>();
    final cashFromOrders = orders
        .where((o) => o['payment_method'] == 'cash' &&
            o['status'] != 'voided' && o['status'] != 'refunded')
        .fold<int>(0, (s, o) => s + (o['total_amount'] as int));

    int movements = 0;
    try {
      final movRes = await _c.dio.get('/shifts/$shiftId/cash-movements');
      movements = (movRes.data as List).fold<int>(0, (s, m) => s + (m['amount'] as int));
    } catch (_) {}

    return openingCash + cashFromOrders + movements;
  }
}

final shiftApiProvider = Provider<ShiftApi>(
    (ref) => ShiftApi(ref.watch(dioClientProvider)));
