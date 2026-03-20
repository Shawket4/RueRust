import 'order.dart';

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
  /// How many times sync has been attempted and failed for this order.
  final int            retryCount;

  PendingOrder({
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

  PendingOrder copyWith({int? retryCount}) => PendingOrder(
    localId:       localId,
    branchId:      branchId,
    shiftId:       shiftId,
    paymentMethod: paymentMethod,
    customerName:  customerName,
    discountType:  discountType,
    discountValue: discountValue,
    items:         items,
    createdAt:     createdAt,
    retryCount:    retryCount ?? this.retryCount,
  );

  /// Serialise for LOCAL STORAGE — includes display fields (item_name,
  /// unit_price, addon name + price_modifier) that CartItem.toJson() omits
  /// because those are not needed by the API.
  Map<String, dynamic> toJson() => {
    'local_id':      localId,
    'branch_id':     branchId,
    'shift_id':      shiftId,
    'payment_method': paymentMethod,
    'customer_name': customerName,
    'discount_type': discountType,
    'discount_value': discountValue,
    'retry_count':   retryCount,
    'created_at':    createdAt.toIso8601String(),
    'items': items.map((i) => {
      // API fields
      'menu_item_id': i.menuItemId,
      'size_label':   i.sizeLabel,
      'quantity':     i.quantity,
      'notes':        i.notes,
      // Display / restore fields — NOT sent to API but needed for local display
      'item_name':    i.itemName,
      'unit_price':   i.unitPrice,
      'addons': i.addons.map((a) => {
        // API fields
        'addon_item_id':        a.addonItemId,
        'drink_option_item_id': a.drinkOptionItemId,
        // Display / restore fields
        'name':           a.name,
        'price_modifier': a.priceModifier,
      }).toList(),
    }).toList(),
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
    items: (j['items'] as List).map((i) {
      final m = i as Map<String, dynamic>;
      return CartItem(
        menuItemId: m['menu_item_id'] as String,
        itemName:   (m['item_name']   as String?) ?? '',
        sizeLabel:  m['size_label']   as String?,
        unitPrice:  (m['unit_price']  as int?)    ?? 0,
        quantity:   (m['quantity']    as int?)    ?? 1,
        notes:      m['notes']        as String?,
        addons: (m['addons'] as List? ?? []).map((a) {
          final am = a as Map<String, dynamic>;
          return SelectedAddon(
            addonItemId:       am['addon_item_id']        as String,
            drinkOptionItemId: (am['drink_option_item_id'] as String?) ?? '',
            name:              (am['name']                as String?) ?? '',
            priceModifier:     (am['price_modifier']      as int?)    ?? 0,
          );
        }).toList(),
      );
    }).toList(),
  );
}
