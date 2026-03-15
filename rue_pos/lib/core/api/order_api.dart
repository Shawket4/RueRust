import 'client.dart';
import '../models/order.dart';

class OrderApi {
  Future<Order> create({
    required String branchId,
    required String shiftId,
    required String paymentMethod,
    required List<CartItem> items,
    String? customerName,
    String? discountType,
    int? discountValue,
  }) async {
    final res = await dio.post('/orders', data: {
      'branch_id': branchId,
      'shift_id': shiftId,
      'payment_method': paymentMethod,
      'customer_name': customerName,
      'discount_type': discountType,
      'discount_value': discountValue,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId != null) params['shift_id'] = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await dio.get('/orders', queryParameters: params);
    print('RAW ORDERS RESPONSE: ${res.data}');
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> get(String id) async {
    final res = await dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> voidOrder(String id, String reason) async {
    await dio.post('/orders/$id/void', data: {'reason': reason});
  }
}

final orderApi = OrderApi();
