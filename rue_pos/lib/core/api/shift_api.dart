import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> current(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  /// List all shifts for a branch. Caches result; serves cache offline.
  Future<List<Shift>> list(String branchId) async {
    try {
      final res    = await dio.get('/shifts/branches/$branchId');
      final shifts = (res.data as List).map((s) => Shift.fromJson(s)).toList();
      final prefs  = await SharedPreferences.getInstance();
      await prefs.setString('shift_list_$branchId',
          jsonEncode(shifts.map(_shiftToJson).toList()));
      return shifts;
    } catch (_) {
      final prefs  = await SharedPreferences.getInstance();
      final raw    = prefs.getString('shift_list_$branchId');
      if (raw != null) {
        return (jsonDecode(raw) as List)
            .map((s) => Shift.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await dio.post('/shifts/branches/$branchId/open',
        data: {'opening_cash': openingCash});
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> close(String shiftId, {
    required int closingCash, String? note,
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

  /// Compute system cash. Tries live API; falls back to cached orders.
  Future<int> getSystemCash(String shiftId, int openingCash) async {
    final ordersData = await _fetchOrCacheOrders(shiftId);
    final cashFromOrders = ordersData
        .where((o) => o['payment_method'] == 'cash' &&
            o['status'] != 'voided' && o['status'] != 'refunded')
        .fold<int>(0, (s, o) => s + (o['total_amount'] as int));

    int cashMovements = 0;
    try {
      final movRes = await dio.get('/shifts/$shiftId/cash-movements');
      final movements = movRes.data as List;
      cashMovements = movements.fold<int>(0, (s, m) => s + (m['amount'] as int));
      // Cache movements
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cash_movements_$shiftId', jsonEncode(movements));
    } catch (_) {
      // Try cached movements
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw   = prefs.getString('cash_movements_$shiftId');
        if (raw != null) {
          final movements = jsonDecode(raw) as List;
          cashMovements = movements.fold<int>(0, (s, m) => s + (m['amount'] as int));
        }
      } catch (_) {}
    }
    return openingCash + cashFromOrders + cashMovements;
  }

  Future<List<Map<String, dynamic>>> _fetchOrCacheOrders(String shiftId) async {
    try {
      final res = await dio.get('/orders', queryParameters: {'shift_id': shiftId});
      final orders = (res.data as List).cast<Map<String, dynamic>>();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('raw_orders_$shiftId', jsonEncode(orders));
      return orders;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('raw_orders_$shiftId');
      if (raw != null) return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return [];
    }
  }

  Map<String, dynamic> _shiftToJson(Shift s) => {
    'id': s.id, 'branch_id': s.branchId, 'teller_id': s.tellerId,
    'teller_name': s.tellerName, 'status': s.status,
    'opening_cash': s.openingCash,
    'closing_cash_declared': s.closingCashDeclared,
    'closing_cash_system':   s.closingCashSystem,
    'cash_discrepancy':      s.cashDiscrepancy,
    'opened_at':  s.openedAt.toIso8601String(),
    'closed_at':  s.closedAt?.toIso8601String(),
  };
}

final shiftApi = ShiftApi();

