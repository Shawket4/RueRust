import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/order.dart';
import 'client.dart';

class OrderApi {
  final DioClient _c;
  OrderApi(this._c);

  Future<Order> create({
    required String branchId,
    required String shiftId,
    required String paymentMethod,
    required List<CartItem> items,
    String? customerName,
    String? discountType,
    int? discountValue,
    String? discountId,
    int? amountTendered,
    int? tipAmount,
    String? tipPaymentMethod,
    List<PaymentSplit>? paymentSplits,
    required String idempotencyKey,
    DateTime? createdAt,
  }) async {
    final res = await _c.dio.post(
      '/orders',
      data: {
        'branch_id': branchId,
        'shift_id': shiftId,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'discount_type': discountType,
        'discount_value': discountValue,
        if (discountId != null) 'discount_id': discountId,
        if (amountTendered != null) 'amount_tendered': amountTendered,
        if (tipAmount != null) 'tip_amount': tipAmount,
        if (tipPaymentMethod != null) 'tip_payment_method': tipPaymentMethod,
        if (paymentSplits != null && paymentSplits.isNotEmpty)
          'payment_splits': paymentSplits.map((s) => s.toApiJson()).toList(),
        'items': items.map((i) => i.toApiJson()).toList(),
        if (createdAt != null)
          'created_at': createdAt.toUtc().toIso8601String(),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId != null) params['shift_id'] = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await _c.dio.get('/orders', queryParameters: params);
    return (res.data['data'] as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> get(String id) async {
    final res = await _c.dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> voidOrder(
    String id, {
    required String reason,
    bool restoreInventory = false,
    DateTime? voidedAt,
  }) async {
    final res = await _c.dio.post('/orders/$id/void', data: {
      'reason': reason,
      'restore_inventory': restoreInventory,
      if (voidedAt != null) 'voided_at': voidedAt.toUtc().toIso8601String(),
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

final orderApiProvider =
    Provider<OrderApi>((ref) => OrderApi(ref.watch(dioClientProvider)));
