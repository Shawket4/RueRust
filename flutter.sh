#!/bin/bash
set -e

# ── Create Flutter project ────────────────────────────────────
flutter create --org com.ruepos --platforms ios,android rue_pos
cd rue_pos

# ── pubspec.yaml ──────────────────────────────────────────────
cat > pubspec.yaml << 'EOF'
name: rue_pos
description: Rue POS — Teller App
publish_to: none
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  go_router: ^13.0.0
  provider: ^6.1.0
  intl: ^0.19.0
  google_fonts: ^6.1.0
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
EOF

# ── Folder structure ──────────────────────────────────────────
mkdir -p lib/{api,models,providers,screens/{auth,shift,order,close_shift},widgets,utils}

# ── lib/utils/constants.dart ─────────────────────────────────
cat > lib/utils/constants.dart << 'EOF'
const String kBaseUrl = 'http://187.124.33.153:8080';
EOF

# ── lib/models/user.dart ──────────────────────────────────────
cat > lib/models/user.dart << 'EOF'
class User {
  final String id;
  final String? orgId;
  final String? branchId;
  final String name;
  final String email;
  final String role;
  final bool isActive;

  const User({
    required this.id,
    this.orgId,
    this.branchId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        orgId: j['org_id'],
        branchId: j['branch_id'],
        name: j['name'],
        email: j['email'],
        role: j['role'],
        isActive: j['is_active'],
      );
}
EOF

# ── lib/models/shift.dart ─────────────────────────────────────
cat > lib/models/shift.dart << 'EOF'
class Shift {
  final String id;
  final String branchId;
  final String tellerId;
  final String tellerName;
  final String status;
  final int openingCash;
  final int? closingCashDeclared;
  final int? closingCashSystem;
  final int? cashDiscrepancy;
  final DateTime openedAt;
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

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'],
        branchId: j['branch_id'],
        tellerId: j['teller_id'],
        tellerName: j['teller_name'],
        status: j['status'],
        openingCash: j['opening_cash'],
        closingCashDeclared: j['closing_cash_declared'],
        closingCashSystem: j['closing_cash_system'],
        cashDiscrepancy: j['cash_discrepancy'],
        openedAt: DateTime.parse(j['opened_at']),
        closedAt: j['closed_at'] != null ? DateTime.parse(j['closed_at']) : null,
      );
}

class ShiftPreFill {
  final bool hasOpenShift;
  final Shift? openShift;
  final int suggestedOpeningCash;

  const ShiftPreFill({
    required this.hasOpenShift,
    this.openShift,
    required this.suggestedOpeningCash,
  });

  factory ShiftPreFill.fromJson(Map<String, dynamic> j) => ShiftPreFill(
        hasOpenShift: j['has_open_shift'],
        openShift: j['open_shift'] != null ? Shift.fromJson(j['open_shift']) : null,
        suggestedOpeningCash: j['suggested_opening_cash'],
      );
}
EOF

# ── lib/models/menu.dart ──────────────────────────────────────
cat > lib/models/menu.dart << 'EOF'
class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        imageUrl: j['image_url'],
        displayOrder: j['display_order'],
        isActive: j['is_active'],
      );
}

class ItemSize {
  final String id;
  final String label;
  final int price;

  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) => ItemSize(
        id: j['id'],
        label: j['label'],
        price: j['price'],
      );
}

class DrinkOptionItem {
  final String id;
  final String name;
  final int priceModifier;

  const DrinkOptionItem({
    required this.id,
    required this.name,
    required this.priceModifier,
  });

  factory DrinkOptionItem.fromJson(Map<String, dynamic> j) => DrinkOptionItem(
        id: j['id'],
        name: j['name'],
        priceModifier: j['price_modifier'] ?? 0,
      );
}

class DrinkOptionGroup {
  final String id;
  final String name;
  final bool isRequired;
  final bool isMultiSelect;
  final List<DrinkOptionItem> items;

  const DrinkOptionGroup({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.isMultiSelect,
    required this.items,
  });

  factory DrinkOptionGroup.fromJson(Map<String, dynamic> j) => DrinkOptionGroup(
        id: j['id'],
        name: j['name'],
        isRequired: j['is_required'] ?? false,
        isMultiSelect: j['is_multi_select'] ?? false,
        items: (j['items'] as List? ?? [])
            .map((i) => DrinkOptionItem.fromJson(i))
            .toList(),
      );
}

class AddonItem {
  final String id;
  final String name;
  final int defaultPrice;
  final String? addonType;

  const AddonItem({
    required this.id,
    required this.name,
    required this.defaultPrice,
    this.addonType,
  });

  factory AddonItem.fromJson(Map<String, dynamic> j) => AddonItem(
        id: j['id'],
        name: j['name'],
        defaultPrice: j['default_price'],
        addonType: j['addon_type'],
      );
}

class MenuItem {
  final String id;
  final String orgId;
  final String? categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int basePrice;
  final bool isActive;
  final int displayOrder;
  final List<ItemSize> sizes;
  final List<DrinkOptionGroup> optionGroups;

  const MenuItem({
    required this.id,
    required this.orgId,
    this.categoryId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.basePrice,
    required this.isActive,
    required this.displayOrder,
    required this.sizes,
    required this.optionGroups,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'],
        orgId: j['org_id'],
        categoryId: j['category_id'],
        name: j['name'],
        description: j['description'],
        imageUrl: j['image_url'],
        basePrice: j['base_price'],
        isActive: j['is_active'],
        displayOrder: j['display_order'],
        sizes: (j['sizes'] as List? ?? [])
            .map((s) => ItemSize.fromJson(s))
            .toList(),
        optionGroups: (j['option_groups'] as List? ?? [])
            .map((g) => DrinkOptionGroup.fromJson(g))
            .toList(),
      );

  int priceForSize(String? sizeLabel) {
    if (sizeLabel == null || sizes.isEmpty) return basePrice;
    final s = sizes.where((s) => s.label == sizeLabel).firstOrNull;
    return s?.price ?? basePrice;
  }
}
EOF

# ── lib/models/order.dart ─────────────────────────────────────
cat > lib/models/order.dart << 'EOF'
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
EOF

# ── lib/models/inventory.dart ─────────────────────────────────
cat > lib/models/inventory.dart << 'EOF'
class InventoryItem {
  final String id;
  final String branchId;
  final String name;
  final String unit;
  final double currentStock;
  final double reorderThreshold;

  const InventoryItem({
    required this.id,
    required this.branchId,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.reorderThreshold,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'],
        branchId: j['branch_id'],
        name: j['name'],
        unit: j['unit'],
        currentStock: double.tryParse(j['current_stock'].toString()) ?? 0,
        reorderThreshold:
            double.tryParse(j['reorder_threshold'].toString()) ?? 0,
      );
}
EOF

# ── lib/api/client.dart ───────────────────────────────────────
cat > lib/api/client.dart << 'EOF'
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

final _storage = FlutterSecureStorage();

Dio createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  // Attach JWT to every request
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      handler.next(error);
    },
  ));

  return dio;
}

final dio = createDio();
EOF

# ── lib/api/auth_api.dart ─────────────────────────────────────
cat > lib/api/auth_api.dart << 'EOF'
import 'client.dart';
import '../models/user.dart';

class AuthApi {
  Future<Map<String, dynamic>> loginWithPin(String pin) async {
    final res = await dio.post('/auth/login', data: {'pin': pin});
    return res.data;
  }

  Future<User> getMe() async {
    final res = await dio.get('/auth/me');
    return User.fromJson(res.data['user']);
  }
}

final authApi = AuthApi();
EOF

# ── lib/api/shift_api.dart ────────────────────────────────────
cat > lib/api/shift_api.dart << 'EOF'
import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> getCurrentShift(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data);
  }

  Future<Shift> openShift(String branchId, int openingCash) async {
    final res = await dio.post('/shifts/branches/$branchId/open', data: {
      'opening_cash': openingCash,
    });
    return Shift.fromJson(res.data);
  }

  Future<Shift> closeShift(
    String shiftId, {
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    final res = await dio.post('/shifts/$shiftId/close', data: {
      'closing_cash_declared': closingCash,
      'cash_note': note,
      'inventory_counts': inventoryCounts,
    });
    return Shift.fromJson(res.data);
  }

  Future<void> addCashMovement(String shiftId, int amount, String note) async {
    await dio.post('/shifts/$shiftId/cash-movements', data: {
      'amount': amount,
      'note': note,
    });
  }
}

final shiftApi = ShiftApi();
EOF

# ── lib/api/menu_api.dart ─────────────────────────────────────
cat > lib/api/menu_api.dart << 'EOF'
import 'client.dart';
import '../models/menu.dart';

class MenuApi {
  Future<List<Category>> getCategories(String orgId) async {
    final res = await dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> getMenuItems(String orgId, {String? categoryId}) async {
    final params = <String, dynamic>{'org_id': orgId};
    if (categoryId != null) params['category_id'] = categoryId;
    final res = await dio.get('/menu-items', queryParameters: params);
    return (res.data as List).map((m) => MenuItem.fromJson(m)).toList();
  }

  Future<MenuItem> getMenuItem(String id) async {
    final res = await dio.get('/menu-items/$id');
    return MenuItem.fromJson(res.data);
  }

  Future<List<AddonItem>> getAddonItems(String orgId) async {
    final res =
        await dio.get('/addon-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((a) => AddonItem.fromJson(a)).toList();
  }
}

final menuApi = MenuApi();
EOF

# ── lib/api/order_api.dart ────────────────────────────────────
cat > lib/api/order_api.dart << 'EOF'
import 'client.dart';
import '../models/order.dart';

class OrderApi {
  Future<Order> createOrder({
    required String branchId,
    required String shiftId,
    required String paymentMethod,
    required List<CartItem> items,
    String? customerName,
    String? notes,
    String? discountType,
    int? discountValue,
  }) async {
    final res = await dio.post('/orders', data: {
      'branch_id': branchId,
      'shift_id': shiftId,
      'payment_method': paymentMethod,
      'customer_name': customerName,
      'notes': notes,
      'discount_type': discountType,
      'discount_value': discountValue,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Order.fromJson(res.data);
  }

  Future<List<Order>> getOrders({String? branchId, String? shiftId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (shiftId != null) params['shift_id'] = shiftId;
    final res = await dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<void> voidOrder(String orderId, String reason) async {
    await dio.post('/orders/$orderId/void', data: {'reason': reason});
  }
}

final orderApi = OrderApi();
EOF

# ── lib/api/inventory_api.dart ────────────────────────────────
cat > lib/api/inventory_api.dart << 'EOF'
import 'client.dart';
import '../models/inventory.dart';

class InventoryApi {
  Future<List<InventoryItem>> getItems(String branchId) async {
    final res =
        await dio.get('/inventory/branches/$branchId/items');
    return (res.data as List).map((i) => InventoryItem.fromJson(i)).toList();
  }
}

final inventoryApi = InventoryApi();
EOF

# ── lib/providers/auth_provider.dart ─────────────────────────
cat > lib/providers/auth_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../api/auth_api.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  User? _user;
  String? _token;
  bool _loading = true;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> init() async {
    _token = await _storage.read(key: 'token');
    if (_token != null) {
      try {
        _user = await authApi.getMe();
      } catch (_) {
        await signOut();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loginWithPin(String pin) async {
    final data = await authApi.loginWithPin(pin);
    _token = data['token'];
    _user = User.fromJson(data['user']);
    await _storage.write(key: 'token', value: _token);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'token');
    _token = null;
    _user = null;
    notifyListeners();
  }
}
EOF

# ── lib/providers/shift_provider.dart ────────────────────────
cat > lib/providers/shift_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../models/shift.dart';
import '../api/shift_api.dart';

class ShiftProvider extends ChangeNotifier {
  Shift? _currentShift;
  ShiftPreFill? _preFill;
  bool _loading = false;
  String? _error;

  Shift? get currentShift => _currentShift;
  ShiftPreFill? get preFill => _preFill;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasOpenShift => _currentShift?.status == 'open';

  Future<void> loadCurrentShift(String branchId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _preFill = await shiftApi.getCurrentShift(branchId);
      _currentShift = _preFill?.openShift;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> openShift(String branchId, int openingCash) async {
    _loading = true;
    notifyListeners();
    try {
      _currentShift = await shiftApi.openShift(branchId, openingCash);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> closeShift(
    String shiftId, {
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      _currentShift = await shiftApi.closeShift(
        shiftId,
        closingCash: closingCash,
        note: note,
        inventoryCounts: inventoryCounts,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _currentShift = null;
    _preFill = null;
    notifyListeners();
  }
}
EOF

# ── lib/providers/cart_provider.dart ─────────────────────────
cat > lib/providers/cart_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../models/order.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _paymentMethod = 'cash';
  String? _customerName;
  String? _discountType;
  int? _discountValue;

  List<CartItem> get items => List.unmodifiable(_items);
  String get paymentMethod => _paymentMethod;
  String? get customerName => _customerName;
  String? get discountType => _discountType;
  int? get discountValue => _discountValue;
  bool get isEmpty => _items.isEmpty;

  int get subtotal => _items.fold(0, (s, i) => s + i.lineTotal);

  int get discountAmount {
    if (_discountType == null || _discountValue == null) return 0;
    if (_discountType == 'percentage') {
      return (subtotal * _discountValue! / 100).round();
    }
    return _discountValue!;
  }

  int get total => subtotal - discountAmount;

  void addItem(CartItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, int qty) {
    if (qty <= 0) {
      removeItem(index);
    } else {
      _items[index].quantity = qty;
      notifyListeners();
    }
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCustomerName(String? name) {
    _customerName = name;
    notifyListeners();
  }

  void setDiscount(String? type, int? value) {
    _discountType = type;
    _discountValue = value;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _paymentMethod = 'cash';
    _customerName = null;
    _discountType = null;
    _discountValue = null;
    notifyListeners();
  }
}
EOF

# ── lib/providers/menu_provider.dart ─────────────────────────
cat > lib/providers/menu_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../models/menu.dart';
import '../api/menu_api.dart';

class MenuProvider extends ChangeNotifier {
  List<Category> _categories = [];
  List<MenuItem> _items = [];
  String? _selectedCategoryId;
  bool _loading = false;

  List<Category> get categories => _categories;
  List<MenuItem> get items => _items;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get loading => _loading;

  List<MenuItem> get filteredItems => _selectedCategoryId == null
      ? _items
      : _items.where((i) => i.categoryId == _selectedCategoryId).toList();

  Future<void> load(String orgId) async {
    _loading = true;
    notifyListeners();
    try {
      _categories = await menuApi.getCategories(orgId);
      _items = await menuApi.getMenuItems(orgId);
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  void selectCategory(String id) {
    _selectedCategoryId = id;
    notifyListeners();
  }
}
EOF

# ── lib/utils/formatting.dart ─────────────────────────────────
cat > lib/utils/formatting.dart << 'EOF'
String formatEGP(int piastres) {
  final egp = piastres / 100;
  if (egp == egp.truncateToDouble()) {
    return 'EGP ${egp.toInt()}';
  }
  return 'EGP ${egp.toStringAsFixed(2)}';
}

String formatEGPDouble(double piastres) => formatEGP(piastres.round());
EOF

# ── lib/widgets/pin_pad.dart ──────────────────────────────────
cat > lib/widgets/pin_pad.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinPad extends StatelessWidget {
  final String pin;
  final int maxLength;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  const PinPad({
    super.key,
    required this.pin,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (i) {
            final filled = i < pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? const Color(0xFF1a56db)
                    : const Color(0xFFE5E7EB),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        // Numpad grid
        _buildGrid(),
      ],
    );
  }

  Widget _buildGrid() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 80);
            return _PinKey(
              label: key,
              onTap: () {
                if (key == '⌫') {
                  onBackspace();
                } else {
                  onDigit(key);
                }
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _PinKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PinKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: label == '⌫' ? 20 : 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}
EOF

# ── lib/widgets/rue_button.dart ───────────────────────────────
cat > lib/widgets/rue_button.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final Color? color;
  final double? width;

  const RueButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.outlined = false,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF1a56db);
    return SizedBox(
      width: width,
      height: 52,
      child: Material(
        color: outlined ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: outlined
                ? BoxDecoration(
                    border: Border.all(color: bg, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: outlined ? bg : Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: outlined ? bg : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
EOF

# ── lib/screens/auth/pin_login_screen.dart ────────────────────
cat > lib/screens/auth/pin_login_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/pin_pad.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;
  static const int _maxPin = 6;

  void _onDigit(String d) {
    if (_pin.length < _maxPin) {
      setState(() {
        _pin += d;
        _error = null;
      });
      if (_pin.length == _maxPin) _submit();
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _submit() async {
    if (_pin.length < 4) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().loginWithPin(_pin);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Invalid PIN. Please try again.';
        _pin = '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1a56db), Color(0xFF3b28cc)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'R',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Rue POS',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter your PIN to continue',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 32),
              PinPad(
                pin: _pin,
                maxLength: _maxPin,
                onDigit: _loading ? (_) {} : _onDigit,
                onBackspace: _loading ? () {} : _onBackspace,
                onSubmit: _submit,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFDC2626),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1a56db),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
EOF

# ── lib/screens/shift/home_screen.dart ───────────────────────
cat > lib/screens/shift/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../utils/formatting.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final branchId = user.branchId;
    if (branchId == null) return; // org_admin / super_admin: no direct branch

    await context.read<ShiftProvider>().loadCurrentShift(branchId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shift = context.watch<ShiftProvider>();
    final user = auth.user!;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_greeting()}, ${user.name.split(' ').first}',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.role.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B7280),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _SignOutButton(),
                ],
              ),
              const SizedBox(height: 32),

              if (shift.loading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF1a56db)))
              else if (shift.hasOpenShift)
                _OpenShiftCard(shift: shift.currentShift!)
              else
                _NoShiftCard(preFillCash: shift.preFill?.suggestedOpeningCash ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _OpenShiftCard extends StatelessWidget {
  final shift;
  const _OpenShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a56db), Color(0xFF3b28cc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '● SHIFT OPEN',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Opening Cash',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            formatEGP(shift.openingCash),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Take Order',
                  icon: Icons.add_shopping_cart_rounded,
                  onTap: () => context.go('/order'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Close Shift',
                  icon: Icons.lock_outline_rounded,
                  onTap: () => context.go('/close-shift'),
                  secondary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoShiftCard extends StatelessWidget {
  final int preFillCash;
  const _NoShiftCard({required this.preFillCash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Open Shift',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a shift to start taking orders.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/open-shift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Open Shift',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool secondary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: secondary
              ? Colors.white.withOpacity(0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: secondary ? Colors.white : const Color(0xFF1a56db)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: secondary ? Colors.white : const Color(0xFF1a56db),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await context.read<AuthProvider>().signOut();
        if (context.mounted) context.go('/login');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              'Sign Out',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
EOF

# ── lib/screens/shift/open_shift_screen.dart ─────────────────
cat > lib/screens/shift/open_shift_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../utils/formatting.dart';
import '../../widgets/rue_button.dart';

class OpenShiftScreen extends StatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preFill = context.read<ShiftProvider>().preFill;
      if (preFill != null) {
        _controller.text = (preFill.suggestedOpeningCash / 100).toStringAsFixed(0);
      }
    });
  }

  Future<void> _open() async {
    final raw = double.tryParse(_controller.text);
    if (raw == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final piastres = (raw * 100).round();
    setState(() { _loading = true; _error = null; });

    final user = context.read<AuthProvider>().user!;

    final branchId = user.branchId;
    if (branchId == null) {
      setState(() { _error = 'No branch assigned to your account'; _loading = false; });
      return;
    }

    await context.read<ShiftProvider>().openShift(branchId, piastres);
    if (mounted) {
      final err = context.read<ShiftProvider>().error;
      if (err != null) {
        setState(() { _error = err; _loading = false; });
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Open Shift',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
      ),
      body: Center(
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Opening Cash',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827)),
                decoration: InputDecoration(
                  prefixText: 'EGP ',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF1a56db), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFFDC2626))),
              ],
              const SizedBox(height: 24),
              RueButton(
                label: 'Open Shift',
                loading: _loading,
                onTap: _open,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
EOF

# ── lib/screens/order/order_screen.dart ──────────────────────
cat > lib/screens/order/order_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/menu_provider.dart';
import '../../models/menu.dart';
import '../../utils/formatting.dart';
import 'item_detail_sheet.dart';
import 'checkout_sheet.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user!;
    if (user.orgId != null) {
      await context.read<MenuProvider>().load(user.orgId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Row(
          children: [
            // ── Left: Menu ────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _MenuHeader(),
                  _CategoryTabs(
                    categories: menu.categories,
                    selectedId: menu.selectedCategoryId,
                    onSelect: menu.selectCategory,
                  ),
                  Expanded(
                    child: menu.loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF1a56db)))
                        : _MenuGrid(items: menu.filteredItems),
                  ),
                ],
              ),
            ),
            // ── Right: Cart ───────────────────────────────────
            Container(
              width: 320,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    left: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
              ),
              child: _CartPanel(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF111827)),
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(width: 8),
          Text(
            'New Order',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final void Function(String) onSelect;

  const _CategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = cat.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1a56db)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  final List<MenuItem> items;
  const _MenuGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text('No items',
            style: GoogleFonts.inter(color: const Color(0xFF9CA3AF))),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuItemCard(item: items[i]),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ItemDetailSheet(item: item),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                alignment: Alignment.center,
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Image.network(item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity))
                    : const Icon(Icons.coffee_rounded,
                        size: 40, color: Color(0xFFD1D5DB)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatEGP(item.basePrice),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1a56db),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Column(
      children: [
        // Cart header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Row(
            children: [
              Text('Order',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827))),
              const Spacer(),
              if (!cart.isEmpty)
                GestureDetector(
                  onTap: cart.clear,
                  child: Text('Clear',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 40, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 8),
                      Text('No items yet',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF9CA3AF))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  itemBuilder: (_, i) => _CartItemRow(index: i),
                ),
        ),
        // Footer
        if (!cart.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827))),
                    Text(
                      formatEGP(cart.total),
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1a56db)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CheckoutSheet(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a56db),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Checkout',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final int index;
  const _CartItemRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName +
                      (item.sizeLabel != null ? ' (${item.sizeLabel})' : ''),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827)),
                ),
              ),
              Text(
                formatEGP(item.lineTotal),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827)),
              ),
            ],
          ),
          if (item.addons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.addons.map((a) => a.name).join(', '),
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () => cart.updateQuantity(index, item.quantity - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.quantity}',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827)),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => cart.updateQuantity(index, item.quantity + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: const Color(0xFF374151)),
      ),
    );
  }
}
EOF

# ── lib/screens/order/item_detail_sheet.dart ─────────────────
cat > lib/screens/order/item_detail_sheet.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/menu.dart';
import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../utils/formatting.dart';

class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  String? _selectedSize;
  final Map<String, String> _selectedOptions = {}; // groupId -> optionItemId
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) {
      _selectedSize = widget.item.sizes.first.label;
    }
  }

  int get _unitPrice {
    if (_selectedSize != null) {
      return widget.item.priceForSize(_selectedSize);
    }
    return widget.item.basePrice;
  }

  int get _addonsPrice {
    int total = 0;
    for (final group in widget.item.optionGroups) {
      final selectedId = _selectedOptions[group.id];
      if (selectedId != null) {
        final opt = group.items.where((i) => i.id == selectedId).firstOrNull;
        if (opt != null) total += opt.priceModifier;
      }
    }
    return total;
  }

  int get _total => (_unitPrice + _addonsPrice) * _quantity;

  void _addToCart() {
    final addons = <CartAddon>[];
    for (final group in widget.item.optionGroups) {
      final selectedId = _selectedOptions[group.id];
      if (selectedId != null) {
        final opt = group.items.where((i) => i.id == selectedId).firstOrNull;
        if (opt != null) {
          addons.add(CartAddon(
            addonItemId: opt.id,
            drinkOptionItemId: opt.id,
            name: opt.name,
            price: opt.priceModifier,
          ));
        }
      }
    }

    context.read<CartProvider>().addItem(CartItem(
          menuItemId: widget.item.id,
          itemName: widget.item.name,
          sizeLabel: _selectedSize,
          unitPrice: _unitPrice,
          quantity: _quantity,
          addons: addons,
        ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.item.name,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827)),
          ),
          if (widget.item.description != null) ...[
            const SizedBox(height: 6),
            Text(widget.item.description!,
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF6B7280))),
          ],
          const SizedBox(height: 20),

          // Sizes
          if (widget.item.sizes.isNotEmpty) ...[
            _SectionLabel('Size'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: widget.item.sizes.map((s) {
                final selected = s.label == _selectedSize;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSize = s.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1a56db)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.label} — ${formatEGP(s.price)}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF374151)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Option groups
          for (final group in widget.item.optionGroups) ...[
            _SectionLabel(group.name + (group.isRequired ? ' *' : '')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: group.items.map((opt) {
                final selected = _selectedOptions[group.id] == opt.id;
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedOptions.remove(group.id);
                    } else {
                      _selectedOptions[group.id] = opt.id;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1a56db)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      opt.priceModifier > 0
                          ? '${opt.name} +${formatEGP(opt.priceModifier)}'
                          : opt.name,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF374151)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Quantity
          Row(
            children: [
              _SectionLabel('Quantity'),
              const Spacer(),
              _QtyControl(
                quantity: _quantity,
                onMinus: () => setState(
                    () => _quantity = (_quantity - 1).clamp(1, 99)),
                onPlus: () =>
                    setState(() => _quantity = (_quantity + 1).clamp(1, 99)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Add to cart
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Add to Order — ${formatEGP(_total)}',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.5),
      );
}

class _QtyControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyControl(
      {required this.quantity,
      required this.onMinus,
      required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Btn(icon: Icons.remove, onTap: onMinus),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$quantity',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
        ),
        _Btn(icon: Icons.add, onTap: onPlus),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: const Color(0xFF374151)),
      ),
    );
  }
}
EOF

# ── lib/screens/order/checkout_sheet.dart ────────────────────
cat > lib/screens/order/checkout_sheet.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/shift_provider.dart';
import '../../api/order_api.dart';
import '../../utils/formatting.dart';

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool _loading = false;
  String? _error;

  final _methods = ['cash', 'card', 'instapay'];

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>();
    final user = context.read<AuthProvider>().user!;

    if (shift.currentShift == null) {
      setState(() => _error = 'No open shift. Please open a shift first.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await orderApi.createOrder(
        branchId: shift.currentShift!.branchId,
        shiftId: shift.currentShift!.id,
        paymentMethod: cart.paymentMethod,
        items: cart.items.toList(),
        customerName: cart.customerName,
        discountType: cart.discountType,
        discountValue: cart.discountValue,
      );
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order placed!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to place order. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Checkout',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 20),

          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SummaryRow('Subtotal', formatEGP(cart.subtotal)),
                if (cart.discountAmount > 0)
                  _SummaryRow('Discount', '- ${formatEGP(cart.discountAmount)}',
                      color: const Color(0xFF059669)),
                const Divider(height: 16),
                _SummaryRow('Total', formatEGP(cart.total), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment method
          Text('Payment Method',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: _methods.map((m) {
              final selected = cart.paymentMethod == m;
              return GestureDetector(
                onTap: () => cart.setPaymentMethod(m),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1a56db)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    m[0].toUpperCase() + m.substring(1),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF374151)),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFFDC2626))),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Place Order',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF374151))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ??
                      (bold
                          ? const Color(0xFF111827)
                          : const Color(0xFF374151)))),
        ],
      ),
    );
  }
}
EOF

# ── lib/screens/close_shift/close_shift_screen.dart ──────────
cat > lib/screens/close_shift/close_shift_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../api/inventory_api.dart';
import '../../models/inventory.dart';
import '../../utils/formatting.dart';
import '../../widgets/rue_button.dart';

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _cashController = TextEditingController();
  final _noteController = TextEditingController();
  List<InventoryItem> _inventoryItems = [];
  final Map<String, TextEditingController> _countControllers = {};
  bool _loadingInventory = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final shift =
        context.read<ShiftProvider>().currentShift;
    if (shift == null) return;
    try {
      final items = await inventoryApi.getItems(shift.branchId);
      setState(() {
        _inventoryItems = items;
        for (final item in items) {
          _countControllers[item.id] =
              TextEditingController(text: item.currentStock.toString());
        }
        _loadingInventory = false;
      });
    } catch (_) {
      setState(() => _loadingInventory = false);
    }
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashController.text);
    if (raw == null) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }

    final piastres = (raw * 100).round();
    final counts = _countControllers.entries.map((e) {
      return {
        'inventory_item_id': e.key,
        'actual_stock': double.tryParse(e.value.text) ?? 0,
      };
    }).toList();

    setState(() { _submitting = true; _error = null; });

    final shift = context.read<ShiftProvider>().currentShift!;
    await context.read<ShiftProvider>().closeShift(
          shift.id,
          closingCash: piastres,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          inventoryCounts: counts,
        );

    if (mounted) {
      final err = context.read<ShiftProvider>().error;
      if (err != null) {
        setState(() { _error = err; _submitting = false; });
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>().currentShift;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF111827)),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Close Shift',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827))),
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift summary card
                      _ShiftSummaryCard(shift: shift),
                      const SizedBox(height: 24),

                      // Closing cash
                      _SectionCard(
                        title: 'Closing Cash',
                        child: Column(
                          children: [
                            TextField(
                              controller: _cashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827)),
                              decoration: InputDecoration(
                                prefixText: 'EGP ',
                                prefixStyle: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: const Color(0xFF6B7280)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1a56db), width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _noteController,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Note (optional)',
                                hintStyle: GoogleFonts.inter(
                                    color: const Color(0xFF9CA3AF)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1a56db), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Inventory counts
                      _SectionCard(
                        title: 'Inventory Count',
                        child: _loadingInventory
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF1a56db)),
                                ),
                              )
                            : _inventoryItems.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No inventory items',
                                        style: GoogleFonts.inter(
                                            color:
                                                const Color(0xFF9CA3AF))),
                                  )
                                : Column(
                                    children:
                                        _inventoryItems.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(item.name,
                                                      style: GoogleFonts
                                                          .inter(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: const Color(
                                                                  0xFF111827))),
                                                  Text(
                                                      'System: ${item.currentStock} ${item.unit}',
                                                      style: GoogleFonts
                                                          .inter(
                                                              fontSize: 12,
                                                              color: const Color(
                                                                  0xFF6B7280))),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 120,
                                              child: TextField(
                                                controller:
                                                    _countControllers[
                                                        item.id],
                                                keyboardType: const TextInputType
                                                    .numberWithOptions(
                                                    decimal: true),
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                  suffixText: item.unit,
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  10)),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(10),
                                                    borderSide:
                                                        const BorderSide(
                                                            color: Color(
                                                                0xFF1a56db),
                                                            width: 2),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ),
                      const SizedBox(height: 16),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFFDC2626))),
                        ),
                        const SizedBox(height: 12),
                      ],

                      RueButton(
                        label: 'Close Shift',
                        loading: _submitting,
                        onTap: _close,
                        width: double.infinity,
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  final shift;
  const _ShiftSummaryCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shift Summary',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 12),
          _Row('Teller', shift.tellerName),
          _Row('Opening Cash', formatEGP(shift.openingCash)),
          _Row('Opened At', shift.openedAt.toLocal().toString().substring(0, 16)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF6B7280))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827))),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
EOF

# ── lib/router.dart ───────────────────────────────────────────
cat > lib/router.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/pin_login_screen.dart';
import 'screens/shift/home_screen.dart';
import 'screens/shift/open_shift_screen.dart';
import 'screens/order/order_screen.dart';
import 'screens/close_shift/close_shift_screen.dart';

GoRouter createRouter(AuthProvider auth) => GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isAuth = auth.isAuthenticated;
        final isLogin = state.matchedLocation == '/login';
        if (!isAuth && !isLogin) return '/login';
        if (isAuth && isLogin) return '/home';
        return null;
      },
      refreshListenable: auth,
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const PinLoginScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/open-shift', builder: (_, __) => const OpenShiftScreen()),
        GoRoute(path: '/order', builder: (_, __) => const OrderScreen()),
        GoRoute(path: '/close-shift', builder: (_, __) => const CloseShiftScreen()),
      ],
    );
EOF

# ── lib/main.dart ─────────────────────────────────────────────
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/menu_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force landscape on tablets
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const RuePOS());
}

class RuePOS extends StatelessWidget {
  const RuePOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthProvider>();
          if (auth.loading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: const Color(0xFFF9FAFB),
                body: Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF1a56db),
                  ),
                ),
              ),
            );
          }
          final router = createRouter(auth);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Rue POS',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1a56db)),
              textTheme: GoogleFonts.interTextTheme(),
              useMaterial3: true,
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
EOF

# ── android/app/src/main/AndroidManifest.xml — add internet ──
# (flutter create already generates this; patch it)
sed -i 's/<application/<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' \
  android/app/src/main/AndroidManifest.xml

echo ""
echo "✅ RuePOS project created successfully!"
echo ""
echo "Next steps:"
echo "  cd rue_pos"
echo "  flutter pub get"
echo "  flutter run"
echo ""
echo "⚠️  One thing to wire up manually:"
echo "  The branch_id is currently a placeholder (user.id)."
echo "  You need to fetch the user's branch assignment from the API"
echo "  or store branch_id in the JWT claims."