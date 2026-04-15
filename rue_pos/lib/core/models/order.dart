class OrderItemAddon {
  final String id;
  final String orderItemId;
  final String addonItemId;
  final String addonName;
  final int    unitPrice;
  final int    quantity;
  final int    lineTotal;

  const OrderItemAddon({
    required this.id,
    required this.orderItemId,
    required this.addonItemId,
    required this.addonName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItemAddon.fromJson(Map<String, dynamic> j) => OrderItemAddon(
    id:          j['id'],
    orderItemId: j['order_item_id'],
    addonItemId: j['addon_item_id'],
    addonName:   j['addon_name'],
    unitPrice:   j['unit_price'],
    quantity:    j['quantity'],
    lineTotal:   j['line_total'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'order_item_id': orderItemId, 'addon_item_id': addonItemId,
    'addon_name': addonName, 'unit_price': unitPrice,
    'quantity': quantity, 'line_total': lineTotal,
  };
}

class OrderItemOptional {
  final String  id;
  final String  orderItemId;
  final String? optionalFieldId;
  final String  fieldName;
  final int     price;
  final String? orgIngredientId;
  final String? ingredientName;
  final String? ingredientUnit;
  final double? quantityDeducted;

  const OrderItemOptional({
    required this.id,
    required this.orderItemId,
    this.optionalFieldId,
    required this.fieldName,
    required this.price,
    this.orgIngredientId,
    this.ingredientName,
    this.ingredientUnit,
    this.quantityDeducted,
  });

  factory OrderItemOptional.fromJson(Map<String, dynamic> j) => OrderItemOptional(
    id:               j['id'],
    orderItemId:      j['order_item_id'],
    optionalFieldId:  j['optional_field_id'] as String?,
    fieldName:        j['field_name'],
    price:            (j['price'] ?? 0) as int,
    orgIngredientId:  j['org_ingredient_id'] as String?,
    ingredientName:   j['ingredient_name']   as String?,
    ingredientUnit:   j['ingredient_unit']   as String?,
    quantityDeducted: j['quantity_deducted'] != null
        ? double.tryParse(j['quantity_deducted'].toString()) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'order_item_id': orderItemId,
    'optional_field_id': optionalFieldId,
    'field_name': fieldName, 'price': price,
    'org_ingredient_id': orgIngredientId,
    'ingredient_name': ingredientName,
    'ingredient_unit': ingredientUnit,
    'quantity_deducted': quantityDeducted,
  };
}

class OrderItem {
  final String                  id;
  final String                  itemName;
  final String?                 sizeLabel;
  final int                     unitPrice;
  final int                     quantity;
  final int                     lineTotal;
  final List<OrderItemAddon>    addons;
  final List<OrderItemOptional> optionals;

  const OrderItem({
    required this.id,
    required this.itemName,
    this.sizeLabel,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.addons,
    this.optionals = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id:        j['id'],
    itemName:  j['item_name'],
    sizeLabel: j['size_label'] as String?,
    unitPrice: j['unit_price'],
    quantity:  j['quantity'],
    lineTotal: j['line_total'],
    addons: (j['addons'] as List? ?? [])
        .map((a) => OrderItemAddon.fromJson(a))
        .toList(),
    optionals: (j['optionals'] as List? ?? [])
        .map((o) => OrderItemOptional.fromJson(o))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'item_name': itemName, 'size_label': sizeLabel,
    'unit_price': unitPrice, 'quantity': quantity, 'line_total': lineTotal,
    'addons':    addons.map((a) => a.toJson()).toList(),
    'optionals': optionals.map((o) => o.toJson()).toList(),
  };
}

class Order {
  final String            id;
  final String            branchId;
  final String            shiftId;
  final String            tellerId;
  final String            tellerName;
  final int               orderNumber;
  final String            status;
  final String            paymentMethod;
  final int               subtotal;
  final String?           discountType;
  final int               discountValue;
  final int               discountAmount;
  final int               taxAmount;
  final int               totalAmount;
  final int?              amountTendered;
  final int?              changeGiven;
  final int?              tipAmount;
  final String?           tipPaymentMethod;
  final String?           discountId;
  final String?           customerName;
  final String?           notes;
  final String?           voidReason;
  final DateTime          createdAt;
  final List<OrderItem>   items;

  const Order({
    required this.id,
    required this.branchId,
    required this.shiftId,
    required this.tellerId,
    required this.tellerName,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.subtotal,
    this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    this.amountTendered,
    this.changeGiven,
    this.tipAmount,
    this.tipPaymentMethod,
    this.discountId,
    this.customerName,
    this.notes,
    this.voidReason,
    required this.createdAt,
    required this.items,
  });

  bool get isVoided => status == 'voided';

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:               j['id'],
    branchId:         j['branch_id'],
    shiftId:          j['shift_id'],
    tellerId:         (j['teller_id']   as String?) ?? '',
    tellerName:       (j['teller_name'] as String?) ?? '',
    orderNumber:      j['order_number'],
    status:           j['status'],
    paymentMethod:    j['payment_method'],
    subtotal:         (j['subtotal']        as int?) ?? 0,
    discountType:     j['discount_type']    as String?,
    discountValue:    (j['discount_value']  as int?) ?? 0,
    discountAmount:   (j['discount_amount'] as int?) ?? 0,
    taxAmount:        (j['tax_amount']      as int?) ?? 0,
    totalAmount:      j['total_amount'],
    amountTendered:   j['amount_tendered']  as int?,
    changeGiven:      j['change_given']     as int?,
    tipAmount:        j['tip_amount']       as int?,
    tipPaymentMethod: j['tip_payment_method'] as String?,
    discountId:       j['discount_id']      as String?,
    customerName:     j['customer_name']    as String?,
    notes:            j['notes']            as String?,
    voidReason:       j['void_reason']      as String?,
    createdAt:        DateTime.parse(j['created_at']),
    items: (j['items'] as List? ?? [])
        .map((i) => OrderItem.fromJson(i))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'branch_id': branchId, 'shift_id': shiftId,
    'teller_id': tellerId, 'teller_name': tellerName,
    'order_number': orderNumber, 'status': status,
    'payment_method': paymentMethod, 'subtotal': subtotal,
    'discount_type': discountType, 'discount_value': discountValue,
    'discount_amount': discountAmount, 'tax_amount': taxAmount,
    'total_amount': totalAmount, 'amount_tendered': amountTendered,
    'change_given': changeGiven, 'tip_amount': tipAmount,
    'tip_payment_method': tipPaymentMethod,
    'discount_id': discountId, 'customer_name': customerName,
    'notes': notes, 'void_reason': voidReason,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };
}
