import 'order.dart';

/// An order that was created while offline.
/// Stored in a Hive box and synced when connectivity is restored.
class PendingOrder {
  final String        localId;       // UUID generated locally
  final String        shiftId;
  final String        paymentMethod;
  final String?       customerName;
  final String?       notes;
  final String?       discountType;
  final int?          discountValue;
  final List<CartItem> items;
  final DateTime      createdAt;

  PendingOrder({
    required this.localId,
    required this.shiftId,
    required this.paymentMethod,
    this.customerName,
    this.notes,
    this.discountType,
    this.discountValue,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'local_id':       localId,
    'shift_id':       shiftId,
    'payment_method': paymentMethod,
    'customer_name':  customerName,
    'notes':          notes,
    'discount_type':  discountType,
    'discount_value': discountValue,
    'items':          items.map((i) => i.toJson()).toList(),
    'created_at':     createdAt.toIso8601String(),
  };

  factory PendingOrder.fromJson(Map<String, dynamic> j) => PendingOrder(
    localId:       j['local_id'] as String,
    shiftId:       j['shift_id'] as String,
    paymentMethod: j['payment_method'] as String,
    customerName:  j['customer_name'] as String?,
    notes:         j['notes'] as String?,
    discountType:  j['discount_type'] as String?,
    discountValue: j['discount_value'] as int?,
    items: (j['items'] as List).map((i) {
      final m = i as Map<String, dynamic>;
      return CartItem(
        menuItemId: m['menu_item_id'] as String,
        itemName:   m['item_name']   ?? '',
        sizeLabel:  m['size_label']  as String?,
        unitPrice:  m['unit_price']  ?? 0,
        quantity:   m['quantity']    ?? 1,
        addons: (m['addons'] as List? ?? []).map((a) {
          final am = a as Map<String, dynamic>;
          return SelectedAddon(
            addonItemId:        am['addon_item_id'],
            drinkOptionItemId:  am['drink_option_item_id'] ?? '',
            name:               am['name'] ?? '',
            priceModifier:      am['price_modifier'] ?? 0,
          );
        }).toList(),
      );
    }).toList(),
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

