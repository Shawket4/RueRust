class SelectedAddon {
  final String addonItemId;
  final String drinkOptionItemId;
  final String name;
  final int    priceModifier;

  const SelectedAddon({
    required this.addonItemId, required this.drinkOptionItemId,
    required this.name, required this.priceModifier,
  });
}

class CartItem {
  final String             menuItemId;
  final String             itemName;
  final String?            sizeLabel;
  final int                unitPrice;
  int                      quantity;
  final List<SelectedAddon> addons;
  final String?            notes;

  CartItem({
    required this.menuItemId, required this.itemName,
    this.sizeLabel, required this.unitPrice,
    this.quantity = 1, this.addons = const [], this.notes,
  });

  int get addonsPrice => addons.fold(0, (s, a) => s + a.priceModifier);
  int get lineTotal   => (unitPrice + addonsPrice) * quantity;

  Map<String, dynamic> toJson() => {
    'menu_item_id': menuItemId,
    'size_label':   sizeLabel,
    'quantity':     quantity,
    'addons': addons.map((a) => {
      'addon_item_id':        a.addonItemId,
      'drink_option_item_id': a.drinkOptionItemId,
    }).toList(),
    'notes': notes,
  };
}

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
    id: j['id'], addonName: j['addon_name'],
    unitPrice: j['unit_price'], quantity: j['quantity'], lineTotal: j['line_total'],
  );
}

class OrderItem {
  final String            id;
  final String            itemName;
  final String?           sizeLabel;
  final int               unitPrice;
  final int               quantity;
  final int               lineTotal;
  final List<OrderItemAddon> addons;

  const OrderItem({
    required this.id, required this.itemName, this.sizeLabel,
    required this.unitPrice, required this.quantity, required this.lineTotal,
    required this.addons,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'], itemName: j['item_name'], sizeLabel: j['size_label'],
    unitPrice: j['unit_price'], quantity: j['quantity'], lineTotal: j['line_total'],
    addons: (j['addons'] as List? ?? [])
        .map((a) => OrderItemAddon.fromJson(a)).toList(),
  );
}

class Order {
  final String      id;
  final String      branchId;
  final String      shiftId;
  final int         orderNumber;
  final String      status;
  final String      paymentMethod;
  final int         subtotal;
  final int         discountAmount;
  final int         taxAmount;
  final int         totalAmount;
  final String?     customerName;
  final String?     notes;
  final DateTime    createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id, required this.branchId, required this.shiftId,
    required this.orderNumber, required this.status, required this.paymentMethod,
    required this.subtotal, required this.discountAmount, required this.taxAmount,
    required this.totalAmount, this.customerName, this.notes,
    required this.createdAt, required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:             j['id'],
    branchId:       j['branch_id'],
    shiftId:        j['shift_id'],
    orderNumber:    j['order_number'],
    status:         j['status'],
    paymentMethod:  j['payment_method'],
    subtotal:       j['subtotal'],
    discountAmount: j['discount_amount'] ?? 0,
    taxAmount:      j['tax_amount']      ?? 0,
    totalAmount:    j['total_amount'],
    customerName:   j['customer_name'],
    notes:          j['notes'],
    createdAt:      DateTime.parse(j['created_at']),
    items: (j['items'] as List? ?? [])
        .map((i) => OrderItem.fromJson(i)).toList(),
  );
}
