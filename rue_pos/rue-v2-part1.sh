#!/usr/bin/env bash
# =============================================================================
#  RuePOS v2 — Part 1: Foundation, Models, APIs, Repositories, Services,
#              Notifiers
#  Run from your Flutter project root.
#  Usage: chmod +x rue_pos_v2_part1.sh && ./rue_pos_v2_part1.sh
# =============================================================================
set -euo pipefail
echo "🚀  RuePOS v2 Part 1 — writing foundation..."

# ---------------------------------------------------------------------------
# pubspec.yaml
# ---------------------------------------------------------------------------
cat > pubspec.yaml << 'PUBSPEC'
name: rue_pos
description: Rue Coffee POS — Teller App (v2 Riverpod)
publish_to: none
version: 2.0.0+1

environment:
  sdk: ">=3.2.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.3
  flutter_riverpod: ^2.6.1
  go_router: ^14.2.7
  shared_preferences: ^2.3.2
  google_fonts: ^6.2.1
  lottie: ^3.3.2
  cupertino_icons: ^1.0.8
  intl: ^0.19.0
  uuid: ^4.5.3
  connectivity_plus: ^7.0.0
  starxpand_sdk_wrapper: ^1.0.2
  pdf: ^3.11.1
  printing: ^5.14.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/Icon.png"
  background_color: "#ffffff"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/TheRue.png"

flutter:
  uses-material-design: true
  fonts:
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Regular.ttf
        - asset: assets/fonts/Cairo-SemiBold.ttf
          weight: 700
  assets:
    - assets/TheRue.png
    - assets/lottie/
PUBSPEC

# ---------------------------------------------------------------------------
# Directory skeleton
# ---------------------------------------------------------------------------
mkdir -p lib/{core/{api,models,repositories,services,storage,theme,utils,router},\
features/{auth,home,order,shift},shared/widgets}

# =============================================================================
# MODELS
# =============================================================================

cat > lib/core/models/user.dart << 'DART'
class User {
  final String  id;
  final String? orgId;
  final String? branchId;
  final String  name;
  final String? email;
  final String  role;
  final bool    isActive;

  const User({
    required this.id,
    this.orgId,
    this.branchId,
    required this.name,
    this.email,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id:       j['id']        as String,
    orgId:    j['org_id']    as String?,
    branchId: j['branch_id'] as String?,
    name:     j['name']      as String,
    email:    j['email']     as String?,
    role:     j['role']      as String,
    isActive: j['is_active'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'branch_id': branchId,
    'name': name, 'email': email, 'role': role, 'is_active': isActive,
  };
}
DART

cat > lib/core/models/branch.dart << 'DART'
enum PrinterBrand { star, epson }

class Branch {
  final String        id;
  final String        orgId;
  final String        name;
  final String?       address;
  final String?       phone;
  final PrinterBrand? printerBrand;
  final String?       printerIp;
  final int           printerPort;
  final bool          isActive;

  const Branch({
    required this.id,
    required this.orgId,
    required this.name,
    this.address,
    this.phone,
    this.printerBrand,
    this.printerIp,
    this.printerPort = 9100,
    required this.isActive,
  });

  bool get hasPrinter =>
      printerIp != null && printerIp!.trim().isNotEmpty && printerBrand != null;

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
    id:           j['id']           as String,
    orgId:        j['org_id']       as String,
    name:         j['name']         as String,
    address:      j['address']      as String?,
    phone:        j['phone']        as String?,
    printerBrand: j['printer_brand'] == null
        ? null
        : PrinterBrand.values.byName(j['printer_brand'] as String),
    printerIp:    j['printer_ip']   as String?,
    printerPort:  (j['printer_port'] as int?) ?? 9100,
    isActive:     (j['is_active']   as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'name': name, 'address': address,
    'phone': phone, 'printer_brand': printerBrand?.name,
    'printer_ip': printerIp, 'printer_port': printerPort,
    'is_active': isActive,
  };
}
DART

cat > lib/core/models/shift.dart << 'DART'
class Shift {
  final String    id;
  final String    branchId;
  final String    tellerId;
  final String    tellerName;
  final String    status;
  final int       openingCash;
  final int?      closingCashDeclared;
  final int?      closingCashSystem;
  final int?      cashDiscrepancy;
  final DateTime  openedAt;
  final DateTime? closedAt;

  const Shift({
    required this.id,
    required this.branchId,
    required this.tellerId,
    required this.tellerName,
    required this.status,
    required this.openingCash,
    this.closingCashDeclared,
    this.closingCashSystem,
    this.cashDiscrepancy,
    required this.openedAt,
    this.closedAt,
  });

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
    id:                  j['id'],
    branchId:            j['branch_id'],
    tellerId:            j['teller_id'],
    tellerName:          j['teller_name'],
    status:              j['status'],
    openingCash:         j['opening_cash'],
    closingCashDeclared: j['closing_cash_declared'],
    closingCashSystem:   j['closing_cash_system'],
    cashDiscrepancy:     j['cash_discrepancy'],
    openedAt:            DateTime.parse(j['opened_at']),
    closedAt:            j['closed_at'] != null
        ? DateTime.parse(j['closed_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'branch_id': branchId, 'teller_id': tellerId,
    'teller_name': tellerName, 'status': status,
    'opening_cash': openingCash,
    'closing_cash_declared': closingCashDeclared,
    'closing_cash_system':   closingCashSystem,
    'cash_discrepancy':      cashDiscrepancy,
    'opened_at': openedAt.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
  };
}

class ShiftPreFill {
  final bool   hasOpenShift;
  final Shift? openShift;
  final int    suggestedOpeningCash;

  const ShiftPreFill({
    required this.hasOpenShift,
    this.openShift,
    required this.suggestedOpeningCash,
  });

  factory ShiftPreFill.fromJson(Map<String, dynamic> j) => ShiftPreFill(
    hasOpenShift:         j['has_open_shift'],
    openShift:            j['open_shift'] != null
        ? Shift.fromJson(j['open_shift']) : null,
    suggestedOpeningCash: j['suggested_opening_cash'],
  );
}
DART

cat > lib/core/models/menu.dart << 'DART'
class Category {
  final String  id;
  final String  name;
  final String? imageUrl;
  final int     displayOrder;
  final bool    isActive;

  const Category({
    required this.id, required this.name, this.imageUrl,
    required this.displayOrder, required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'], name: j['name'], imageUrl: j['image_url'],
    displayOrder: j['display_order'], isActive: j['is_active'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'image_url': imageUrl,
    'display_order': displayOrder, 'is_active': isActive,
  };
}

class ItemSize {
  final String id;
  final String label;
  final int    price;
  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) =>
      ItemSize(id: j['id'], label: j['label'], price: j['price_override'] ?? 0);

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'price_override': price};
}

class DrinkOptionItem {
  final String id;
  final String addonItemId;
  final String name;
  final int    price;
  const DrinkOptionItem({
    required this.id, required this.addonItemId,
    required this.name, required this.price,
  });

  factory DrinkOptionItem.fromJson(Map<String, dynamic> j) => DrinkOptionItem(
    id: j['id'], addonItemId: j['addon_item_id'], name: j['name'],
    price: (j['price_override'] ?? j['default_price'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'addon_item_id': addonItemId, 'name': name,
    'price_override': price, 'default_price': price,
  };
}

class DrinkOptionGroup {
  final String                id;
  final String                groupType;
  final bool                  isRequired;
  final bool                  isMultiSelect;
  final List<DrinkOptionItem> items;

  String get displayName => groupType
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  const DrinkOptionGroup({
    required this.id, required this.groupType, required this.isRequired,
    required this.isMultiSelect, required this.items,
  });

  factory DrinkOptionGroup.fromJson(Map<String, dynamic> j) => DrinkOptionGroup(
    id: j['id'], groupType: j['group_type'] ?? '',
    isRequired:   (j['is_required'] ?? false) as bool,
    isMultiSelect: (j['selection_type'] ?? 'single') == 'multi',
    items: (j['items'] as List? ?? [])
        .map((i) => DrinkOptionItem.fromJson(i)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'group_type': groupType, 'is_required': isRequired,
    'selection_type': isMultiSelect ? 'multi' : 'single',
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class MenuItem {
  final String                id;
  final String                orgId;
  final String?               categoryId;
  final String                name;
  final String?               description;
  final String?               imageUrl;
  final int                   basePrice;
  final bool                  isActive;
  final int                   displayOrder;
  final List<ItemSize>        sizes;
  final List<DrinkOptionGroup> optionGroups;

  const MenuItem({
    required this.id, required this.orgId, this.categoryId,
    required this.name, this.description, this.imageUrl,
    required this.basePrice, required this.isActive, required this.displayOrder,
    this.sizes = const [], this.optionGroups = const [],
  });

  int priceForSize(String? label) {
    if (label == null || sizes.isEmpty) return basePrice;
    return sizes.firstWhere((s) => s.label == label,
        orElse: () => ItemSize(id: '', label: '', price: basePrice)).price;
  }

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'], orgId: j['org_id'], categoryId: j['category_id'],
    name: j['name'], description: j['description'], imageUrl: j['image_url'],
    basePrice: j['base_price'], isActive: j['is_active'],
    displayOrder: j['display_order'],
    sizes: (j['sizes'] as List? ?? []).map((s) => ItemSize.fromJson(s)).toList(),
    optionGroups: (j['option_groups'] as List? ?? [])
        .map((g) => DrinkOptionGroup.fromJson(g)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'category_id': categoryId, 'name': name,
    'description': description, 'image_url': imageUrl,
    'base_price': basePrice, 'is_active': isActive, 'display_order': displayOrder,
    'sizes': sizes.map((s) => s.toJson()).toList(),
    'option_groups': optionGroups.map((g) => g.toJson()).toList(),
  };
}
DART

cat > lib/core/models/cart.dart << 'DART'
import 'package:flutter/foundation.dart';

@immutable
class SelectedAddon {
  final String addonItemId;
  final String drinkOptionItemId;
  final String name;
  final int    priceModifier;
  final int    quantity;

  const SelectedAddon({
    required this.addonItemId,
    required this.drinkOptionItemId,
    required this.name,
    required this.priceModifier,
    this.quantity = 1,
  });

  SelectedAddon copyWith({int? quantity}) => SelectedAddon(
    addonItemId: addonItemId, drinkOptionItemId: drinkOptionItemId,
    name: name, priceModifier: priceModifier,
    quantity: quantity ?? this.quantity,
  );

  Map<String, dynamic> toApiJson() => {
    'addon_item_id':        addonItemId,
    'drink_option_item_id': drinkOptionItemId,
    'quantity':             quantity,
  };

  Map<String, dynamic> toStorageJson() => {
    ...toApiJson(),
    'name':           name,
    'price_modifier': priceModifier,
  };

  factory SelectedAddon.fromStorageJson(Map<String, dynamic> j) => SelectedAddon(
    addonItemId:       j['addon_item_id']        as String,
    drinkOptionItemId: (j['drink_option_item_id'] as String?) ?? '',
    name:              (j['name']                as String?) ?? '',
    priceModifier:     (j['price_modifier']      as int?)    ?? 0,
    quantity:          (j['quantity']            as int?)    ?? 1,
  );
}

@immutable
class CartItem {
  final String            menuItemId;
  final String            itemName;
  final String?           sizeLabel;
  final int               unitPrice;
  final int               quantity;
  final List<SelectedAddon> addons;
  final String?           notes;

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
        menuItemId: menuItemId, itemName: itemName, sizeLabel: sizeLabel,
        unitPrice: unitPrice, notes: notes ?? this.notes,
        quantity: quantity ?? this.quantity,
        addons:   addons   ?? this.addons,
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
    itemName:   (j['item_name']  as String?) ?? '',
    sizeLabel:  j['size_label']  as String?,
    unitPrice:  (j['unit_price'] as int?)    ?? 0,
    quantity:   (j['quantity']   as int?)    ?? 1,
    notes:      j['notes']       as String?,
    addons: (j['addons'] as List? ?? [])
        .map((a) => SelectedAddon.fromStorageJson(a as Map<String, dynamic>))
        .toList(),
  );

  static bool addonsMatch(List<SelectedAddon> a, List<SelectedAddon> b) {
    if (a.length != b.length) return false;
    final aIds = a.map((x) => x.drinkOptionItemId).toSet();
    final bIds = b.map((x) => x.drinkOptionItemId).toSet();
    return aIds.containsAll(bIds) && bIds.containsAll(aIds);
  }
}

enum DiscountType { percentage, fixed }

extension DiscountTypeX on DiscountType {
  String get apiValue => name;
}

@immutable
class CartState {
  final List<CartItem> items;
  final String         payment;
  final String?        customerName;
  final String?        notes;
  final DiscountType?  discountType;
  final int?           discountValue;

  const CartState({
    this.items        = const [],
    this.payment      = 'cash',
    this.customerName,
    this.notes,
    this.discountType,
    this.discountValue,
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

  CartState copyWith({
    List<CartItem>? items,
    String?         payment,
    String?         customerName,
    String?         notes,
    DiscountType?   discountType,
    int?            discountValue,
    bool            clearDiscount = false,
    bool            clearCustomer = false,
  }) => CartState(
    items:         items         ?? this.items,
    payment:       payment       ?? this.payment,
    customerName:  clearCustomer  ? null : (customerName ?? this.customerName),
    notes:         notes          ?? this.notes,
    discountType:  clearDiscount  ? null : (discountType  ?? this.discountType),
    discountValue: clearDiscount  ? null : (discountValue ?? this.discountValue),
  );

  static const empty = CartState();
}
DART

cat > lib/core/models/order.dart << 'DART'
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
DART

cat > lib/core/models/pending_order.dart << 'DART'
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
DART

cat > lib/core/models/inventory.dart << 'DART'
class InventoryItem {
  final String id;
  final String name;
  final String unit;
  final double currentStock;

  const InventoryItem({
    required this.id, required this.name,
    required this.unit, required this.currentStock,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    id:           j['id'],
    name:         j['name'],
    unit:         j['unit'],
    currentStock: double.tryParse(j['current_stock'].toString()) ?? 0,
  );
}
DART

# =============================================================================
# STORAGE SERVICE
# =============================================================================

cat > lib/core/storage/storage_service.dart << 'DART'
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  // ── Token ──────────────────────────────────────────────────────────────────
  String? get token          => _prefs.getString('auth_token');
  Future<void> saveToken(String t) => _prefs.setString('auth_token', t);
  Future<void> removeToken()       => _prefs.remove('auth_token');

  // ── User ───────────────────────────────────────────────────────────────────
  Future<void> saveUser(Map<String, dynamic> j) =>
      _prefs.setString('cached_user', jsonEncode(j));

  Map<String, dynamic>? loadUser() {
    final raw = _prefs.getString('cached_user');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  Future<void> removeUser() => _prefs.remove('cached_user');

  // ── Branch ─────────────────────────────────────────────────────────────────
  Future<void> saveBranch(String id, Map<String, dynamic> j) =>
      _prefs.setString('branch_$id', jsonEncode(j));

  Map<String, dynamic>? loadBranch(String id) {
    final raw = _prefs.getString('branch_$id');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  // ── Shift ──────────────────────────────────────────────────────────────────
  Future<void> saveShift(String branchId, Map<String, dynamic> j) =>
      _prefs.setString('shift_$branchId', jsonEncode(j));

  Map<String, dynamic>? loadShift(String branchId) {
    final raw = _prefs.getString('shift_$branchId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  Future<void> removeShift(String branchId) => _prefs.remove('shift_$branchId');

  // ── Menu ───────────────────────────────────────────────────────────────────
  Future<void> saveMenu(String orgId, Map<String, dynamic> j) =>
      _prefs.setString('menu_v2_$orgId', jsonEncode(j));

  Map<String, dynamic>? loadMenu(String orgId) {
    final raw = _prefs.getString('menu_v2_$orgId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { return null; }
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  Future<void> saveOrders(String shiftId, List<Map<String, dynamic>> orders) =>
      _prefs.setString('orders_$shiftId', jsonEncode(orders));

  List<Map<String, dynamic>>? loadOrders(String shiftId) {
    final raw = _prefs.getString('orders_$shiftId');
    if (raw == null) return null;
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return null; }
  }

  // ── Pending (offline queue) ────────────────────────────────────────────────
  static const _pendingKey = 'offline_pending_v2';

  Future<void> savePending(List<Map<String, dynamic>> pending) =>
      _prefs.setString(_pendingKey, jsonEncode(pending));

  List<Map<String, dynamic>> loadPending() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); }
    catch (_) { return []; }
  }

  // ── Clear auth ─────────────────────────────────────────────────────────────
  Future<void> clearAuth() async {
    await removeToken();
    await removeUser();
  }
}

// Seeded in main.dart with the real SharedPreferences instance.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});
DART

# =============================================================================
# API CLIENT
# =============================================================================

cat > lib/core/api/client.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String? _currentToken;
void setAuthToken(String? token) => _currentToken = token;
String? get currentToken => _currentToken;

/// Set by AuthNotifier so the Dio layer can trigger logout on 401.
void Function()? onUnauthorizedCallback;

class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(BaseOptions(
      baseUrl:        'https://rue-pos.ddns.net/api',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout:    const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_currentToken != null) {
          options.headers['Authorization'] = 'Bearer $_currentToken';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (response.data is Map &&
            (response.data as Map).containsKey('error') &&
            response.statusCode == 200) {
          handler.reject(DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: (response.data as Map)['error']?.toString(),
          ));
        } else {
          handler.next(response);
        }
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401) {
          onUnauthorizedCallback?.call();
        }
        handler.next(err);
      },
    ));
  }

  Dio get dio => _dio;
}

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

String friendlyError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Session expired — please sign in again';
    if (code == 403) return 'You do not have permission to do that';
    if (code == 404) return 'Not found';
    if (code == 409) return 'A conflict occurred — resource already exists';
    if (code == 422) return 'Invalid data submitted';
    if (code != null && code >= 500) return 'Server error — please try again';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout       ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out — check your connection';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    final msg = e.response?.data;
    if (msg is Map && msg['message'] != null) return msg['message'].toString();
    if (msg is Map && msg['error']   != null) return msg['error'].toString();
  }
  return 'Something went wrong — please try again';
}

bool isNetworkError(Object e) {
  if (e is DioException) {
    return e.type == DioExceptionType.connectionError    ||
           e.type == DioExceptionType.connectionTimeout  ||
           e.type == DioExceptionType.sendTimeout        ||
           e.type == DioExceptionType.receiveTimeout;
  }
  return false;
}
DART

# ---------------------------------------------------------------------------
# Raw API classes
# ---------------------------------------------------------------------------
cat > lib/core/api/auth_api.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'client.dart';

class AuthApi {
  final DioClient _c;
  AuthApi(this._c);

  Future<Map<String, dynamic>> loginWithPin(
      {required String name, required String pin}) async {
    final res = await _c.dio.post('/auth/login', data: {'name': name, 'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  Future<User> me() async {
    final res = await _c.dio.get('/auth/me');
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }
}

final authApiProvider = Provider<AuthApi>(
    (ref) => AuthApi(ref.watch(dioClientProvider)));
DART

cat > lib/core/api/branch_api.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import 'client.dart';

class BranchApi {
  final DioClient _c;
  BranchApi(this._c);

  Future<Branch> get(String branchId) async {
    final res = await _c.dio.get('/branches/$branchId');
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }
}

final branchApiProvider = Provider<BranchApi>(
    (ref) => BranchApi(ref.watch(dioClientProvider)));
DART

cat > lib/core/api/shift_api.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';
import 'client.dart';

class ShiftApi {
  final DioClient _c;
  ShiftApi(this._c);

  Future<ShiftPreFill> current(String branchId) async {
    final res = await _c.dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Shift>> list(String branchId) async {
    final res = await _c.dio.get('/shifts/branches/$branchId');
    return (res.data as List).map((s) => Shift.fromJson(s)).toList();
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await _c.dio.post('/shifts/branches/$branchId/open',
        data: {'opening_cash': openingCash});
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> close(String shiftId, {
    required int closingCash, String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    final res = await _c.dio.post('/shifts/$shiftId/close', data: {
      'closing_cash_declared': closingCash,
      'cash_note':             note,
      'inventory_counts':      inventoryCounts,
    });
    return Shift.fromJson((res.data as Map<String, dynamic>)['shift'] as Map<String, dynamic>);
  }

  Future<int> systemCash(String shiftId, int openingCash) async {
    final ordersRes = await _c.dio.get('/orders', queryParameters: {'shift_id': shiftId});
    final orders    = (ordersRes.data as List).cast<Map<String, dynamic>>();
    final cashFromOrders = orders
        .where((o) => o['payment_method'] == 'cash' &&
            o['status'] != 'voided' && o['status'] != 'refunded')
        .fold<int>(0, (s, o) => s + (o['total_amount'] as int));

    int movements = 0;
    try {
      final movRes = await _c.dio.get('/shifts/$shiftId/cash-movements');
      movements = (movRes.data as List).fold<int>(0, (s, m) => s + (m['amount'] as int));
    } catch (_) {}

    return openingCash + cashFromOrders + movements;
  }
}

final shiftApiProvider = Provider<ShiftApi>(
    (ref) => ShiftApi(ref.watch(dioClientProvider)));
DART

cat > lib/core/api/menu_api.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu.dart';
import 'client.dart';

class MenuApi {
  final DioClient _c;
  MenuApi(this._c);

  Future<List<Category>> categories(String orgId) async {
    final res = await _c.dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> items(String orgId) async {
    final res = await _c.dio.get('/menu-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((m) => MenuItem.fromJson(m)).toList();
  }

  Future<MenuItem> item(String id) async {
    final res = await _c.dio.get('/menu-items/$id');
    return MenuItem.fromJson(res.data as Map<String, dynamic>);
  }
}

final menuApiProvider = Provider<MenuApi>(
    (ref) => MenuApi(ref.watch(dioClientProvider)));
DART

cat > lib/core/api/order_api.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/order.dart';
import 'client.dart';

class OrderApi {
  final DioClient _c;
  OrderApi(this._c);

  Future<Order> create({
    required String         branchId,
    required String         shiftId,
    required String         paymentMethod,
    required List<CartItem> items,
    String?                 customerName,
    String?                 discountType,
    int?                    discountValue,
    required String         idempotencyKey,
  }) async {
    final res = await _c.dio.post('/orders',
      data: {
        'branch_id':      branchId,
        'shift_id':       shiftId,
        'payment_method': paymentMethod,
        'customer_name':  customerName,
        'discount_type':  discountType,
        'discount_value': discountValue,
        'items':          items.map((i) => i.toApiJson()).toList(),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId  != null) params['shift_id']  = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await _c.dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> get(String id) async {
    final res = await _c.dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> voidOrder(String id,
      {String? reason, bool restoreInventory = false}) async {
    final res = await _c.dio.post('/orders/$id/void', data: {
      'reason':            reason,
      'restore_inventory': restoreInventory,
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

final orderApiProvider = Provider<OrderApi>(
    (ref) => OrderApi(ref.watch(dioClientProvider)));
DART

cat > lib/core/api/inventory_api.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import 'client.dart';

class InventoryApi {
  final DioClient _c;
  InventoryApi(this._c);

  Future<List<InventoryItem>> items(String branchId) async {
    final res = await _c.dio.get('/inventory/branches/$branchId/items');
    return (res.data as List).map((i) => InventoryItem.fromJson(i)).toList();
  }
}

final inventoryApiProvider = Provider<InventoryApi>(
    (ref) => InventoryApi(ref.watch(dioClientProvider)));
DART

# =============================================================================
# REPOSITORIES
# =============================================================================

cat > lib/core/repositories/auth_repository.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api.dart';
import '../api/client.dart';
import '../models/user.dart';
import '../storage/storage_service.dart';

class AuthRepository {
  final AuthApi        _api;
  final StorageService _storage;
  AuthRepository(this._api, this._storage);

  String? get storedToken => _storage.token;

  /// Restore session from disk. Returns null if invalid / no token.
  Future<({String token, User user})?> restoreSession() async {
    final token = _storage.token;
    if (token == null) return null;
    setAuthToken(token);
    try {
      final user = await _api.me();
      await _storage.saveUser(user.toJson());
      return (token: token, user: user);
    } catch (e) {
      if (isNetworkError(e)) {
        final cached = _storage.loadUser();
        if (cached != null) {
          return (token: token, user: User.fromJson(cached));
        }
      }
      // 401 or no cache → clear
      await _storage.clearAuth();
      setAuthToken(null);
      return null;
    }
  }

  Future<({String token, User user})> login(
      {required String name, required String pin}) async {
    final data  = await _api.loginWithPin(name: name, pin: pin);
    final token = data['token'] as String;
    final user  = User.fromJson(data['user'] as Map<String, dynamic>);
    setAuthToken(token);
    await _storage.saveToken(token);
    await _storage.saveUser(user.toJson());
    return (token: token, user: user);
  }

  Future<void> logout() async {
    setAuthToken(null);
    await _storage.clearAuth();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
  ref.watch(authApiProvider),
  ref.watch(storageServiceProvider),
));
DART

cat > lib/core/repositories/shift_repository.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/shift_api.dart';
import '../api/inventory_api.dart';
import '../models/shift.dart';
import '../models/inventory.dart';
import '../storage/storage_service.dart';

class ShiftRepository {
  final ShiftApi       _shiftApi;
  final InventoryApi   _inventoryApi;
  final StorageService _storage;
  ShiftRepository(this._shiftApi, this._inventoryApi, this._storage);

  Future<ShiftPreFill> currentShift(String branchId) async {
    try {
      final preFill = await _shiftApi.current(branchId);
      if (preFill.openShift != null) {
        await _storage.saveShift(branchId, preFill.openShift!.toJson());
      } else {
        await _storage.removeShift(branchId);
      }
      return preFill;
    } catch (_) {
      final cached = _storage.loadShift(branchId);
      if (cached != null) {
        final shift = Shift.fromJson(cached);
        return ShiftPreFill(
            hasOpenShift: shift.isOpen, openShift: shift,
            suggestedOpeningCash: 0);
      }
      rethrow;
    }
  }

  Future<List<Shift>> listShifts(String branchId) =>
      _shiftApi.list(branchId);

  Future<Shift> openShift(String branchId, int openingCash) async {
    final shift = await _shiftApi.open(branchId, openingCash);
    await _storage.saveShift(branchId, shift.toJson());
    return shift;
  }

  Future<Shift> closeShift(String shiftId, {
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    final shift = await _shiftApi.close(shiftId,
        closingCash: closingCash, note: note, inventoryCounts: inventoryCounts);
    await _storage.removeShift(branchId);
    return shift;
  }

  Future<int> getSystemCash(String shiftId, int openingCash) =>
      _shiftApi.systemCash(shiftId, openingCash);

  Future<List<InventoryItem>> getInventory(String branchId) async {
    try { return await _inventoryApi.items(branchId); }
    catch (_) { return []; }
  }
}

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) => ShiftRepository(
  ref.watch(shiftApiProvider),
  ref.watch(inventoryApiProvider),
  ref.watch(storageServiceProvider),
));
DART

cat > lib/core/repositories/menu_repository.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/menu_api.dart';
import '../models/menu.dart';
import '../storage/storage_service.dart';

class MenuRepository {
  final MenuApi        _api;
  final StorageService _storage;
  MenuRepository(this._api, this._storage);

  Future<({List<Category> categories, List<MenuItem> items, bool fromCache})>
      fetchMenu(String orgId) async {
    try {
      final results = await Future.wait([_api.categories(orgId), _api.items(orgId)]);
      final cats  = results[0] as List<Category>;
      final items = results[1] as List<MenuItem>;
      await _storage.saveMenu(orgId, {
        'categories': cats.map((c)  => c.toJson()).toList(),
        'items':      items.map((i) => i.toJson()).toList(),
      });
      return (categories: cats, items: items, fromCache: false);
    } catch (_) {
      final cached = _storage.loadMenu(orgId);
      if (cached != null) {
        return (
          categories: (cached['categories'] as List)
              .map((c) => Category.fromJson(c as Map<String, dynamic>)).toList(),
          items: (cached['items'] as List)
              .map((i) => MenuItem.fromJson(i as Map<String, dynamic>)).toList(),
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  Future<MenuItem> fetchItem(String id) => _api.item(id);
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) => MenuRepository(
  ref.watch(menuApiProvider),
  ref.watch(storageServiceProvider),
));
DART

cat > lib/core/repositories/order_repository.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../models/cart.dart';
import '../models/order.dart';
import '../storage/storage_service.dart';

class OrderRepository {
  final OrderApi       _api;
  final StorageService _storage;
  OrderRepository(this._api, this._storage);

  Future<Order> create({
    required String    branchId,
    required String    shiftId,
    required CartState cart,
    required String    idempotencyKey,
  }) => _api.create(
    branchId:       branchId,
    shiftId:        shiftId,
    paymentMethod:  cart.payment,
    items:          cart.items,
    customerName:   cart.customerName,
    discountType:   cart.discountType?.apiValue,
    discountValue:  cart.discountValue,
    idempotencyKey: idempotencyKey,
  );

  Future<List<Order>> listForShift(String shiftId) async {
    try {
      final orders = await _api.list(shiftId: shiftId);
      await _storage.saveOrders(shiftId, orders.map((o) => o.toJson()).toList());
      return orders;
    } catch (_) {
      final cached = _storage.loadOrders(shiftId);
      if (cached != null) return cached.map(Order.fromJson).toList();
      rethrow;
    }
  }

  Future<Order> get(String id) => _api.get(id);

  Future<Order> voidOrder(String id,
      {String? reason, bool restoreInventory = false}) =>
      _api.voidOrder(id, reason: reason, restoreInventory: restoreInventory);

  void appendOrderToCache(String shiftId, Order order, List<Order> current) {
    final updated = [order, ...current];
    _storage.saveOrders(shiftId, updated.map((o) => o.toJson()).toList());
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository(
  ref.watch(orderApiProvider),
  ref.watch(storageServiceProvider),
));
DART

# =============================================================================
# CONNECTIVITY SERVICE
# =============================================================================

cat > lib/core/services/connectivity_service.dart << 'DART'
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

final connectivityStreamProvider = StreamProvider<bool>((ref) =>
    ConnectivityService.instance.stream);

final isOnlineProvider = Provider<bool>((ref) =>
    ref.watch(connectivityStreamProvider).maybeWhen(
      data: (v) => v,
      orElse: () => ConnectivityService.instance.isOnline,
    ));
DART

# =============================================================================
# OFFLINE QUEUE
# =============================================================================

cat > lib/core/services/offline_queue.dart << 'DART'
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../models/order.dart';
import '../models/pending_order.dart';
import '../storage/storage_service.dart';
import 'connectivity_service.dart';

const _kMaxRetries = 5;

class OfflineQueueState {
  final List<PendingOrder> pending;
  final bool               isSyncing;
  final String?            lastError;

  const OfflineQueueState({
    this.pending   = const [],
    this.isSyncing = false,
    this.lastError,
  });

  int  get count      => pending.length;
  int  get stuckCount => pending.where((p) => p.retryCount >= _kMaxRetries).length;
  bool get hasStuck   => stuckCount > 0;

  OfflineQueueState copyWith({
    List<PendingOrder>? pending,
    bool?               isSyncing,
    String?             lastError,
    bool                clearError = false,
  }) => OfflineQueueState(
    pending:   pending   ?? this.pending,
    isSyncing: isSyncing ?? this.isSyncing,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

class OfflineQueueNotifier extends Notifier<OfflineQueueState> {
  /// Wire this to OrderHistoryNotifier.onOrderSynced after creation.
  void Function(Order)? onOrderSynced;

  StreamSubscription<bool>? _sub;

  @override
  OfflineQueueState build() {
    ref.onDispose(() => _sub?.cancel());
    return const OfflineQueueState();
  }

  Future<void> init() async {
    _loadFromStorage();
    _sub = ConnectivityService.instance.stream.listen((online) {
      if (online && state.pending.isNotEmpty) syncAll();
    });
    if (ConnectivityService.instance.isOnline && state.pending.isNotEmpty) {
      await syncAll();
    }
  }

  void _loadFromStorage() {
    final raw = ref.read(storageServiceProvider).loadPending();
    state = state.copyWith(pending: raw.map(PendingOrder.fromJson).toList());
  }

  Future<void> _persist() async {
    await ref.read(storageServiceProvider)
        .savePending(state.pending.map((p) => p.toJson()).toList());
  }

  Future<void> enqueue(PendingOrder order) async {
    state = state.copyWith(pending: [...state.pending, order]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> syncAll() async {
    if (state.isSyncing || state.pending.isEmpty) return;
    state = state.copyWith(isSyncing: true, clearError: true);

    final api       = ref.read(orderApiProvider);
    final toProcess = List<PendingOrder>.of(state.pending);
    final synced    = <String>{};
    String? lastErr;

    for (final p in toProcess) {
      if (p.retryCount >= _kMaxRetries) continue;
      try {
        final order = await api.create(
          branchId:       p.branchId,
          shiftId:        p.shiftId,
          paymentMethod:  p.paymentMethod,
          items:          p.items,
          customerName:   p.customerName,
          discountType:   p.discountType,
          discountValue:  p.discountValue,
          idempotencyKey: p.localId,
        );
        synced.add(p.localId);
        onOrderSynced?.call(order);
      } catch (e) {
        final idx = state.pending.indexWhere((x) => x.localId == p.localId);
        if (idx >= 0) {
          final updated = List<PendingOrder>.of(state.pending);
          updated[idx] = updated[idx].withIncrementedRetry();
          state = state.copyWith(pending: updated);
        }
        lastErr = e.toString();
      }
    }

    state = state.copyWith(
      pending:   state.pending.where((p) => !synced.contains(p.localId)).toList(),
      isSyncing: false,
      lastError: lastErr,
    );
    await _persist();
  }

  Future<void> discard(String localId) async {
    state = state.copyWith(
        pending: state.pending.where((p) => p.localId != localId).toList());
    await _persist();
  }

  Future<void> resetRetry(String localId) async {
    state = state.copyWith(
      pending: state.pending
          .map((p) => p.localId == localId ? p.withResetRetry() : p)
          .toList(),
    );
    await _persist();
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, OfflineQueueState>(
        OfflineQueueNotifier.new);
DART

# =============================================================================
# NOTIFIERS
# =============================================================================

# ---------------------------------------------------------------------------
# AuthNotifier  — owns User + Branch + post-login shift guard
# ---------------------------------------------------------------------------
cat > lib/core/providers/auth_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/branch_api.dart';
import '../api/client.dart';
import '../api/shift_api.dart';
import '../models/branch.dart';
import '../models/shift.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../storage/storage_service.dart';

enum SessionExpiry { none, expired, blockedByOtherShift }

class AuthState {
  final bool            isLoading;
  final User?           user;
  final Branch?         branch;
  final String?         error;
  final SessionExpiry   sessionExpiry;

  const AuthState({
    this.isLoading     = true,
    this.user,
    this.branch,
    this.error,
    this.sessionExpiry = SessionExpiry.none,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool?          isLoading,
    User?          user,
    Branch?        branch,
    String?        error,
    SessionExpiry? sessionExpiry,
    bool           clearUser   = false,
    bool           clearBranch = false,
    bool           clearError  = false,
  }) => AuthState(
    isLoading:     isLoading     ?? this.isLoading,
    user:          clearUser     ? null : (user   ?? this.user),
    branch:        clearBranch   ? null : (branch ?? this.branch),
    error:         clearError    ? null : (error  ?? this.error),
    sessionExpiry: sessionExpiry ?? this.sessionExpiry,
  );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Wire 401 → auto-logout (fires from Dio interceptor)
    onUnauthorizedCallback = () {
      if (state.user != null) {
        _forceLogout(expiry: SessionExpiry.expired);
      }
    };
    Future.microtask(init);
    return const AuthState();
  }

  // ── Startup restore ────────────────────────────────────────────────────────
  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (session == null) {
      state = const AuthState(isLoading: false);
      return;
    }
    await _hydrateAfterAuth(session.user, emitLoading: false);
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  /// Returns null on success, or an error string.
  Future<String?> login({required String name, required String pin}) async {
    state = state.copyWith(isLoading: true, clearError: true,
        sessionExpiry: SessionExpiry.none);
    try {
      final session = await ref.read(authRepositoryProvider).login(name: name, pin: pin);
      final blockError = await _hydrateAfterAuth(session.user, emitLoading: true);
      return blockError;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return _friendly(e);
    }
  }

  // ── Post-auth hydration + shift guard ─────────────────────────────────────
  /// Loads branch, then checks shift ownership.
  /// Returns a non-null error string if login should be BLOCKED.
  Future<String?> _hydrateAfterAuth(User user, {required bool emitLoading}) async {
    if (emitLoading) state = state.copyWith(isLoading: true);

    // 1. Load branch
    Branch? branch;
    if (user.branchId != null) {
      try {
        branch = await ref.read(branchApiProvider).get(user.branchId!);
        await ref.read(storageServiceProvider).saveBranch(user.branchId!, branch.toJson());
      } catch (_) {
        final cached = ref.read(storageServiceProvider).loadBranch(user.branchId!);
        if (cached != null) branch = Branch.fromJson(cached);
      }
    }

    // 2. Shift ownership guard — only when branch is assigned
    if (user.branchId != null) {
      try {
        final preFill = await ref.read(shiftApiProvider).current(user.branchId!);
        final openShift = preFill.openShift;

        if (openShift != null && openShift.isOpen && openShift.tellerId != user.id) {
          // Another teller's shift is open on this branch → BLOCK
          await ref.read(authRepositoryProvider).logout();
          state = const AuthState(
            isLoading:     false,
            sessionExpiry: SessionExpiry.blockedByOtherShift,
          );
          return 'Branch has an open shift belonging to '
              '"${openShift.tellerName}". '
              'That shift must be closed before anyone else can sign in.';
        }
        // Cache the open shift if it belongs to this user
        if (openShift != null) {
          await ref.read(storageServiceProvider)
              .saveShift(user.branchId!, openShift.toJson());
        }
      } catch (_) {
        // Network error during shift check — allow login, shift screen will handle it
      }
    }

    // 3. All good
    state = state.copyWith(
      isLoading:     false,
      user:          user,
      branch:        branch,
      clearError:    true,
      sessionExpiry: SessionExpiry.none,
    );
    return null;
  }

  // ── Logout guard ───────────────────────────────────────────────────────────
  /// Checks if a shift is open. Returns true if logout is safe.
  /// If a shift is open, the router redirects to close-shift instead.
  Future<bool> canLogout() async {
    final branchId = state.user?.branchId;
    if (branchId == null) return true;
    try {
      final preFill = await ref.read(shiftApiProvider).current(branchId);
      return !(preFill.openShift?.isOpen ?? false);
    } catch (_) {
      // If we can't check (offline), check local cache
      final cached = ref.read(storageServiceProvider).loadShift(branchId);
      if (cached != null) {
        final shift = Shift.fromJson(cached);
        return !shift.isOpen;
      }
      return true;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(isLoading: false);
  }

  void _forceLogout({required SessionExpiry expiry}) {
    ref.read(authRepositoryProvider).logout();
    state = AuthState(isLoading: false, sessionExpiry: expiry);
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('401') || s.contains('invalid'))
      return 'Invalid name or PIN — please try again';
    if (s.contains('network') || s.contains('connection'))
      return 'No internet connection';
    return 'Something went wrong — please try again';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
DART

# ---------------------------------------------------------------------------
# ShiftNotifier
# ---------------------------------------------------------------------------
cat > lib/core/providers/shift_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';

class ShiftState {
  final bool             isLoading;
  final Shift?           shift;
  final int              suggestedOpeningCash;
  final List<InventoryItem> inventory;
  final int              systemCash;
  final bool             systemCashLoading;
  final String?          error;
  final bool             fromCache;

  const ShiftState({
    this.isLoading            = false,
    this.shift,
    this.suggestedOpeningCash = 0,
    this.inventory            = const [],
    this.systemCash           = 0,
    this.systemCashLoading    = false,
    this.error,
    this.fromCache            = false,
  });

  bool get hasOpenShift => shift?.isOpen ?? false;

  ShiftState copyWith({
    bool?              isLoading,
    Shift?             shift,
    int?               suggestedOpeningCash,
    List<InventoryItem>? inventory,
    int?               systemCash,
    bool?              systemCashLoading,
    String?            error,
    bool?              fromCache,
    bool               clearShift = false,
    bool               clearError = false,
  }) => ShiftState(
    isLoading:            isLoading            ?? this.isLoading,
    shift:                clearShift ? null     : (shift ?? this.shift),
    suggestedOpeningCash: suggestedOpeningCash ?? this.suggestedOpeningCash,
    inventory:            inventory            ?? this.inventory,
    systemCash:           systemCash           ?? this.systemCash,
    systemCashLoading:    systemCashLoading    ?? this.systemCashLoading,
    error:                clearError ? null     : (error ?? this.error),
    fromCache:            fromCache            ?? this.fromCache,
  );
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() => const ShiftState();

  Future<void> load(String branchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preFill = await ref.read(shiftRepositoryProvider).currentShift(branchId);
      state = state.copyWith(
        isLoading:            false,
        shift:                preFill.openShift,
        suggestedOpeningCash: preFill.suggestedOpeningCash,
        fromCache:            false,
        clearShift:           preFill.openShift == null,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, fromCache: true,
          error: 'Could not load shift — check connection');
    }
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final shift = await ref.read(shiftRepositoryProvider)
          .openShift(branchId, openingCash);
      state = state.copyWith(isLoading: false, shift: shift);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  /// Close shift. On success clears the shift and returns true.
  /// Returns false + sets error on failure.
  Future<bool> closeShift({
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (state.shift == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(shiftRepositoryProvider).closeShift(
        state.shift!.id,
        branchId:        branchId,
        closingCash:     closingCash,
        note:            note,
        inventoryCounts: inventoryCounts,
      );
      state = state.copyWith(
          isLoading: false, clearShift: true, systemCash: 0);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<void> loadSystemCash() async {
    final shift = state.shift;
    if (shift == null) return;
    state = state.copyWith(systemCashLoading: true);
    try {
      final cash = await ref.read(shiftRepositoryProvider)
          .getSystemCash(shift.id, shift.openingCash);
      state = state.copyWith(systemCash: cash, systemCashLoading: false);
    } catch (_) {
      state = state.copyWith(systemCashLoading: false);
    }
  }

  Future<void> loadInventory(String branchId) async {
    final items = await ref.read(shiftRepositoryProvider).getInventory(branchId);
    state = state.copyWith(inventory: items);
  }

  void onShiftClosed() {
    state = state.copyWith(clearShift: true, systemCash: 0);
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('409')) return 'A shift is already open for this branch';
    if (s.contains('404')) return 'Shift not found';
    if (s.contains('401')) return 'Session expired — please sign in again';
    return 'Something went wrong — please try again';
  }
}

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
DART

# ---------------------------------------------------------------------------
# CartNotifier
# ---------------------------------------------------------------------------
cat > lib/core/providers/cart_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => CartState.empty;

  void add(CartItem incoming) {
    final idx = state.items.indexWhere((i) =>
        i.menuItemId == incoming.menuItemId &&
        i.sizeLabel  == incoming.sizeLabel  &&
        CartItem.addonsMatch(i.addons, incoming.addons));

    if (idx >= 0) {
      final updated = List<CartItem>.of(state.items);
      updated[idx] = updated[idx].copyWith(
          quantity: updated[idx].quantity + incoming.quantity);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, incoming]);
    }
  }

  void removeAt(int index) {
    final updated = List<CartItem>.of(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void setQty(int index, int qty) {
    if (qty <= 0) { removeAt(index); return; }
    final updated = List<CartItem>.of(state.items);
    updated[index] = updated[index].copyWith(quantity: qty);
    state = state.copyWith(items: updated);
  }

  void setPayment(String m)   => state = state.copyWith(payment: m);
  void setCustomer(String? n) => state = state.copyWith(customerName: n, clearCustomer: n == null);
  void setNotes(String? n)    => state = state.copyWith(notes: n);

  void setDiscount(DiscountType? type, int? value) => state = type == null
      ? state.copyWith(clearDiscount: true)
      : state.copyWith(discountType: type, discountValue: value);

  void clear() => state = CartState.empty;
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
DART

# ---------------------------------------------------------------------------
# MenuNotifier
# ---------------------------------------------------------------------------
cat > lib/core/providers/menu_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu.dart';
import '../repositories/menu_repository.dart';

class MenuState {
  final List<Category> categories;
  final List<MenuItem> items;
  final String?        selectedCategoryId;
  final bool           isLoading;
  final bool           fromCache;
  final String?        error;
  final String?        loadedOrgId;

  const MenuState({
    this.categories        = const [],
    this.items             = const [],
    this.selectedCategoryId,
    this.isLoading         = false,
    this.fromCache         = false,
    this.error,
    this.loadedOrgId,
  });

  List<MenuItem> get filtered => selectedCategoryId == null
      ? items
      : items.where((i) => i.categoryId == selectedCategoryId).toList();

  MenuState copyWith({
    List<Category>? categories,
    List<MenuItem>? items,
    String?         selectedCategoryId,
    bool?           isLoading,
    bool?           fromCache,
    String?         error,
    String?         loadedOrgId,
    bool            clearError = false,
  }) => MenuState(
    categories:         categories         ?? this.categories,
    items:              items              ?? this.items,
    selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    isLoading:          isLoading          ?? this.isLoading,
    fromCache:          fromCache          ?? this.fromCache,
    error:              clearError ? null  : (error ?? this.error),
    loadedOrgId:        loadedOrgId        ?? this.loadedOrgId,
  );
}

class MenuNotifier extends Notifier<MenuState> {
  @override
  MenuState build() => const MenuState();

  Future<void> load(String orgId, {bool force = false}) async {
    if (!force && state.loadedOrgId == orgId &&
        state.items.isNotEmpty && !state.fromCache) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(menuRepositoryProvider).fetchMenu(orgId);
      state = state.copyWith(
        isLoading:          false,
        categories:         result.categories,
        items:              result.items,
        fromCache:          result.fromCache,
        loadedOrgId:        orgId,
        selectedCategoryId: result.categories.isNotEmpty
            ? result.categories.first.id : null,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'No connection and no cached menu available');
    }
  }

  void selectCategory(String id) => state = state.copyWith(selectedCategoryId: id);
}

final menuProvider =
    NotifierProvider<MenuNotifier, MenuState>(MenuNotifier.new);
DART

# ---------------------------------------------------------------------------
# OrderHistoryNotifier
# ---------------------------------------------------------------------------
cat > lib/core/providers/order_history_notifier.dart << 'DART'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';

class OrderHistoryState {
  final List<Order> orders;
  final bool        isLoading;
  final bool        fromCache;
  final String?     error;
  final String?     shiftId;

  const OrderHistoryState({
    this.orders    = const [],
    this.isLoading = false,
    this.fromCache = false,
    this.error,
    this.shiftId,
  });

  OrderHistoryState copyWith({
    List<Order>? orders,
    bool?        isLoading,
    bool?        fromCache,
    String?      error,
    String?      shiftId,
    bool         clearError = false,
  }) => OrderHistoryState(
    orders:    orders    ?? this.orders,
    isLoading: isLoading ?? this.isLoading,
    fromCache: fromCache ?? this.fromCache,
    error:     clearError ? null : (error ?? this.error),
    shiftId:   shiftId   ?? this.shiftId,
  );
}

class OrderHistoryNotifier extends Notifier<OrderHistoryState> {
  @override
  OrderHistoryState build() => const OrderHistoryState();

  Future<void> loadForShift(String shiftId, {bool force = false}) async {
    if (!force && state.shiftId == shiftId && state.orders.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await ref.read(orderRepositoryProvider).listForShift(shiftId);
      state = state.copyWith(
          isLoading: false, orders: orders, shiftId: shiftId, fromCache: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, fromCache: true,
          error: 'Could not load orders — check connection');
    }
  }

  /// Called after a successful order placement (online or synced offline).
  void addOrder(Order order) {
    if (state.orders.any((o) => o.id == order.id)) return;
    final updated = [order, ...state.orders];
    state = state.copyWith(orders: updated);
    if (state.shiftId != null) {
      ref.read(orderRepositoryProvider).appendOrderToCache(
          state.shiftId!, order, state.orders);
    }
  }

  void updateOrder(Order updated) {
    state = state.copyWith(
      orders: state.orders.map((o) => o.id == updated.id ? updated : o).toList(),
    );
  }

  void clear() => state = const OrderHistoryState();
}

final orderHistoryProvider =
    NotifierProvider<OrderHistoryNotifier, OrderHistoryState>(
        OrderHistoryNotifier.new);
DART

# =============================================================================
# UTILS + THEME
# =============================================================================

cat > lib/core/utils/formatting.dart << 'DART'
import 'package:intl/intl.dart';

String egp(int piastres) {
  final v = piastres / 100;
  return 'EGP ${v == v.truncateToDouble() ? v.toInt() : v.toStringAsFixed(2)}';
}

String egpD(double p) => egp(p.round());
String timeShort(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());
String dateShort(DateTime dt) => DateFormat('MMM d').format(dt.toLocal());
String dateTime(DateTime dt)  => DateFormat('MMM d, hh:mm a').format(dt.toLocal());

String normaliseName(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');
DART

cat > lib/core/theme/app_theme.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary       = Color(0xFF1a56db);
  static const secondary     = Color(0xFF3b28cc);
  static const success       = Color(0xFF059669);
  static const danger        = Color(0xFFDC2626);
  static const warning       = Color(0xFFD97706);
  static const bg            = Color(0xFFF2F3F7);
  static const surface       = Colors.white;
  static const border        = Color(0xFFE5E7EB);
  static const borderLight   = Color(0xFFF3F4F6);
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);
}

TextStyle cairo({
  double fontSize       = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color           = AppColors.textPrimary,
  double? height,
  double letterSpacing  = 0,
  TextDecoration? decoration,
}) => GoogleFonts.cairo(
  fontSize: fontSize, fontWeight: fontWeight, color: color,
  height: height, letterSpacing: letterSpacing, decoration: decoration,
);

class AppTheme {
  static ThemeData get light {
    final base = GoogleFonts.cairoTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.cairo(
            fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger)),
        hintStyle: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 15),
      ),
    );
  }
}
DART

# =============================================================================
# SHARED WIDGETS
# =============================================================================

cat > lib/shared/widgets/app_button.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BtnVariant { primary, danger, outline, ghost }

class AppButton extends StatefulWidget {
  final String        label;
  final VoidCallback? onTap;
  final bool          loading;
  final BtnVariant    variant;
  final double?       width;
  final IconData?     icon;
  final double        height;

  const AppButton({
    super.key, required this.label, this.onTap, this.loading = false,
    this.variant = BtnVariant.primary, this.width, this.icon, this.height = 48,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _enabled => !widget.loading && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (widget.variant) {
      BtnVariant.primary => (AppColors.primary,       Colors.white),
      BtnVariant.danger  => (AppColors.danger,          Colors.white),
      BtnVariant.outline => (Colors.transparent,        AppColors.primary),
      BtnVariant.ghost   => (Colors.transparent,        AppColors.textSecondary),
    };
    final hasBorder = widget.variant == BtnVariant.outline;

    return GestureDetector(
      onTapDown:   (_) { if (_enabled) _ctrl.forward(); },
      onTapUp:     (_) { if (_enabled) { _ctrl.reverse(); widget.onTap!(); } },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: widget.width, height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color:        _enabled ? bg : bg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: hasBorder
                  ? Border.all(color: AppColors.primary) : null,
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 17, color: fg),
                      const SizedBox(width: 7),
                    ],
                    Text(widget.label,
                        style: cairo(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
                  ]),
          ),
        ),
      ),
    );
  }
}
DART

cat > lib/shared/widgets/card_container.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CardContainer extends StatelessWidget {
  final Widget              child;
  final EdgeInsetsGeometry? padding;
  final Color?              color;
  final double              radius;

  const CardContainer({
    super.key, required this.child,
    this.padding, this.color, this.radius = 16,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}
DART

cat > lib/shared/widgets/error_banner.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback? onRetry;
  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.danger.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: cairo(fontSize: 13, color: AppColors.danger))),
      if (onRetry != null)
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: cairo(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
    ]),
  );
}
DART

cat > lib/shared/widgets/label_value.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LabelValue extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool   bold;
  const LabelValue(this.label, this.value,
      {super.key, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: cairo(fontSize: 13, color: AppColors.textSecondary)),
      Text(value,  style: cairo(fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: valueColor ?? AppColors.textPrimary)),
    ]),
  );
}
DART

cat > lib/shared/widgets/pin_pad.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final String               pin;
  final int                  maxLength;
  final void Function(String) onDigit;
  final VoidCallback         onBackspace;

  const PinPad({super.key, required this.pin, required this.maxLength,
      required this.onDigit, required this.onBackspace});

  static const _rows = [
    ['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    final keySize = MediaQuery.of(context).size.width >= 768 ? 80.0 : 68.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < pin.length ? AppColors.primary : Colors.transparent,
              border: Border.all(
                  color: i < pin.length ? AppColors.primary : AppColors.border,
                  width: 2),
            ),
          ))),
      const SizedBox(height: 28),
      ..._rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              if (k.isEmpty) return SizedBox(width: keySize, height: keySize);
              return _Key(label: k, size: keySize,
                  onTap: () => k == '⌫' ? onBackspace() : onDigit(k));
            }).toList()),
      )),
    ]);
  }
}

class _Key extends StatefulWidget {
  final String label; final double size; final VoidCallback onTap;
  const _Key({required this.label, required this.size, required this.onTap});
  @override State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  @override void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => _ctrl.forward(),
    onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: ()  => _ctrl.reverse(),
    child: ScaleTransition(scale: _scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 4, offset: const Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(widget.label, style: cairo(
            fontSize: widget.label == '⌫' ? 18 : 22,
            fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
    ),
  );
}
DART

# =============================================================================
# PRINTER SERVICE
# =============================================================================

cat > lib/core/services/printer_service.dart << 'DART'
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
import '../models/branch.dart';
import '../models/order.dart';
import '../utils/formatting.dart';

class PrinterService {
  static const _printerWidth = 576;
  static const _timeout = Duration(seconds: 5);

  static Future<String?> print({
    required String ip, required int port,
    required PrinterBrand brand, required Order order,
    required String branchName,
  }) async {
    final cleanIp  = ip.split('/').first;
    final pdfBytes = await _buildReceiptPdf(order: order, branchName: branchName);
    return switch (brand) {
      PrinterBrand.star  => _printStar(ip: cleanIp, pdfBytes: pdfBytes),
      PrinterBrand.epson => _printEpson(ip: cleanIp, port: port, pdfBytes: pdfBytes),
    };
  }

  static Future<String?> _printStar({required String ip, required Uint8List pdfBytes}) async {
    try {
      final device    = StarDevice(ip, StarInterfaceType.lan);
      final connected = await StarXpand.instance.connect(device, monitor: false);
      if (!connected) return 'Could not connect to Star printer';
      final ok = await StarXpand.instance.printPdf(pdfBytes, width: _printerWidth);
      return ok ? null : 'Star print failed';
    } catch (e) { return 'Star printer error: $e'; }
    finally { await StarXpand.instance.disconnect(); }
  }

  static Future<String?> _printEpson({
    required String ip, required int port, required Uint8List pdfBytes,
  }) async {
    Socket? socket;
    try {
      final page     = await Printing.raster(pdfBytes, dpi: 203).first;
      final png      = await page.toPng();
      final imgBytes = await _pngToEscPos(png, page.width, page.height);
      socket = await Socket.connect(ip, port, timeout: _timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.add(imgBytes);
      await socket.flush().timeout(_timeout);
      return null;
    } on TimeoutException { return 'Epson printer timeout'; }
    on SocketException catch (e) { return 'Epson printer error: ${e.message}'; }
    catch (e) { return 'Epson printer error: $e'; }
    finally { await socket?.close(); }
  }

  static Future<Uint8List> _pngToEscPos(Uint8List png, int w, int h) async {
    final codec   = await ui.instantiateImageCodec(png);
    final frame   = await codec.getNextFrame();
    final imgData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (imgData == null) throw Exception('Failed to decode image');
    final pixels  = imgData.buffer.asUint8List();
    final buf     = <int>[];
    buf.addAll([0x1B, 0x40]);
    final wB = (w + 7) ~/ 8;
    buf.addAll([0x1D,0x76,0x30,0x00, wB&0xFF,(wB>>8)&0xFF, h&0xFF,(h>>8)&0xFF]);
    for (int y = 0; y < h; y++) {
      for (int xB = 0; xB < wB; xB++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = xB * 8 + bit;
          if (x < w) {
            final idx = (y * w + x) * 4;
            final r=pixels[idx]; final g=pixels[idx+1];
            final b=pixels[idx+2]; final a=pixels[idx+3];
            final rW=((r*a)+(255*(255-a)))~/255;
            final gW=((g*a)+(255*(255-a)))~/255;
            final bW=((b*a)+(255*(255-a)))~/255;
            if ((0.299*rW+0.587*gW+0.114*bW).round() < 128) byte |= (0x80>>bit);
          }
        }
        buf.add(byte);
      }
    }
    buf.addAll([0x1B,0x64,0x05,0x1D,0x56,0x41,0x05]);
    return Uint8List.fromList(buf);
  }

  static Future<Uint8List> _buildReceiptPdf({
    required Order order, required String branchName,
  }) async {
    final pdf          = pw.Document();
    final font         = pw.Font.ttf((await rootBundle.load('assets/fonts/Cairo-Regular.ttf')).buffer.asByteData());
    final fontB        = pw.Font.ttf((await rootBundle.load('assets/fonts/Cairo-SemiBold.ttf')).buffer.asByteData());
    final logo         = pw.MemoryImage((await rootBundle.load('assets/TheRue.png')).buffer.asUint8List());
    const cw           = 40;
    pw.TextStyle ts(pw.Font f, {double sz=8}) => pw.TextStyle(font:f,fontSize:sz);
    pw.Widget div()    => pw.Divider(thickness:0.3,color:PdfColors.grey600,height:4);
    String pad(String l,String r){final sp=cw-l.length-r.length;return sp<=0?'$l $r':l+' '*sp+r;}
    final dt  = order.createdAt.toLocal();
    final dts = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${timeShort(order.createdAt)}';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(72*PdfPageFormat.mm, double.infinity,
          marginTop:2*PdfPageFormat.mm,marginBottom:2*PdfPageFormat.mm,
          marginLeft:2*PdfPageFormat.mm,marginRight:2*PdfPageFormat.mm),
      build: (ctx) => pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch, children:[
        pw.Center(child:pw.Image(logo,width:56)),
        pw.Center(child:pw.Text(branchName,style:ts(font,sz:7.5))),
        pw.SizedBox(height:2), div(),
        pw.Text(pad('Order #${order.orderNumber}',dts),style:ts(fontB,sz:8)),
        div(),
        ...order.items.expand((item){
          final sz = item.sizeLabel!=null?' (${item.sizeLabel})':'';
          return[
            pw.Text(pad('${item.quantity}x ${item.itemName}$sz',egp(item.lineTotal)),style:ts(fontB,sz:8)),
            ...item.addons.map((a){
              final ap=a.unitPrice>0?'+${egp(a.unitPrice)}':'';
              final al='  + ${a.addonName}';
              return pw.Text(ap.isNotEmpty?pad(al,ap):al,style:ts(font,sz:7.5));
            }),
          ];
        }),
        div(),
        pw.Text(pad('Subtotal',egp(order.subtotal)),style:ts(font,sz:8)),
        if(order.discountAmount>0) pw.Text(pad('Discount','- ${egp(order.discountAmount)}'),style:ts(font,sz:8)),
        if(order.taxAmount>0) pw.Text(pad('Tax',egp(order.taxAmount)),style:ts(font,sz:8)),
        pw.Text(pad('TOTAL',egp(order.totalAmount)),style:ts(fontB,sz:10)),
        div(),
        pw.Text(pad('Payment',order.paymentMethod[0].toUpperCase()+order.paymentMethod.substring(1).replaceAll('_',' ')),style:ts(font,sz:7.5)),
        if(order.customerName!=null&&order.customerName!.isNotEmpty) pw.Text(pad('Customer',order.customerName!),style:ts(font,sz:7.5)),
        if(order.tellerName.isNotEmpty) pw.Text(pad('Teller',order.tellerName),style:ts(font,sz:7.5)),
        pw.SizedBox(height:3),
        pw.Center(child:pw.Text('Thank you for visiting!',style:ts(font,sz:7.5))),
        pw.SizedBox(height:2), div(),
      ]),
    ));
    return pdf.save();
  }
}
DART

echo ""
echo "✅  Part 1 complete — foundation, models, APIs, repos, services, notifiers written."
echo "👉  Now run:  ./rue_pos_v2_part2.sh"