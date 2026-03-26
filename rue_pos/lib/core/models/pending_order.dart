import 'cart.dart';

class PendingOrder {
  final String         localId;
  final String         branchId;
  final String         shiftId;
  final String         paymentMethod;
  final String?        customerName;
  final String?        discountType;
  final int?           discountValue;
  final List<CartItem> items;
  final DateTime       createdAt;
  final int            retryCount;

  const PendingOrder({
    required this.localId,
    required this.branchId,
    required this.shiftId,
    required this.paymentMethod,
    this.customerName,
    this.discountType,
    this.discountValue,
    required this.items,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingOrder withIncrementedRetry() => PendingOrder(
    localId: localId, branchId: branchId, shiftId: shiftId,
    paymentMethod: paymentMethod, customerName: customerName,
    discountType: discountType, discountValue: discountValue,
    items: items, createdAt: createdAt, retryCount: retryCount + 1,
  );

  PendingOrder withResetRetry() => PendingOrder(
    localId: localId, branchId: branchId, shiftId: shiftId,
    paymentMethod: paymentMethod, customerName: customerName,
    discountType: discountType, discountValue: discountValue,
    items: items, createdAt: createdAt, retryCount: 0,
  );

  Map<String, dynamic> toJson() => {
    'local_id': localId, 'branch_id': branchId, 'shift_id': shiftId,
    'payment_method': paymentMethod, 'customer_name': customerName,
    'discount_type': discountType, 'discount_value': discountValue,
    'retry_count': retryCount, 'created_at': createdAt.toIso8601String(),
    'items': items.map((i) => i.toStorageJson()).toList(),
  };

  factory PendingOrder.fromJson(Map<String, dynamic> j) => PendingOrder(
    localId:       j['local_id']       as String,
    branchId:      (j['branch_id']     as String?) ?? '',
    shiftId:       j['shift_id']       as String,
    paymentMethod: j['payment_method'] as String,
    customerName:  j['customer_name']  as String?,
    discountType:  j['discount_type']  as String?,
    discountValue: j['discount_value'] as int?,
    retryCount:    (j['retry_count']   as int?) ?? 0,
    createdAt:     DateTime.parse(j['created_at'] as String),
    items: (j['items'] as List)
        .map((i) => CartItem.fromStorageJson(i as Map<String, dynamic>))
        .toList(),
  );
}
