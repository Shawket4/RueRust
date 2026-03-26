import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/order.dart';
import 'client.dart';

class OrderApi {
  final DioClient _c;
  OrderApi(this._c);

  Future<Order> create({
    required String         branchId,
    required String         shiftId,
    required String         paymentMethod,
    required List<CartItem> items,
    String?                 customerName,
    String?                 discountType,
    int?                    discountValue,
    required String         idempotencyKey,
  }) async {
    final res = await _c.dio.post('/orders',
      data: {
        'branch_id':      branchId,
        'shift_id':       shiftId,
        'payment_method': paymentMethod,
        'customer_name':  customerName,
        'discount_type':  discountType,
        'discount_value': discountValue,
        'items':          items.map((i) => i.toApiJson()).toList(),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId  != null) params['shift_id']  = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await _c.dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> get(String id) async {
    final res = await _c.dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> voidOrder(String id,
      {String? reason, bool restoreInventory = false}) async {
    final res = await _c.dio.post('/orders/$id/void', data: {
      'reason':            reason,
      'restore_inventory': restoreInventory,
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

final orderApiProvider = Provider<OrderApi>(
    (ref) => OrderApi(ref.watch(dioClientProvider)));
