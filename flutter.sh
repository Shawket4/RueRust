#!/usr/bin/env bash
# =============================================================================
#  RuePOS — Complete Flutter Project
#  Usage: chmod +x create_rue_pos.sh && ./create_rue_pos.sh
# =============================================================================
set -euo pipefail

PROJECT="rue_pos"
BASE_URL="http://187.124.33.153:8080"

echo "🚀  Creating Flutter project..."
flutter create --org com.ruepos --platforms ios,android,macos "$PROJECT"
cd "$PROJECT"

# =============================================================================
#  pubspec.yaml
# =============================================================================
cat > pubspec.yaml << 'EOF'
name: rue_pos
description: Rue Coffee POS — Teller App
publish_to: none
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.3
  shared_preferences: ^2.3.2
  go_router: ^14.2.7
  provider: ^6.1.2
  google_fonts: ^6.2.1
  intl: ^0.19.0
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
EOF

# =============================================================================
#  Directories
# =============================================================================
mkdir -p lib/core/{api,models,providers,router,theme,utils}
mkdir -p lib/features/{auth,home,order,shift}
mkdir -p lib/shared/widgets

# =============================================================================
#  core/theme/app_theme.dart
# =============================================================================
cat > lib/core/theme/app_theme.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary     = Color(0xFF1a56db);
  static const secondary   = Color(0xFF3b28cc);
  static const success     = Color(0xFF059669);
  static const danger      = Color(0xFFDC2626);
  static const warning     = Color(0xFFD97706);
  static const bg          = Color(0xFFF9FAFB);
  static const surface     = Colors.white;
  static const border      = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 15),
    ),
  );
}
EOF

# =============================================================================
#  core/utils/formatting.dart
# =============================================================================
cat > lib/core/utils/formatting.dart << 'EOF'
import 'package:intl/intl.dart';

String egp(int piastres) {
  final v = piastres / 100;
  return 'EGP ${v == v.truncateToDouble() ? v.toInt() : v.toStringAsFixed(2)}';
}

String egpD(double p) => egp(p.round());
String timeShort(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());
String dateShort(DateTime dt) => DateFormat('MMM d').format(dt.toLocal());
String dateTime(DateTime dt)  => DateFormat('MMM d, hh:mm a').format(dt.toLocal());
EOF

# =============================================================================
#  core/models/user.dart
# =============================================================================
cat > lib/core/models/user.dart << 'EOF'
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
}
EOF

# =============================================================================
#  core/models/shift.dart
# =============================================================================
cat > lib/core/models/shift.dart << 'EOF'
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
    closedAt:            j['closed_at'] != null ? DateTime.parse(j['closed_at']) : null,
  );
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
    openShift:            j['open_shift'] != null ? Shift.fromJson(j['open_shift']) : null,
    suggestedOpeningCash: j['suggested_opening_cash'],
  );
}
EOF

# =============================================================================
#  core/models/menu.dart
# =============================================================================
cat > lib/core/models/menu.dart << 'EOF'
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
}

class ItemSize {
  final String id;
  final String label;
  final int    price;
  const ItemSize({required this.id, required this.label, required this.price});
  factory ItemSize.fromJson(Map<String, dynamic> j) =>
      ItemSize(id: j['id'], label: j['label'], price: j['price']);
}

class DrinkOptionItem {
  final String id;
  final String name;
  final int    priceModifier;
  const DrinkOptionItem({
    required this.id, required this.name, required this.priceModifier,
  });
  factory DrinkOptionItem.fromJson(Map<String, dynamic> j) => DrinkOptionItem(
    id: j['id'], name: j['name'],
    priceModifier: (j['price_modifier'] ?? 0) as int,
  );
}

class DrinkOptionGroup {
  final String                id;
  final String                name;
  final bool                  isRequired;
  final bool                  isMultiSelect;
  final List<DrinkOptionItem> items;
  const DrinkOptionGroup({
    required this.id, required this.name,
    required this.isRequired, required this.isMultiSelect, required this.items,
  });
  factory DrinkOptionGroup.fromJson(Map<String, dynamic> j) => DrinkOptionGroup(
    id: j['id'], name: j['name'],
    isRequired:    (j['is_required']     ?? false) as bool,
    isMultiSelect: (j['is_multi_select'] ?? false) as bool,
    items: (j['items'] as List? ?? [])
        .map((i) => DrinkOptionItem.fromJson(i)).toList(),
  );
}

class MenuItem {
  final String                 id;
  final String                 orgId;
  final String?                categoryId;
  final String                 name;
  final String?                description;
  final String?                imageUrl;
  final int                    basePrice;
  final bool                   isActive;
  final int                    displayOrder;
  final List<ItemSize>         sizes;
  final List<DrinkOptionGroup> optionGroups;

  const MenuItem({
    required this.id, required this.orgId, this.categoryId,
    required this.name, this.description, this.imageUrl,
    required this.basePrice, required this.isActive, required this.displayOrder,
    required this.sizes, required this.optionGroups,
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
    sizes:        (j['sizes']         as List? ?? []).map((s) => ItemSize.fromJson(s)).toList(),
    optionGroups: (j['option_groups'] as List? ?? []).map((g) => DrinkOptionGroup.fromJson(g)).toList(),
  );
}
EOF

# =============================================================================
#  core/models/order.dart
# =============================================================================
cat > lib/core/models/order.dart << 'EOF'
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
EOF

# =============================================================================
#  core/models/inventory.dart
# =============================================================================
cat > lib/core/models/inventory.dart << 'EOF'
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
EOF

# =============================================================================
#  core/api/client.dart
# =============================================================================
cat > lib/core/api/client.dart << HEREDOC
import 'package:dio/dio.dart';

String? authToken;

final dio = _build();

Dio _build() {
  final d = Dio(BaseOptions(
    baseUrl:        '$BASE_URL',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers:        const {'Content-Type': 'application/json'},
  ));
  d.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (authToken != null) {
        options.headers['Authorization'] = 'Bearer \$authToken';
      }
      handler.next(options);
    },
  ));
  return d;
}
HEREDOC

# =============================================================================
#  core/api/auth_api.dart
# =============================================================================
cat > lib/core/api/auth_api.dart << 'EOF'
import 'client.dart';
import '../models/user.dart';

class AuthApi {
  Future<Map<String, dynamic>> loginWithPin({
    required String name,
    required String pin,
  }) async {
    final res = await dio.post('/auth/login', data: {'name': name, 'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  Future<User> me() async {
    final res = await dio.get('/auth/me');
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }
}

final authApi = AuthApi();
EOF

# =============================================================================
#  core/api/shift_api.dart
# =============================================================================
cat > lib/core/api/shift_api.dart << 'EOF'
import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> current(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await dio.post('/shifts/branches/$branchId/open',
        data: {'opening_cash': openingCash});
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Shift> close(
    String shiftId, {
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    final res = await dio.post('/shifts/$shiftId/close', data: {
      'closing_cash_declared': closingCash,
      'cash_note':             note,
      'inventory_counts':      inventoryCounts,
    });
    return Shift.fromJson(res.data as Map<String, dynamic>);
  }
}

final shiftApi = ShiftApi();
EOF

# =============================================================================
#  core/api/menu_api.dart
# =============================================================================
cat > lib/core/api/menu_api.dart << 'EOF'
import 'client.dart';
import '../models/menu.dart';

class MenuApi {
  Future<List<Category>> categories(String orgId) async {
    final res = await dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> items(String orgId) async {
    final res = await dio.get('/menu-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((m) => MenuItem.fromJson(m)).toList();
  }
}

final menuApi = MenuApi();
EOF

# =============================================================================
#  core/api/order_api.dart
# =============================================================================
cat > lib/core/api/order_api.dart << 'EOF'
import 'client.dart';
import '../models/order.dart';

class OrderApi {
  Future<Order> create({
    required String     branchId,
    required String     shiftId,
    required String     paymentMethod,
    required List<CartItem> items,
    String? customerName,
    String? discountType,
    int?    discountValue,
  }) async {
    final res = await dio.post('/orders', data: {
      'branch_id':      branchId,
      'shift_id':       shiftId,
      'payment_method': paymentMethod,
      'customer_name':  customerName,
      'discount_type':  discountType,
      'discount_value': discountValue,
      'items':          items.map((i) => i.toJson()).toList(),
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId  != null) params['shift_id']  = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> get(String id) async {
    final res = await dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> voidOrder(String id, String reason) async {
    await dio.post('/orders/$id/void', data: {'reason': reason});
  }
}

final orderApi = OrderApi();
EOF

# =============================================================================
#  core/api/inventory_api.dart
# =============================================================================
cat > lib/core/api/inventory_api.dart << 'EOF'
import 'client.dart';
import '../models/inventory.dart';

class InventoryApi {
  Future<List<InventoryItem>> items(String branchId) async {
    final res = await dio.get('/inventory/branches/$branchId/items');
    return (res.data as List).map((i) => InventoryItem.fromJson(i)).toList();
  }
}

final inventoryApi = InventoryApi();
EOF

# =============================================================================
#  core/providers/auth_provider.dart
# =============================================================================
cat > lib/core/providers/auth_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/auth_api.dart';
import '../api/client.dart';

class AuthProvider extends ChangeNotifier {
  User?   _user;
  bool    _loading = true;

  User?  get user    => _user;
  bool   get loading => _loading;
  bool   get isAuthenticated => authToken != null && _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('token');
    if (authToken != null) {
      try {
        _user = await authApi.me();
      } catch (_) {
        await _clear();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login({required String name, required String pin}) async {
    final data = await authApi.loginWithPin(name: name, pin: pin);
    authToken = data['token'] as String;
    _user     = User.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', authToken!);
    notifyListeners();
  }

  Future<void> logout() async {
    await _clear();
    notifyListeners();
  }

  Future<void> _clear() async {
    authToken = null;
    _user     = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
EOF

# =============================================================================
#  core/providers/shift_provider.dart
# =============================================================================
cat > lib/core/providers/shift_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../models/shift.dart';
import '../api/shift_api.dart';

class ShiftProvider extends ChangeNotifier {
  Shift?        _shift;
  ShiftPreFill? _preFill;
  bool          _loading = false;
  String?       _error;

  Shift?        get shift   => _shift;
  ShiftPreFill? get preFill => _preFill;
  bool          get loading => _loading;
  String?       get error   => _error;
  bool          get hasOpen => _shift?.isOpen ?? false;

  Future<void> load(String branchId) async {
    _set(true);
    try {
      _preFill = await shiftApi.current(branchId);
      _shift   = _preFill?.openShift;
      _error   = null;
    } catch (e) {
      _error = _friendly(e);
    }
    _set(false);
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    _set(true);
    try {
      _shift = await shiftApi.open(branchId, openingCash);
      _error = null;
      _set(false);
      return true;
    } catch (e) {
      _error = _friendly(e);
      _set(false);
      return false;
    }
  }

  Future<bool> closeShift({
    required int closingCash,
    String? note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (_shift == null) return false;
    _set(true);
    try {
      _shift = await shiftApi.close(
        _shift!.id,
        closingCash:     closingCash,
        note:            note,
        inventoryCounts: inventoryCounts,
      );
      _error = null;
      _set(false);
      return true;
    } catch (e) {
      _error = _friendly(e);
      _set(false);
      return false;
    }
  }

  void _set(bool v) { _loading = v; notifyListeners(); }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'Session expired — please sign in again';
    if (s.contains('409')) return 'A shift is already open for this branch';
    if (s.contains('404')) return 'Shift not found';
    return 'Something went wrong — please try again';
  }
}
EOF

# =============================================================================
#  core/providers/cart_provider.dart
# =============================================================================
cat > lib/core/providers/cart_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../models/order.dart';

enum DiscountType { percentage, fixed }

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String        _payment       = 'cash';
  String?       _customer;
  String?       _notes;
  DiscountType? _discountType;
  int?          _discountValue;

  List<CartItem> get items    => List.unmodifiable(_items);
  String         get payment  => _payment;
  String?        get customer => _customer;
  String?        get notes    => _notes;
  bool           get isEmpty  => _items.isEmpty;
  int            get count    => _items.fold(0, (s, i) => s + i.quantity);

  int get subtotal => _items.fold(0, (s, i) => s + i.lineTotal);

  int get discountAmount {
    if (_discountType == null || (_discountValue ?? 0) == 0) return 0;
    return _discountType == DiscountType.percentage
        ? (subtotal * _discountValue! / 100).round()
        : _discountValue!;
  }

  int get total => subtotal - discountAmount;

  String? get discountTypeStr => switch (_discountType) {
    DiscountType.percentage => 'percentage',
    DiscountType.fixed      => 'fixed',
    null                    => null,
  };
  int? get discountValue => _discountValue;

  void add(CartItem item) {
    // Merge identical items (same menuItemId + sizeLabel + same addons)
    final existing = _items.where((i) =>
        i.menuItemId == item.menuItemId &&
        i.sizeLabel  == item.sizeLabel  &&
        i.addons.length == item.addons.length).firstOrNull;
    if (existing != null) {
      existing.quantity += item.quantity;
      notifyListeners();
    } else {
      _items.add(item);
      notifyListeners();
    }
  }

  void removeAt(int i) { _items.removeAt(i); notifyListeners(); }

  void setQty(int i, int qty) {
    if (qty <= 0) { removeAt(i); } else { _items[i].quantity = qty; notifyListeners(); }
  }

  void setPayment(String m)   { _payment = m;  notifyListeners(); }
  void setCustomer(String? n) { _customer = n; notifyListeners(); }
  void setNotes(String? n)    { _notes = n;    notifyListeners(); }

  void setDiscount(DiscountType? t, int? v) {
    _discountType  = t;
    _discountValue = v;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _payment       = 'cash';
    _customer      = null;
    _notes         = null;
    _discountType  = null;
    _discountValue = null;
    notifyListeners();
  }
}
EOF

# =============================================================================
#  core/providers/menu_provider.dart
# =============================================================================
cat > lib/core/providers/menu_provider.dart << 'EOF'
import 'package:flutter/foundation.dart' hide Category;
import '../models/menu.dart';
import '../api/menu_api.dart';

class MenuProvider extends ChangeNotifier {
  List<Category> _cats    = [];
  List<MenuItem> _items   = [];
  String?        _selId;
  bool           _loading = false;
  String?        _error;
  String?        _loadedOrgId;

  List<Category> get categories => _cats;
  String?        get selectedId  => _selId;
  bool           get loading     => _loading;
  String?        get error       => _error;

  List<MenuItem> get filtered => _selId == null
      ? _items
      : _items.where((i) => i.categoryId == _selId).toList();

  Future<void> load(String orgId) async {
    if (_loadedOrgId == orgId && _items.isNotEmpty) return;
    _loading = true; notifyListeners();
    try {
      _cats         = await menuApi.categories(orgId);
      _items        = await menuApi.items(orgId);
      _selId        = _cats.isNotEmpty ? _cats.first.id : null;
      _error        = null;
      _loadedOrgId  = orgId;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  void refresh(String orgId) {
    _loadedOrgId = null;
    load(orgId);
  }

  void select(String id) { _selId = id; notifyListeners(); }
}
EOF

# =============================================================================
#  core/providers/order_history_provider.dart
# =============================================================================
cat > lib/core/providers/order_history_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../api/order_api.dart';

class OrderHistoryProvider extends ChangeNotifier {
  List<Order> _orders  = [];
  bool        _loading = false;
  String?     _error;
  String?     _shiftId;

  List<Order> get orders  => _orders;
  bool        get loading => _loading;
  String?     get error   => _error;

  Future<void> loadForShift(String shiftId) async {
    if (_shiftId == shiftId && _orders.isNotEmpty) return;
    _loading = true; _error = null; notifyListeners();
    try {
      _orders  = await orderApi.list(shiftId: shiftId);
      _shiftId = shiftId;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false; notifyListeners();
  }

  void refresh(String shiftId) {
    _shiftId = null;
    loadForShift(shiftId);
  }

  void addOrder(Order o) {
    _orders.insert(0, o);
    notifyListeners();
  }
}
EOF

# =============================================================================
#  core/router/router.dart
# =============================================================================
cat > lib/core/router/router.dart << 'EOF'
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/shift/open_shift_screen.dart';
import '../../features/shift/close_shift_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/order/order_history_screen.dart';
import '../providers/auth_provider.dart';

GoRouter buildRouter(AuthProvider auth) => GoRouter(
  initialLocation: '/login',
  refreshListenable: auth,
  redirect: (context, state) {
    final authed  = auth.isAuthenticated;
    final onLogin = state.matchedLocation == '/login';
    if (!authed && !onLogin) return '/login';
    if (authed  &&  onLogin) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login',         builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home',          builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/open-shift',    builder: (_, __) => const OpenShiftScreen()),
    GoRoute(path: '/close-shift',   builder: (_, __) => const CloseShiftScreen()),
    GoRoute(path: '/order',         builder: (_, __) => const OrderScreen()),
    GoRoute(path: '/order-history', builder: (_, __) => const OrderHistoryScreen()),
  ],
);
EOF

# =============================================================================
#  shared/widgets/app_button.dart
# =============================================================================
cat > lib/shared/widgets/app_button.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

enum BtnVariant { primary, danger, outline, ghost }

class AppButton extends StatelessWidget {
  final String       label;
  final VoidCallback? onTap;
  final bool         loading;
  final BtnVariant   variant;
  final double?      width;
  final IconData?    icon;
  final double       height;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.variant = BtnVariant.primary,
    this.width,
    this.icon,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (variant) {
      BtnVariant.primary => (AppColors.primary,          Colors.white,           Colors.transparent),
      BtnVariant.danger  => (AppColors.danger,           Colors.white,           Colors.transparent),
      BtnVariant.outline => (Colors.transparent,         AppColors.primary,      AppColors.primary),
      BtnVariant.ghost   => (Colors.transparent,         AppColors.textSecondary, Colors.transparent),
    };

    return SizedBox(
      width: width, height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: side),
        ),
        child: InkWell(
          onTap: (loading || onTap == null) ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: fg),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 17, color: fg),
                      const SizedBox(width: 7),
                    ],
                    Text(label, style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: fg,
                    )),
                  ]),
          ),
        ),
      ),
    );
  }
}
EOF

# =============================================================================
#  shared/widgets/card_container.dart
# =============================================================================
cat > lib/shared/widgets/card_container.dart << 'EOF'
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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}
EOF

# =============================================================================
#  shared/widgets/label_value.dart
# =============================================================================
cat > lib/shared/widgets/label_value.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool   bold;

  const LabelValue(this.label, this.value,
      {super.key, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textSecondary,
        )),
        Text(value, style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: valueColor ?? AppColors.textPrimary,
        )),
      ],
    ),
  );
}
EOF

# =============================================================================
#  shared/widgets/pin_pad.dart
# =============================================================================
cat > lib/shared/widgets/pin_pad.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final String              pin;
  final int                 maxLength;
  final void Function(String) onDigit;
  final VoidCallback        onBackspace;

  const PinPad({
    super.key,
    required this.pin,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
  });

  static const _rows = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['', '0','⌫'],
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(maxLength, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < pin.length ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: i < pin.length ? AppColors.primary : AppColors.border,
              width: 2,
            ),
          ),
        )),
      ),
      const SizedBox(height: 28),
      ..._rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 72, height: 68);
            return _Key(label: k,
                onTap: () => k == '⌫' ? onBackspace() : onDigit(k));
          }).toList(),
        ),
      )),
    ],
  );
}

class _Key extends StatelessWidget {
  final String      label;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 68, height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4, offset: const Offset(0, 2),
        )],
      ),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.inter(
        fontSize: label == '⌫' ? 18 : 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      )),
    ),
  );
}
EOF

# =============================================================================
#  shared/widgets/error_banner.dart
# =============================================================================
cat > lib/shared/widgets/error_banner.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {
  final String    message;
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
      Expanded(child: Text(message, style: GoogleFonts.inter(
        fontSize: 13, color: AppColors.danger,
      ))),
      if (onRetry != null)
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary,
          )),
        ),
    ]),
  );
}
EOF

# =============================================================================
#  features/auth/login_screen.dart
# =============================================================================
cat > lib/features/auth/login_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pin_pad.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  String  _pin     = '';
  bool    _loading = false;
  String? _error;
  static const _max = 6;

  void _digit(String d) {
    if (_loading || _pin.length >= _max) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length == _max) _submit();
  }

  void _back() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() { _error = 'Please enter your name'; _pin = ''; });
      return;
    }
    if (_pin.length < 4) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AuthProvider>().login(name: name, pin: _pin);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() {
        _error   = 'Invalid name or PIN — please try again';
        _pin     = '';
        _loading = false;
      });
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Logo
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text('R', style: GoogleFonts.inter(
                fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white,
              )),
            ),
            const SizedBox(height: 18),
            Text('Rue POS', style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
            )),
            const SizedBox(height: 6),
            Text('Sign in to start your shift', style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textSecondary,
            )),
            const SizedBox(height: 32),

            // Name field
            TextField(
              controller: _nameCtrl,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    color: AppColors.textMuted),
              ),
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 30),

            // PIN pad
            PinPad(
                pin: _pin, maxLength: _max,
                onDigit: _digit, onBackspace: _back),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_error!, style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.danger,
                  ))),
                ]),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ],
          ]),
        ),
      ),
    ),
  );
}
EOF

# =============================================================================
#  features/home/home_screen.dart
# =============================================================================
cat > lib/features/home/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/label_value.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = context.read<AuthProvider>().user?.branchId;
    if (branchId == null) return;
    await context.read<ShiftProvider>().load(branchId);
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().user!;
    final shift = context.watch<ShiftProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(children: [
                _Avatar(name: user.name),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greet(user.name.split(' ').first),
                        style: GoogleFonts.inter(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text(user.role.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.textMuted, letterSpacing: 1)),
                  ],
                )),
                AppButton(
                  label: 'Sign Out',
                  variant: BtnVariant.outline,
                  icon: Icons.logout_rounded,
                  onTap: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ]),
              const SizedBox(height: 28),

              // ── Shift area ───────────────────────────────────
              if (shift.loading)
                const Center(child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ))
              else if (shift.error != null)
                ErrorBanner(message: shift.error!, onRetry: _load)
              else if (shift.hasOpen)
                _OpenCard(shift: shift.shift!)
              else
                _NoShiftCard(
                    suggested: shift.preFill?.suggestedOpeningCash ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  String _greet(String first) {
    final h = DateTime.now().hour;
    return 'Good ${h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening"}, $first';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Text(name[0].toUpperCase(), style: GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
    )),
  );
}

class _OpenCard extends StatelessWidget {
  final dynamic shift;
  const _OpenCard({required this.shift});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _Badge('● SHIFT OPEN'),
        const Spacer(),
        _Badge(egp(shift.openingCash)),
      ]),
      const SizedBox(height: 6),
      Text(dateTime(shift.openedAt), style: GoogleFonts.inter(
        fontSize: 12, color: Colors.white60,
      )),
      const SizedBox(height: 20),
      // Action buttons — 2x2 grid for clarity
      Row(children: [
        Expanded(child: _ShiftBtn(
          label: 'New Order', icon: Icons.add_shopping_cart_rounded,
          onTap: () => context.go('/order'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _ShiftBtn(
          label: 'Order History', icon: Icons.receipt_long_rounded,
          onTap: () => context.go('/order-history'),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _ShiftBtn(
          label: 'Close Shift', icon: Icons.lock_outline_rounded,
          onTap: () => context.go('/close-shift'), danger: true,
        )),
      ]),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: Colors.white, letterSpacing: 0.3,
    )),
  );
}

class _ShiftBtn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap; final bool danger;
  const _ShiftBtn({required this.label, required this.icon,
      required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: danger ? Colors.white.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16,
            color: danger ? Colors.white : AppColors.primary),
        const SizedBox(width: 7),
        Text(label, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: danger ? Colors.white : AppColors.primary,
        )),
      ]),
    ),
  );
}

class _NoShiftCard extends StatelessWidget {
  final int suggested;
  const _NoShiftCard({required this.suggested});

  @override
  Widget build(BuildContext context) => CardContainer(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.wb_sunny_outlined,
              color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No Open Shift', style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          )),
          if (suggested > 0)
            Text('Last closing: ${egp(suggested)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ]),
      const SizedBox(height: 20),
      AppButton(
        label: 'Open Shift', width: double.infinity,
        icon: Icons.play_arrow_rounded,
        onTap: () => context.go('/open-shift'),
      ),
    ]),
  );
}
EOF

# =============================================================================
#  features/shift/open_shift_screen.dart
# =============================================================================
cat > lib/features/shift/open_shift_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';

class OpenShiftScreen extends StatefulWidget {
  const OpenShiftScreen({super.key});
  @override State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _ctrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<ShiftProvider>().preFill?.suggestedOpeningCash ?? 0;
      if (s > 0) _ctrl.text = (s / 100).toStringAsFixed(0);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _open() async {
    final raw = double.tryParse(_ctrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid cash amount');
      return;
    }
    final branchId = context.read<AuthProvider>().user?.branchId;
    if (branchId == null) {
      setState(() => _error = 'No branch assigned to your account');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await context.read<ShiftProvider>()
        .openShift(branchId, (raw * 100).round());
    if (mounted) {
      if (ok) {
        context.go('/home');
      } else {
        setState(() {
          _error   = context.read<ShiftProvider>().error ?? 'Failed to open shift';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go('/home'),
      ),
      title: const Text('Open Shift'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CardContainer(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Opening Cash', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary, letterSpacing: 0.4,
                )),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: GoogleFonts.inter(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'EGP ',
                    prefixStyle: GoogleFonts.inter(
                        fontSize: 20, color: AppColors.textSecondary),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Open Shift',
                  loading: _loading,
                  width: double.infinity,
                  icon: Icons.play_arrow_rounded,
                  onTap: _open,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
EOF

# =============================================================================
#  features/shift/close_shift_screen.dart
# =============================================================================
cat > lib/features/shift/close_shift_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api/inventory_api.dart';
import '../../core/models/inventory.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/label_value.dart';

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});
  @override State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<InventoryItem>                      _inv  = [];
  final Map<String, TextEditingController> _ctrs = {};
  bool    _loadingInv = true;
  bool    _submitting = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadInv(); }

  @override
  void dispose() {
    _cashCtrl.dispose(); _noteCtrl.dispose();
    for (final c in _ctrs.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadInv() async {
    final branchId = context.read<ShiftProvider>().shift?.branchId;
    if (branchId == null) { setState(() => _loadingInv = false); return; }
    try {
      final items = await inventoryApi.items(branchId);
      if (!mounted) return;
      setState(() {
        _inv        = items;
        _loadingInv = false;
        for (final i in items) {
          _ctrs[i.id] = TextEditingController(
              text: i.currentStock.toStringAsFixed(2));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingInv = false);
    }
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }
    setState(() { _submitting = true; _error = null; });

    final counts = _ctrs.entries.map((e) => {
      'inventory_item_id': e.key,
      'actual_stock': double.tryParse(e.value.text) ?? 0.0,
    }).toList();

    final ok = await context.read<ShiftProvider>().closeShift(
      closingCash:     (raw * 100).round(),
      note:            _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      inventoryCounts: counts,
    );

    if (mounted) {
      if (ok) {
        context.go('/home');
      } else {
        setState(() {
          _error      = context.read<ShiftProvider>().error
              ?? 'Failed to close shift';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>().shift;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Close Shift'),
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Summary
                      CardContainer(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shift Summary', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                          const SizedBox(height: 12),
                          LabelValue('Teller',       shift.tellerName),
                          LabelValue('Opening Cash', egp(shift.openingCash)),
                          LabelValue('Opened At',    dateTime(shift.openedAt)),
                        ],
                      )),
                      const SizedBox(height: 16),

                      // Cash
                      CardContainer(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Closing Cash', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'))],
                            style: GoogleFonts.inter(
                              fontSize: 24, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              prefixText: 'EGP ',
                              prefixStyle: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                                hintText: 'Cash note (optional)'),
                          ),
                        ],
                      )),
                      const SizedBox(height: 16),

                      // Inventory
                      CardContainer(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Inventory Count', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                          const SizedBox(height: 14),
                          if (_loadingInv)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ))
                          else if (_inv.isEmpty)
                            Text('No inventory items', style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textMuted))
                          else
                            ..._inv.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    )),
                                    Text(
                                      'System: ${item.currentStock} ${item.unit}',
                                      style: GoogleFonts.inter(fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                )),
                                const SizedBox(width: 12),
                                SizedBox(width: 130, child: TextField(
                                  controller: _ctrs[item.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    suffixText: item.unit,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                  ),
                                )),
                              ]),
                            )),
                        ],
                      )),
                      const SizedBox(height: 16),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!, style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.danger)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      AppButton(
                        label: 'Close Shift',
                        variant: BtnVariant.danger,
                        loading: _submitting,
                        width: double.infinity,
                        icon: Icons.lock_outline_rounded,
                        onTap: _close,
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
EOF

# =============================================================================
#  features/order/order_history_screen.dart
# =============================================================================
cat > lib/features/order/order_history_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/order.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final shiftId = context.read<ShiftProvider>().shift?.id;
    if (shiftId == null) return;
    await context.read<OrderHistoryProvider>().loadForShift(shiftId);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<OrderHistoryProvider>();
    final shift   = context.watch<ShiftProvider>().shift;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Order History'),
        actions: [
          if (shift != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => context.read<OrderHistoryProvider>()
                  .refresh(shift.id),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : history.loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary))
              : history.error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorBanner(
                          message: history.error!, onRetry: _load))
                  : history.orders.isEmpty
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                size: 48, color: AppColors.border),
                            const SizedBox(height: 12),
                            Text('No orders yet for this shift',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: AppColors.textSecondary)),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: history.orders.length,
                          itemBuilder: (_, i) =>
                              _OrderTile(order: history.orders[i]),
                        ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final isVoided = order.status == 'voided';

    return GestureDetector(
      onTap: () => _OrderDetailSheet.show(context, order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isVoided
              ? AppColors.borderLight
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isVoided
                ? AppColors.border
                : AppColors.border,
          ),
          boxShadow: isVoided ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          // Order number badge
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isVoided
                  ? AppColors.border
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('#${order.orderNumber}',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isVoided
                      ? AppColors.textMuted
                      : AppColors.primary,
                )),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  order.items.map((i) => i.itemName).take(2).join(', ') +
                      (order.items.length > 2
                          ? ' +${order.items.length - 2} more'
                          : ''),
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isVoided
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    decoration: isVoided
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                _Tag(label: order.paymentMethod, voided: isVoided),
                const SizedBox(width: 6),
                if (isVoided) _Tag(label: 'VOIDED', voided: true, danger: true),
                const Spacer(),
                Text(timeShort(order.createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
            ],
          )),
          const SizedBox(width: 12),
          // Total
          Text(
            egp(order.totalAmount),
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isVoided
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              decoration: isVoided ? TextDecoration.lineThrough : null,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool   voided;
  final bool   danger;
  const _Tag({required this.label, this.voided = false, this.danger = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: danger
          ? AppColors.danger.withOpacity(0.1)
          : voided
              ? AppColors.borderLight
              : AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label[0].toUpperCase() + label.substring(1),
      style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600,
        color: danger
            ? AppColors.danger
            : voided
                ? AppColors.textMuted
                : AppColors.primary,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ── Order detail sheet ───────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});

  static void show(BuildContext ctx, Order order) =>
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderDetailSheet(order: order),
      );

  @override
  Widget build(BuildContext context) {
    final isVoided = order.status == 'voided';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          )),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${order.orderNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              Text(dateTime(order.createdAt),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            if (isVoided)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('VOIDED', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.danger, letterSpacing: 0.5,
                )),
              ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        // Items list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Items
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('${item.quantity}',
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName +
                              (item.sizeLabel != null
                                  ? ' (${item.sizeLabel})' : ''),
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.addons.isNotEmpty)
                          Text(
                            item.addons.map((a) => a.addonName).join(', '),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                      ],
                    )),
                    Text(egp(item.lineTotal),
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
              )),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              // Totals
              _Row('Subtotal', egp(order.subtotal)),
              if (order.discountAmount > 0)
                _Row('Discount', '- ${egp(order.discountAmount)}',
                    color: AppColors.success),
              if (order.taxAmount > 0)
                _Row('Tax', egp(order.taxAmount)),
              const SizedBox(height: 4),
              _Row('Total', egp(order.totalAmount), bold: true),
              const SizedBox(height: 12),
              _Row('Payment',
                order.paymentMethod[0].toUpperCase() +
                    order.paymentMethod.substring(1)),
              if (order.customerName != null)
                _Row('Customer', order.customerName!),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool   bold;
  const _Row(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: color ?? AppColors.textPrimary,
        )),
      ],
    ),
  );
}
EOF

# =============================================================================
#  features/order/order_screen.dart
# =============================================================================
cat > lib/features/order/order_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api/order_api.dart';
import '../../core/models/menu.dart';
import '../../core/models/order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/menu_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/label_value.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});
  @override State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = context.read<AuthProvider>().user?.orgId;
      if (orgId != null) context.read<MenuProvider>().load(orgId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _AppBar(),
          Expanded(
            child: Row(children: [
              // ── Menu ─────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(children: [
                  _CategoryBar(
                    cats:  menu.categories,
                    selId: menu.selectedId,
                    onTap: menu.select,
                  ),
                  Expanded(
                    child: menu.loading
                        ? const Center(child: CircularProgressIndicator(
                            color: AppColors.primary))
                        : menu.error != null
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: ErrorBanner(
                                  message: menu.error!,
                                  onRetry: () {
                                    final orgId = context
                                        .read<AuthProvider>().user?.orgId;
                                    if (orgId != null)
                                      context.read<MenuProvider>().refresh(orgId);
                                  },
                                ))
                            : _Grid(items: menu.filtered),
                  ),
                ]),
              ),
              // ── Cart ─────────────────────────────────────────
              SizedBox(width: 300, child: _Cart()),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        Text('New Order', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        )),
        const Spacer(),
        if (!cart.isEmpty)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${cart.count} item${cart.count != 1 ? "s" : ""}',
              style: GoogleFonts.inter(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
      ]),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final List<Category> cats;
  final String?        selId;
  final void Function(String) onTap;
  const _CategoryBar({required this.cats, required this.selId, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    color: AppColors.surface,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final c   = cats[i];
        final sel = c.id == selId;
        return GestureDetector(
          onTap: () => onTap(c.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : AppColors.borderLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(c.name, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: sel ? Colors.white : AppColors.textSecondary,
            )),
          ),
        );
      },
    ),
  );
}

class _Grid extends StatelessWidget {
  final List<MenuItem> items;
  const _Grid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(
      child: Text('No items in this category',
          style: GoogleFonts.inter(color: AppColors.textMuted)),
    );
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 175,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(item: items[i]),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => ItemSheet.show(context, item),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.borderLight,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
            ),
            alignment: Alignment.center,
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14)),
                    child: Image.network(item.imageUrl!,
                        fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.coffee_rounded,
                            size: 34, color: AppColors.textMuted)))
                : const Icon(Icons.coffee_rounded,
                    size: 34, color: AppColors.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(egp(item.basePrice), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary,
            )),
          ]),
        ),
      ]),
    ),
  );
}

// ── Item detail sheet ────────────────────────────────────────
class ItemSheet extends StatefulWidget {
  final MenuItem item;
  const ItemSheet({super.key, required this.item});

  static void show(BuildContext ctx, MenuItem item) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ItemSheet(item: item),
  );

  @override State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  String?               _size;
  final Map<String,String> _opts = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) _size = widget.item.sizes.first.label;
  }

  int get _unit  => widget.item.priceForSize(_size);
  int get _addP  => _opts.entries.fold(0, (s, e) {
    for (final g in widget.item.optionGroups) {
      if (g.id == e.key) {
        for (final o in g.items) if (o.id == e.value) return s + o.priceModifier;
      }
    }
    return s;
  });
  int get _total => (_unit + _addP) * _qty;

  void _add() {
    final addons = <SelectedAddon>[];
    for (final g in widget.item.optionGroups) {
      final id = _opts[g.id]; if (id == null) continue;
      for (final o in g.items) if (o.id == id) addons.add(SelectedAddon(
        addonItemId:       o.id,
        drinkOptionItemId: o.id,
        name:              o.name,
        priceModifier:     o.priceModifier,
      ));
    }
    context.read<CartProvider>().add(CartItem(
      menuItemId: widget.item.id, itemName: widget.item.name,
      sizeLabel: _size, unitPrice: _unit, quantity: _qty, addons: addons,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
    child: SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.border,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(widget.item.name, style: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        )),
        if (widget.item.description != null) ...[
          const SizedBox(height: 6),
          Text(widget.item.description!, style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 20),

        if (widget.item.sizes.isNotEmpty) ...[
          _SLabel('Size'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: widget.item.sizes.map((s) => _Chip(
              label: '${s.label}  ${egp(s.price)}',
              sel: s.label == _size,
              onTap: () => setState(() => _size = s.label),
            )).toList()),
          const SizedBox(height: 18),
        ],

        for (final g in widget.item.optionGroups) ...[
          _SLabel('${g.name}${g.isRequired ? " *" : ""}'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: g.items.map((o) => _Chip(
              label: o.priceModifier > 0
                  ? '${o.name}  +${egp(o.priceModifier)}' : o.name,
              sel: _opts[g.id] == o.id,
              onTap: () => setState(() =>
                  _opts[g.id] == o.id ? _opts.remove(g.id) : _opts[g.id] = o.id),
            )).toList()),
          const SizedBox(height: 18),
        ],

        Row(children: [
          _SLabel('Quantity'),
          const Spacer(),
          _QtyCtrl(qty: _qty,
            onMinus: () => setState(() => _qty = (_qty - 1).clamp(1, 99)),
            onPlus:  () => setState(() => _qty = (_qty + 1).clamp(1, 99)),
          ),
        ]),
        const SizedBox(height: 24),

        AppButton(label: 'Add to Order — ${egp(_total)}',
            width: double.infinity, onTap: _add),
      ],
    )),
  );
}

class _SLabel extends StatelessWidget {
  final String t;
  const _SLabel(this.t);
  @override Widget build(BuildContext context) => Text(t,
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.6));
}

class _Chip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _Chip({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: sel ? AppColors.primary : AppColors.borderLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: sel ? Colors.white : AppColors.textSecondary,
      )),
    ),
  );
}

class _QtyCtrl extends StatelessWidget {
  final int qty; final VoidCallback onMinus, onPlus;
  const _QtyCtrl({required this.qty, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) => Row(children: [
    _QB(icon: Icons.remove, onTap: onMinus),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('$qty', style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary))),
    _QB(icon: Icons.add, onTap: onPlus),
  ]);
}

class _QB extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _QB({required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34,
      decoration: BoxDecoration(color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(9)),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: AppColors.textPrimary)),
  );
}

// ── Cart panel ───────────────────────────────────────────────
class _Cart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Text('Order', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: cart.clear,
                child: Text('Clear all', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                )),
              ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Items
        Expanded(
          child: cart.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        size: 38, color: AppColors.border),
                    const SizedBox(height: 8),
                    Text('Cart is empty', style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textMuted)),
                  ],
                ))
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CartRow(index: i),
                ),
        ),

        // Footer
        if (!cart.isEmpty) ...[
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              LabelValue('Subtotal', egp(cart.subtotal)),
              if (cart.discountAmount > 0)
                LabelValue('Discount', '- ${egp(cart.discountAmount)}',
                    valueColor: AppColors.success),
              const Divider(height: 14, color: AppColors.border),
              LabelValue('Total', egp(cart.total), bold: true),
              const SizedBox(height: 12),
              AppButton(
                label: 'Checkout',
                width: double.infinity,
                icon: Icons.arrow_forward_rounded,
                onTap: () => CheckoutSheet.show(context),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _CartRow extends StatelessWidget {
  final int index;
  const _CartRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items[index];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg, borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            item.itemName +
                (item.sizeLabel != null ? ' (${item.sizeLabel})' : ''),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          )),
          Text(egp(item.lineTotal), style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
        ]),
        if (item.addons.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(item.addons.map((a) => a.name).join(', '),
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 7),
        Row(children: [
          _QtyBtn(icon: Icons.remove,
              onTap: () => cart.setQty(index, item.quantity - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Text('${item.quantity}', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
          ),
          _QtyBtn(icon: Icons.add,
              onTap: () => cart.setQty(index, item.quantity + 1)),
          const Spacer(),
          GestureDetector(
            onTap: () => cart.removeAt(index),
            child: const Icon(Icons.delete_outline_rounded,
                size: 17, color: AppColors.textMuted),
          ),
        ]),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 25, height: 25,
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border)),
      alignment: Alignment.center,
      child: Icon(icon, size: 13, color: AppColors.textPrimary)),
  );
}

// ── Checkout sheet ───────────────────────────────────────────
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  static void show(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CheckoutSheet(),
  );

  @override State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool    _loading = false;
  String? _error;
  static const _methods = ['cash', 'card', 'instapay'];

  Future<void> _place() async {
    final cart  = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) {
      setState(() => _error = 'No open shift');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final order = await orderApi.create(
        branchId:      shift.branchId,
        shiftId:       shift.id,
        paymentMethod: cart.payment,
        items:         cart.items.toList(),
        customerName:  cart.customer,
        discountType:  cart.discountTypeStr,
        discountValue: cart.discountValue,
      );
      // Add to history cache
      context.read<OrderHistoryProvider>().addOrder(order);
      final total = cart.total;
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context, order: order, total: total);
      }
    } catch (e) {
      setState(() {
        _error   = 'Failed to place order — please retry';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text('Checkout', style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          )),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg,
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              LabelValue('Subtotal', egp(cart.subtotal)),
              if (cart.discountAmount > 0)
                LabelValue('Discount', '- ${egp(cart.discountAmount)}',
                    valueColor: AppColors.success),
              const Divider(height: 14),
              LabelValue('Total', egp(cart.total), bold: true),
            ]),
          ),
          const SizedBox(height: 18),

          // Payment
          Text('Payment', style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 0.6,
          )),
          const SizedBox(height: 10),
          Row(children: _methods.map((m) {
            final sel = cart.payment == m;
            return GestureDetector(
              onTap: () => cart.setPayment(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(m[0].toUpperCase() + m.substring(1),
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textSecondary,
                    )),
              ),
            );
          }).toList()),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.danger)),
          ],
          const SizedBox(height: 20),

          AppButton(
            label: 'Place Order',
            loading: _loading,
            width: double.infinity,
            icon: Icons.check_rounded,
            onTap: _place,
          ),
        ],
      ),
    );
  }
}

// ── Receipt sheet ────────────────────────────────────────────
class ReceiptSheet extends StatelessWidget {
  final Order order;
  final int   total;
  const ReceiptSheet({super.key, required this.order, required this.total});

  static void show(BuildContext ctx,
      {required Order order, required int total}) =>
      showModalBottomSheet(
        context: ctx, backgroundColor: Colors.transparent,
        builder: (_) => ReceiptSheet(order: order, total: total),
      );

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.border,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            color: AppColors.success, size: 28),
      ),
      const SizedBox(height: 12),
      Text('Order Placed!', style: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      )),
      const SizedBox(height: 4),
      Text('Order #${order.orderNumber}', style: GoogleFonts.inter(
        fontSize: 14, color: AppColors.textSecondary,
      )),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.bg,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          LabelValue('Payment',
              order.paymentMethod[0].toUpperCase() +
                  order.paymentMethod.substring(1)),
          LabelValue('Total', egp(order.totalAmount), bold: true),
          LabelValue('Time',  timeShort(order.createdAt)),
        ]),
      ),
      const SizedBox(height: 20),
      AppButton(
        label: 'New Order', width: double.infinity,
        icon: Icons.add_rounded,
        onTap: () => Navigator.pop(context),
      ),
    ]),
  );
}
EOF

# =============================================================================
#  main.dart
# =============================================================================
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/menu_provider.dart';
import 'core/providers/order_history_provider.dart';
import 'core/providers/shift_provider.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
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
        ChangeNotifierProvider(create: (_) => OrderHistoryProvider()),
      ],
      child: Builder(builder: (ctx) {
        final auth = ctx.watch<AuthProvider>();

        if (auth.loading) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(child: CircularProgressIndicator(
                  color: AppColors.primary)),
            ),
          );
        }

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Rue POS',
          theme: AppTheme.light,
          routerConfig: buildRouter(auth),
        );
      }),
    );
  }
}
EOF

# =============================================================================
#  Android internet permission
# =============================================================================
MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q "INTERNET" "$MANIFEST"; then
  sed -i.bak \
    's/<application/<uses-permission android:name="android.permission.INTERNET"\/>\n    <application/' \
    "$MANIFEST"
fi

# =============================================================================
#  Done
# =============================================================================
echo ""
echo "✅  RuePOS complete — $(find lib -name '*.dart' | wc -l | tr -d ' ') Dart files"
echo ""
echo "  cd $PROJECT && flutter pub get && flutter run"
echo ""
echo "Backend requirements:"
echo "  POST /auth/login   →  { name, pin }  — no branch_id needed"
echo "  GET  /auth/me      →  user.branch_id populated from user_branch_assignments"
echo "  GET  /orders?shift_id=  →  returns items[] and items[].addons[] embedded"