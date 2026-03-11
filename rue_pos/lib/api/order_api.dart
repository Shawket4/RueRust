import 'client.dart';
import '../models/order.dart';

class OrderApi {
  Future<Order> createOrder({
    required String branchId,
    required String shiftId,
    required String paymentMethod,
    required List<CartItem> items,
    String? customerName,
    String? notes,
    String? discountType,
    int? discountValue,
  }) async {
    final res = await dio.post('/orders', data: {
      'branch_id': branchId,
      'shift_id': shiftId,
      'payment_method': paymentMethod,
      'customer_name': customerName,
      'notes': notes,
      'discount_type': discountType,
      'discount_value': discountValue,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Order.fromJson(res.data);
  }

  Future<List<Order>> getOrders({String? branchId, String? shiftId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (shiftId != null) params['shift_id'] = shiftId;
    final res = await dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<void> voidOrder(String orderId, String reason) async {
    await dio.post('/orders/$orderId/void', data: {'reason': reason});
  }
}

final orderApi = OrderApi();
