class CartAddon {
  final String addonItemId;
  final String drinkOptionItemId;
  final String name;
  final int price;

  const CartAddon({
    required this.addonItemId,
    required this.drinkOptionItemId,
    required this.name,
    required this.price,
  });
}

class CartItem {
  final String menuItemId;
  final String itemName;
  final String? sizeLabel;
  final int unitPrice;
  int quantity;
  final List<CartAddon> addons;
  final String? notes;

  CartItem({
    required this.menuItemId,
    required this.itemName,
    this.sizeLabel,
    required this.unitPrice,
    this.quantity = 1,
    this.addons = const [],
    this.notes,
  });

  int get addonsTotal => addons.fold(0, (s, a) => s + a.price);
  int get lineTotal => (unitPrice + addonsTotal) * quantity;

  Map<String, dynamic> toJson() => {
        'menu_item_id': menuItemId,
        'size_label': sizeLabel,
        'quantity': quantity,
        'addons': addons
            .map((a) => {
                  'addon_item_id': a.addonItemId,
                  'drink_option_item_id': a.drinkOptionItemId,
                })
            .toList(),
        'notes': notes,
      };
}

class Order {
  final String id;
  final String branchId;
  final String shiftId;
  final int orderNumber;
  final String status;
  final String paymentMethod;
  final int subtotal;
  final int total;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.branchId,
    required this.shiftId,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.subtotal,
    required this.total,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        branchId: j['branch_id'],
        shiftId: j['shift_id'],
        orderNumber: j['order_number'],
        status: j['status'],
        paymentMethod: j['payment_method'],
        subtotal: j['subtotal'],
        total: j['total_amount'],
        createdAt: DateTime.parse(j['created_at']),
      );
}
