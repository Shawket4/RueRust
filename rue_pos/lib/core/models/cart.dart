import 'package:flutter/foundation.dart';

@immutable
class SelectedAddon {
  final String addonItemId;
  final String name;
  final int    priceModifier;
  final int    quantity;

  const SelectedAddon({
    required this.addonItemId,
    required this.name,
    required this.priceModifier,
    this.quantity = 1,
  });

  SelectedAddon copyWith({int? quantity}) => SelectedAddon(
    addonItemId:   addonItemId,
    name:          name,
    priceModifier: priceModifier,
    quantity:      quantity ?? this.quantity,
  );

  Map<String, dynamic> toApiJson() => {
    'addon_item_id': addonItemId,
    'quantity':      quantity,
  };

  Map<String, dynamic> toStorageJson() => {
    ...toApiJson(),
    'name':           name,
    'price_modifier': priceModifier,
  };

  factory SelectedAddon.fromStorageJson(Map<String, dynamic> j) => SelectedAddon(
    addonItemId:   j['addon_item_id']  as String,
    name:          (j['name']          as String?) ?? '',
    priceModifier: (j['price_modifier'] as int?)   ?? 0,
    quantity:      (j['quantity']      as int?)    ?? 1,
  );
}

@immutable
class CartItem {
  final String              menuItemId;
  final String              itemName;
  final String?             sizeLabel;
  final int                 unitPrice;
  final int                 quantity;
  final List<SelectedAddon> addons;
  final String?             notes;

  const CartItem({
    required this.menuItemId,
    required this.itemName,
    this.sizeLabel,
    required this.unitPrice,
    this.quantity = 1,
    this.addons   = const [],
    this.notes,
  });

  CartItem copyWith({int? quantity, List<SelectedAddon>? addons, String? notes}) =>
      CartItem(
        menuItemId: menuItemId,
        itemName:   itemName,
        sizeLabel:  sizeLabel,
        unitPrice:  unitPrice,
        notes:      notes    ?? this.notes,
        quantity:   quantity ?? this.quantity,
        addons:     addons   ?? this.addons,
      );

  int get addonsPrice => addons.fold(0, (s, a) => s + a.priceModifier * a.quantity);
  int get lineTotal   => (unitPrice + addonsPrice) * quantity;

  Map<String, dynamic> toApiJson() => {
    'menu_item_id': menuItemId,
    'size_label':   sizeLabel,
    'quantity':     quantity,
    'addons':       addons.map((a) => a.toApiJson()).toList(),
    'notes':        notes,
  };

  Map<String, dynamic> toStorageJson() => {
    ...toApiJson(),
    'item_name':  itemName,
    'unit_price': unitPrice,
    'addons':     addons.map((a) => a.toStorageJson()).toList(),
  };

  factory CartItem.fromStorageJson(Map<String, dynamic> j) => CartItem(
    menuItemId: j['menu_item_id'] as String,
    itemName:   (j['item_name']   as String?) ?? '',
    sizeLabel:  j['size_label']   as String?,
    unitPrice:  (j['unit_price']  as int?)    ?? 0,
    quantity:   (j['quantity']    as int?)    ?? 1,
    notes:      j['notes']        as String?,
    addons: (j['addons'] as List? ?? [])
        .map((a) => SelectedAddon.fromStorageJson(a as Map<String, dynamic>))
        .toList(),
  );

  // Two cart items match if they have the same set of addon_item_ids
  // (order-independent). drinkOptionItemId is gone.
  static bool addonsMatch(List<SelectedAddon> a, List<SelectedAddon> b) {
    if (a.length != b.length) return false;
    final aIds = a.map((x) => x.addonItemId).toSet();
    final bIds = b.map((x) => x.addonItemId).toSet();
    return aIds.containsAll(bIds) && bIds.containsAll(aIds);
  }
}

enum DiscountType { percentage, fixed }

extension DiscountTypeX on DiscountType {
  String get apiValue => name;
}

// ── Payment split ─────────────────────────────────────────────
@immutable
class PaymentSplit {
  final String method;
  final int    amount;

  const PaymentSplit({required this.method, required this.amount});

  Map<String, dynamic> toApiJson() => {'method': method, 'amount': amount};

  PaymentSplit copyWith({String? method, int? amount}) =>
      PaymentSplit(method: method ?? this.method, amount: amount ?? this.amount);
}

@immutable
class CartState {
  final List<CartItem>      items;
  final String              payment;
  final String?             customerName;
  final String?             notes;
  final DiscountType?       discountType;
  final int?                discountValue;
  final String?             discountId;
  final int?                amountTendered;
  final int?                tipAmount;
  final List<PaymentSplit>? paymentSplits;

  const CartState({
    this.items          = const [],
    this.payment        = 'cash',
    this.customerName,
    this.notes,
    this.discountType,
    this.discountValue,
    this.discountId,
    this.amountTendered,
    this.tipAmount,
    this.paymentSplits,
  });

  bool get isEmpty  => items.isEmpty;
  int  get count    => items.fold(0, (s, i) => s + i.quantity);
  int  get subtotal => items.fold(0, (s, i) => s + i.lineTotal);

  int get discountAmount {
    if (discountType == null || (discountValue ?? 0) == 0) return 0;
    return discountType == DiscountType.percentage
        ? (subtotal * discountValue! / 100).round()
        : discountValue!;
  }

  int get total => subtotal - discountAmount;

  int get changeGiven {
    if (amountTendered == null) return 0;
    return (amountTendered! - total).clamp(0, 999999);
  }

  bool get isSplitPayment =>
      paymentSplits != null && paymentSplits!.isNotEmpty;

  CartState copyWith({
    List<CartItem>?      items,
    String?              payment,
    String?              customerName,
    String?              notes,
    DiscountType?        discountType,
    int?                 discountValue,
    String?              discountId,
    int?                 amountTendered,
    int?                 tipAmount,
    List<PaymentSplit>?  paymentSplits,
    bool clearDiscount   = false,
    bool clearCustomer   = false,
    bool clearTendered   = false,
    bool clearSplits     = false,
    bool clearDiscountId = false,
  }) => CartState(
    items:          items          ?? this.items,
    payment:        payment        ?? this.payment,
    customerName:   clearCustomer   ? null : (customerName  ?? this.customerName),
    notes:          notes           ?? this.notes,
    discountType:   clearDiscount   ? null : (discountType  ?? this.discountType),
    discountValue:  clearDiscount   ? null : (discountValue ?? this.discountValue),
    discountId:     clearDiscountId ? null : (discountId    ?? this.discountId),
    amountTendered: clearTendered   ? null : (amountTendered ?? this.amountTendered),
    tipAmount:      tipAmount       ?? this.tipAmount,
    paymentSplits:  clearSplits     ? null : (paymentSplits ?? this.paymentSplits),
  );

  static const empty = CartState();
}