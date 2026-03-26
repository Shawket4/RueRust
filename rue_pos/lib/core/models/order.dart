class OrderItemAddon {
  final String id;
  final String addonName;
  final int    unitPrice;
  final int    quantity;
  final int    lineTotal;

  const OrderItemAddon({
    required this.id, required this.addonName,
    required this.unitPrice, required this.quantity, required this.lineTotal,
  });

  factory OrderItemAddon.fromJson(Map<String, dynamic> j) => OrderItemAddon(
    id: j['id'], addonName: j['addon_name'], unitPrice: j['unit_price'],
    quantity: j['quantity'], lineTotal: j['line_total'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'addon_name': addonName, 'unit_price': unitPrice,
    'quantity': quantity, 'line_total': lineTotal,
  };
}

class OrderItem {
  final String             id;
  final String             itemName;
  final String?            sizeLabel;
  final int                unitPrice;
  final int                quantity;
  final int                lineTotal;
  final List<OrderItemAddon> addons;

  const OrderItem({
    required this.id, required this.itemName, this.sizeLabel,
    required this.unitPrice, required this.quantity,
    required this.lineTotal, required this.addons,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'], itemName: j['item_name'], sizeLabel: j['size_label'],
    unitPrice: j['unit_price'], quantity: j['quantity'], lineTotal: j['line_total'],
    addons: (j['addons'] as List? ?? []).map((a) => OrderItemAddon.fromJson(a)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'item_name': itemName, 'size_label': sizeLabel,
    'unit_price': unitPrice, 'quantity': quantity, 'line_total': lineTotal,
    'addons': addons.map((a) => a.toJson()).toList(),
  };
}

class Order {
  final String          id;
  final String          branchId;
  final String          shiftId;
  final String          tellerId;
  final String          tellerName;
  final int             orderNumber;
  final String          status;
  final String          paymentMethod;
  final int             subtotal;
  final String?         discountType;
  final int             discountValue;
  final int             discountAmount;
  final int             taxAmount;
  final int             totalAmount;
  final String?         customerName;
  final String?         notes;
  final String?         voidReason;
  final DateTime        createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id, required this.branchId, required this.shiftId,
    required this.tellerId, required this.tellerName,
    required this.orderNumber, required this.status,
    required this.paymentMethod, required this.subtotal,
    this.discountType, required this.discountValue,
    required this.discountAmount, required this.taxAmount,
    required this.totalAmount, this.customerName, this.notes,
    this.voidReason, required this.createdAt, required this.items,
  });

  bool get isVoided => status == 'voided';

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:             j['id'],
    branchId:       j['branch_id'],
    shiftId:        j['shift_id'],
    tellerId:       (j['teller_id']    as String?) ?? '',
    tellerName:     (j['teller_name']  as String?) ?? '',
    orderNumber:    j['order_number'],
    status:         j['status'],
    paymentMethod:  j['payment_method'],
    subtotal:       (j['subtotal']        as int?) ?? 0,
    discountType:   j['discount_type']    as String?,
    discountValue:  (j['discount_value']  as int?) ?? 0,
    discountAmount: (j['discount_amount'] as int?) ?? 0,
    taxAmount:      (j['tax_amount']      as int?) ?? 0,
    totalAmount:    j['total_amount'],
    customerName:   j['customer_name']    as String?,
    notes:          j['notes']            as String?,
    voidReason:     j['void_reason']      as String?,
    createdAt:      DateTime.parse(j['created_at']),
    items: (j['items'] as List? ?? []).map((i) => OrderItem.fromJson(i)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'branch_id': branchId, 'shift_id': shiftId,
    'teller_id': tellerId, 'teller_name': tellerName,
    'order_number': orderNumber, 'status': status,
    'payment_method': paymentMethod, 'subtotal': subtotal,
    'discount_type': discountType, 'discount_value': discountValue,
    'discount_amount': discountAmount, 'tax_amount': taxAmount,
    'total_amount': totalAmount, 'customer_name': customerName,
    'notes': notes, 'void_reason': voidReason,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };
}
