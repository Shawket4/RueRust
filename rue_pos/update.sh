#!/usr/bin/env bash
# =============================================================================
#  Rue POS — Full Audit Patch
#  Run from the root of your Flutter project:  bash rue_pos_patch.sh
# =============================================================================
set -e
ROOT="$(pwd)"
echo "🔧  Patching Rue POS from: $ROOT"

# ─────────────────────────────────────────────────────────────────────────────
# HELPER
# ─────────────────────────────────────────────────────────────────────────────
write() {
  local path="$ROOT/$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  echo "  ✅  $1"
}

# =============================================================================
# 1.  lib/core/utils/formatting.dart
#     + normaliseName utility (was scattered at file-scope in order_screen)
# =============================================================================
write lib/core/utils/formatting.dart << 'DART'
import 'package:intl/intl.dart';

/// Piastres → "EGP 12.50" or "EGP 12"
String egp(int piastres) {
  final v = piastres / 100;
  return 'EGP ${v == v.truncateToDouble() ? v.toInt() : v.toStringAsFixed(2)}';
}

String egpD(double p) => egp(p.round());
String timeShort(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());
String dateShort(DateTime dt) => DateFormat('MMM d').format(dt.toLocal());
String dateTime(DateTime dt)  => DateFormat('MMM d, hh:mm a').format(dt.toLocal());

/// Title-cases each word.  "oat MILK" → "Oat Milk"
String normaliseName(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');
DART

# =============================================================================
# 2.  lib/core/models/pending_order.dart
#     Fix: toJson MUST persist item_name, unit_price, addon name + price_modifier
#          so that offline orders can be displayed and are not blank after restore.
#     Fix: add retry_count field to allow skipping permanently-broken orders.
# =============================================================================
write lib/core/models/pending_order.dart << 'DART'
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
DART

# =============================================================================
# 3.  lib/core/api/client.dart
#     Fix: 401 auto-logout interceptor, sendTimeout, error interceptor,
#          SharedPreferences singleton helper.
# =============================================================================
write lib/core/api/client.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Token storage
// ---------------------------------------------------------------------------
String? authToken;

/// Callback set by AuthProvider so the HTTP layer can trigger re-login on 401.
void Function()? onUnauthorized;

// ---------------------------------------------------------------------------
// SharedPreferences singleton — avoids repeated getInstance() calls
// ---------------------------------------------------------------------------
SharedPreferences? _prefs;
Future<SharedPreferences> get prefs async =>
    _prefs ??= await SharedPreferences.getInstance();

// ---------------------------------------------------------------------------
// Dio singleton
// ---------------------------------------------------------------------------
final dio = _build();

Dio _build() {
  final d = Dio(BaseOptions(
    baseUrl:        'https://rue-pos.ddns.net/api',
    connectTimeout: const Duration(seconds: 10),
    sendTimeout:    const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: const {'Content-Type': 'application/json'},
  ));

  // ── Request: attach Bearer token ─────────────────────────────────────────
  d.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (authToken != null) {
        options.headers['Authorization'] = 'Bearer $authToken';
      }
      handler.next(options);
    },

    // ── Response: surface API-level errors cleanly ────────────────────────
    onResponse: (response, handler) {
      // Some backends return 200 with {"error": "..."} — surface as exception
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

    // ── Error: trigger logout on 401 ─────────────────────────────────────
    onError: (err, handler) {
      if (err.response?.statusCode == 401) {
        onUnauthorized?.call();
      }
      handler.next(err);
    },
  ));

  return d;
}

/// Human-readable network error message.
String friendlyError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Session expired — please sign in again';
    if (code == 403) return 'You do not have permission to do that';
    if (code == 404) return 'Not found';
    if (code == 409) return 'Conflict — resource already exists';
    if (code == 422) return 'Invalid data submitted';
    if (code != null && code >= 500) return 'Server error — please try again';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout    ||
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
DART

# =============================================================================
# 4.  lib/core/providers/branch_provider.dart
#     Fix: cache branch to SharedPreferences; load from cache when offline.
# =============================================================================
write lib/core/providers/branch_provider.dart << 'DART'
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../api/branch_api.dart';
import '../api/client.dart' show prefs;

class BranchProvider extends ChangeNotifier {
  Branch? _branch;
  bool    _loading = false;
  String? _error;

  Branch? get branch      => _branch;
  bool    get loading     => _loading;
  String? get error       => _error;
  bool    get hasPrinter  => _branch?.hasPrinter ?? false;
  String? get printerIp   => _branch?.printerIp;
  int     get printerPort => _branch?.printerPort ?? 9100;
  String  get branchName  => _branch?.name ?? '';

  Future<void> load(String branchId) async {
    if (_branch?.id == branchId) return;
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _branch = await branchApi.get(branchId);
      await _save(_branch!);
    } catch (e) {
      // Try cache
      final cached = await _load(branchId);
      if (cached != null) {
        _branch = cached;
        _error  = null;
      } else {
        _error = e.toString();
      }
    }
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _branch  = null;
    _error   = null;
    _loading = false;
    notifyListeners();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _save(Branch b) async {
    try {
      final p = await prefs;
      await p.setString('branch_${b.id}', jsonEncode({
        'id':           b.id,
        'org_id':       b.orgId,
        'name':         b.name,
        'address':      b.address,
        'phone':        b.phone,
        'printer_ip':   b.printerIp,
        'printer_port': b.printerPort,
        'is_active':    b.isActive,
      }));
    } catch (_) {}
  }

  Future<Branch?> _load(String branchId) async {
    try {
      final p   = await prefs;
      final raw = p.getString('branch_$branchId');
      if (raw == null) return null;
      return Branch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) { return null; }
  }
}
DART

# =============================================================================
# 5.  lib/core/providers/auth_provider.dart
#     Fix: distinguish 401 (real logout) vs network error (stay logged in).
#          Set onUnauthorized callback on client so 401 anywhere triggers logout.
# =============================================================================
write lib/core/providers/auth_provider.dart << 'DART'
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/auth_api.dart';
import '../api/client.dart';
import 'branch_provider.dart';

class AuthProvider extends ChangeNotifier {
  final BranchProvider branchProvider;
  AuthProvider(this.branchProvider) {
    // Wire 401 → auto-logout so any API call can trigger it.
    onUnauthorized = () {
      if (_user != null) {
        _clear().then((_) => notifyListeners());
      }
    };
  }

  User?  _user;
  bool   _loading = true;

  User?  get user            => _user;
  bool   get loading         => _loading;
  bool   get isAuthenticated => authToken != null && _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('token');

    if (authToken != null) {
      try {
        _user = await authApi.me();
        await _loadBranch();
      } on DioException catch (e) {
        // 401 → token invalid, must re-login
        if (e.response?.statusCode == 401) {
          await _clear();
        }
        // Any other network error → stay logged in with cached user
        else {
          _user = _loadCachedUser(prefs);
          if (_user != null) await _loadBranch();
          else await _clear();
        }
      } catch (_) {
        // Non-network error — try cached user
        _user = _loadCachedUser(prefs);
        if (_user != null) await _loadBranch();
        else await _clear();
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
    await _saveUser(prefs, _user!);
    await _loadBranch();
    notifyListeners();
  }

  Future<void> logout() async {
    branchProvider.clear();
    await _clear();
    notifyListeners();
  }

  Future<void> _loadBranch() async {
    final branchId = _user?.branchId;
    if (branchId != null) await branchProvider.load(branchId);
  }

  Future<void> _clear() async {
    authToken = null;
    _user     = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('cached_user');
  }

  // ── Cached user (for offline startup) ─────────────────────────────────────
  Future<void> _saveUser(SharedPreferences p, User u) async {
    try {
      await p.setString('cached_user', '${u.id}|${u.orgId ?? ''}|${u.branchId ?? ''}|${u.name}|${u.email ?? ''}|${u.role}|${u.isActive}');
    } catch (_) {}
  }

  User? _loadCachedUser(SharedPreferences p) {
    try {
      final raw = p.getString('cached_user');
      if (raw == null) return null;
      final parts = raw.split('|');
      if (parts.length < 7) return null;
      return User(
        id:       parts[0],
        orgId:    parts[1].isEmpty ? null : parts[1],
        branchId: parts[2].isEmpty ? null : parts[2],
        name:     parts[3],
        email:    parts[4].isEmpty ? null : parts[4],
        role:     parts[5],
        isActive: parts[6] == 'true',
      );
    } catch (_) { return null; }
  }
}
DART

# =============================================================================
# 6.  lib/core/providers/cart_provider.dart
#     Fix: addon equality check — compare actual addon IDs, not just count.
# =============================================================================
write lib/core/providers/cart_provider.dart << 'DART'
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
    // Merge only if same item + size + identical addon set (by drinkOptionItemId)
    final existing = _items.firstWhere(
      (i) =>
          i.menuItemId == item.menuItemId &&
          i.sizeLabel  == item.sizeLabel  &&
          _addonsMatch(i.addons, item.addons),
      orElse: () => _sentinel,
    );
    if (!identical(existing, _sentinel)) {
      existing.quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  // Sentinel to avoid nullable firstWhere hack
  static final _sentinel = CartItem(
    menuItemId: '__sentinel__', itemName: '', unitPrice: 0,
  );

  /// Two addon lists match iff they contain the same drinkOptionItemIds
  /// (order-independent).
  static bool _addonsMatch(
      List<SelectedAddon> a, List<SelectedAddon> b) {
    if (a.length != b.length) return false;
    final aIds = a.map((x) => x.drinkOptionItemId).toSet();
    final bIds = b.map((x) => x.drinkOptionItemId).toSet();
    return aIds.containsAll(bIds) && bIds.containsAll(aIds);
  }

  void removeAt(int i)        { _items.removeAt(i); notifyListeners(); }
  void setQty(int i, int qty) {
    if (qty <= 0) { removeAt(i); } else { _items[i].quantity = qty; notifyListeners(); }
  }

  void setPayment(String m)   { _payment  = m; notifyListeners(); }
  void setCustomer(String? n) { _customer = n; notifyListeners(); }
  void setNotes(String? n)    { _notes    = n; notifyListeners(); }

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
DART

# =============================================================================
# 7.  lib/core/providers/menu_provider.dart
#     Fix: parallel fetch, smarter reload guard, expose isStale flag.
# =============================================================================
write lib/core/providers/menu_provider.dart << 'DART'
import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import '../models/menu.dart';
import '../api/menu_api.dart';
import '../api/client.dart' show prefs;

class MenuProvider extends ChangeNotifier {
  List<Category>  _cats        = [];
  List<MenuItem>  _items       = [];
  String?         _selId;
  bool            _loading     = false;
  String?         _error;
  String?         _loadedOrgId;
  bool            _fromCache   = false;

  List<Category>  get categories => _cats;
  List<MenuItem>  get allItems   => _items;
  String?         get selectedId => _selId;
  bool            get loading    => _loading;
  String?         get error      => _error;
  bool            get fromCache  => _fromCache;

  List<MenuItem> get filtered => _selId == null
      ? _items
      : _items.where((i) => i.categoryId == _selId).toList();

  /// Load menu for [orgId].
  /// Skips network if fresh live data already loaded for this org.
  Future<void> load(String orgId) async {
    // Already have fresh live data — skip
    if (_loadedOrgId == orgId && _items.isNotEmpty && !_fromCache) return;

    _loading   = true;
    _fromCache = false;
    _error     = null;
    notifyListeners();

    try {
      // Fetch categories + items in parallel
      final results = await Future.wait([
        menuApi.categories(orgId),
        menuApi.items(orgId),
      ]);
      _cats        = results[0] as List<Category>;
      _items       = results[1] as List<MenuItem>;
      _selId       = _cats.isNotEmpty ? _cats.first.id : null;
      _loadedOrgId = orgId;
      _fromCache   = false;
      await _saveCache(orgId);
    } catch (_) {
      final ok = await _loadCache(orgId);
      if (ok) {
        _fromCache   = true;
        _loadedOrgId = orgId;
      } else {
        _error = 'No connection and no cached menu available';
      }
    }

    _loading = false;
    notifyListeners();
  }

  /// Force a fresh fetch regardless of current state.
  Future<void> refresh(String orgId) async {
    _loadedOrgId = null;
    await load(orgId);
  }

  void select(String id) { _selId = id; notifyListeners(); }

  // ── Cache ──────────────────────────────────────────────────────────────────
  Future<void> _saveCache(String orgId) async {
    try {
      final p = await prefs;
      await p.setString('menu_cache_v2_$orgId', jsonEncode({
        'categories': _cats.map((c)  => c.toJson()).toList(),
        'items':      _items.map((i) => i.toJson()).toList(),
      }));
    } catch (_) {}
  }

  Future<bool> _loadCache(String orgId) async {
    try {
      final p   = await prefs;
      final raw = p.getString('menu_cache_v2_$orgId');
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _cats  = (data['categories'] as List)
          .map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
      _items = (data['items'] as List)
          .map((i) => MenuItem.fromJson(i as Map<String, dynamic>)).toList();
      _selId = _cats.isNotEmpty ? _cats.first.id : null;
      return true;
    } catch (_) { return false; }
  }
}
DART

# =============================================================================
# 8.  lib/core/services/offline_sync_service.dart
#     Fix: skip permanently-broken orders (retryCount >= 5), idempotency header,
#          callback to OrderHistoryProvider, readable errors, proper init flow.
# =============================================================================
write lib/core/services/offline_sync_service.dart << 'DART'
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../api/client.dart' show prefs, friendlyError;
import '../api/order_api.dart';
import '../models/order.dart';
import '../models/pending_order.dart';

const _kPendingKey  = 'offline_pending_orders';
const _kMaxRetries  = 5;

/// Called after each order is successfully synced so the history list updates.
typedef OnOrderSynced = void Function(Order order);

class OfflineSyncService extends ChangeNotifier {
  List<PendingOrder> _pending   = [];
  bool               _syncing   = false;
  bool               _isOnline  = true;
  String?            _lastError;

  /// Wired up by main.dart after providers are ready.
  OnOrderSynced? onOrderSynced;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  List<PendingOrder> get pending   => List.unmodifiable(_pending);
  bool               get syncing   => _syncing;
  bool               get isOnline  => _isOnline;
  int                get count     => _pending.length;
  String?            get lastError => _lastError;

  Future<void> init() async {
    await _load();
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wentOnline = online && !_isOnline;
      _isOnline = online;
      notifyListeners();
      if (wentOnline && _pending.isNotEmpty) syncAll();
    });

    // Attempt sync on startup if online
    if (_isOnline && _pending.isNotEmpty) {
      // Defer until after runApp so providers are ready
      Future.microtask(syncAll);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> savePending(PendingOrder order) async {
    _pending.add(order);
    await _persist();
    notifyListeners();
    // Opportunistically sync right away if online
    if (_isOnline) syncAll();
  }

  /// Sync all pending orders.
  /// - Skips orders that have hit the retry ceiling (shows them as "stuck").
  /// - Continues past individual failures so one bad order doesn't block others.
  Future<void> syncAll() async {
    if (_syncing || _pending.isEmpty) return;
    _syncing   = true;
    _lastError = null;
    notifyListeners();

    final toProcess = List.of(_pending);
    final succeeded = <String>[];

    for (final p in toProcess) {
      // Skip permanently-broken orders
      if (p.retryCount >= _kMaxRetries) continue;

      try {
        final order = await orderApi.create(
          branchId:      p.branchId,
          shiftId:       p.shiftId,
          paymentMethod: p.paymentMethod,
          items:         p.items,
          customerName:  p.customerName,
          discountType:  p.discountType,
          discountValue: p.discountValue,
          idempotencyKey: p.localId,      // prevents duplicate creation
        );
        succeeded.add(p.localId);
        onOrderSynced?.call(order);
      } catch (e) {
        // Increment retry counter for this order and continue to next
        final idx = _pending.indexWhere((x) => x.localId == p.localId);
        if (idx != -1) {
          _pending[idx] = _pending[idx].copyWith(
            retryCount: _pending[idx].retryCount + 1,
          );
        }
        _lastError = friendlyError(e);
        // Don't break — keep trying subsequent orders
      }
    }

    _pending.removeWhere((p) => succeeded.contains(p.localId));
    await _persist();
    _syncing = false;
    notifyListeners();
  }

  /// How many orders are permanently stuck (>= max retries).
  int get stuckCount =>
      _pending.where((p) => p.retryCount >= _kMaxRetries).length;

  /// Discard a stuck order by localId.
  Future<void> discard(String localId) async {
    _pending.removeWhere((p) => p.localId == localId);
    await _persist();
    notifyListeners();
  }

  /// Reset retry counter so a stuck order can be re-attempted.
  Future<void> resetRetry(String localId) async {
    final idx = _pending.indexWhere((p) => p.localId == localId);
    if (idx != -1) {
      _pending[idx] = _pending[idx].copyWith(retryCount: 0);
      await _persist();
      notifyListeners();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final p   = await prefs;
      final raw = p.getString(_kPendingKey);
      if (raw != null) {
        _pending = (jsonDecode(raw) as List)
            .map((e) => PendingOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) { _pending = []; }
  }

  Future<void> _persist() async {
    try {
      final p = await prefs;
      await p.setString(_kPendingKey,
          jsonEncode(_pending.map((x) => x.toJson()).toList()));
    } catch (_) {}
  }
}

final offlineSyncService = OfflineSyncService();
DART

# =============================================================================
# 9.  lib/core/api/order_api.dart
#     Fix: accept idempotencyKey header; deduplicate _orderToJson (single source).
# =============================================================================
write lib/core/api/order_api.dart << 'DART'
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';
import '../models/order.dart';

class OrderApi {
  Future<Order> create({
    required String branchId,
    required String shiftId,
    required String paymentMethod,
    required List<CartItem> items,
    String? customerName,
    String? discountType,
    int?    discountValue,
    String? idempotencyKey,        // prevents duplicate creation on retry
  }) async {
    final res = await dio.post(
      '/orders',
      data: {
        'branch_id':       branchId,
        'shift_id':        shiftId,
        'payment_method':  paymentMethod,
        'customer_name':   customerName,
        'discount_type':   discountType,
        'discount_value':  discountValue,
        'items':           items.map((i) => i.toJson()).toList(),
      },
      options: idempotencyKey != null
          ? Options(headers: {'Idempotency-Key': idempotencyKey})
          : null,
    );
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Order>> list({String? shiftId, String? branchId}) async {
    final params = <String, dynamic>{};
    if (shiftId  != null) params['shift_id']  = shiftId;
    if (branchId != null) params['branch_id'] = branchId;
    final res = await dio.get('/orders', queryParameters: params);
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  /// Fetch a single order. Caches result; serves cache when offline.
  Future<Order> get(String id) async {
    try {
      final res   = await dio.get('/orders/$id');
      final order = Order.fromJson(res.data as Map<String, dynamic>);
      final p     = await prefs;
      await p.setString('order_$id', jsonEncode(orderToJson(order)));
      return order;
    } catch (_) {
      final p   = await prefs;
      final raw = p.getString('order_$id');
      if (raw != null) return Order.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      rethrow;
    }
  }

  Future<Order> voidOrder(String id,
      {String? reason, bool restoreInventory = false}) async {
    final res = await dio.post('/orders/$id/void', data: {
      'reason':            reason,
      'restore_inventory': restoreInventory,
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

final orderApi = OrderApi();

// ── Canonical serialiser — single source of truth used by both OrderApi
//    and OrderHistoryProvider so they never drift. ───────────────────────────
Map<String, dynamic> orderToJson(Order o) => {
  'id':             o.id,
  'branch_id':      o.branchId,
  'shift_id':       o.shiftId,
  'teller_id':      o.tellerId,
  'teller_name':    o.tellerName,
  'order_number':   o.orderNumber,
  'status':         o.status,
  'payment_method': o.paymentMethod,
  'subtotal':       o.subtotal,
  'discount_type':  o.discountType,
  'discount_value': o.discountValue,
  'discount_amount':o.discountAmount,
  'tax_amount':     o.taxAmount,
  'total_amount':   o.totalAmount,
  'customer_name':  o.customerName,
  'notes':          o.notes,
  'created_at':     o.createdAt.toIso8601String(),
  'items': o.items.map((i) => {
    'id':         i.id,
    'item_name':  i.itemName,
    'size_label': i.sizeLabel,
    'unit_price': i.unitPrice,
    'quantity':   i.quantity,
    'line_total': i.lineTotal,
    'addons': i.addons.map((a) => {
      'id':         a.id,
      'addon_name': a.addonName,
      'unit_price': a.unitPrice,
      'quantity':   a.quantity,
      'line_total': a.lineTotal,
    }).toList(),
  }).toList(),
};
DART

# =============================================================================
# 10. lib/core/providers/order_history_provider.dart
#     Fix: use canonical orderToJson from order_api; wire onOrderSynced.
# =============================================================================
write lib/core/providers/order_history_provider.dart << 'DART'
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../api/order_api.dart' show orderApi, orderToJson;
import '../api/client.dart' show prefs;

class OrderHistoryProvider extends ChangeNotifier {
  List<Order> _orders    = [];
  bool        _loading   = false;
  String?     _error;
  String?     _shiftId;
  bool        _fromCache = false;

  List<Order> get orders    => _orders;
  bool        get loading   => _loading;
  String?     get error     => _error;
  bool        get fromCache => _fromCache;

  Future<void> loadForShift(String shiftId) async {
    if (_shiftId == shiftId && _orders.isNotEmpty) return;
    _loading   = true;
    _fromCache = false;
    _error     = null;
    notifyListeners();
    try {
      _orders    = await orderApi.list(shiftId: shiftId);
      _shiftId   = shiftId;
      _fromCache = false;
      await _save(shiftId, _orders);
    } catch (_) {
      final cached = await _loadCached(shiftId);
      if (cached != null) {
        _orders    = cached;
        _shiftId   = shiftId;
        _fromCache = true;
      } else {
        _error = 'Could not load orders — check connection';
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh(String shiftId) async {
    _shiftId = null;
    await loadForShift(shiftId);
  }

  /// Called when a new order is successfully placed (online or after sync).
  void addOrder(Order o) {
    // Avoid duplicates if synced order is also in pending list
    if (_orders.any((x) => x.id == o.id)) return;
    _orders.insert(0, o);
    notifyListeners();
    if (_shiftId != null) _save(_shiftId!, _orders);
  }

  /// Called by OfflineSyncService after a pending order syncs successfully.
  void onOrderSynced(Order o) => addOrder(o);

  // ── Persistence — uses canonical orderToJson ───────────────────────────────
  static String _key(String shiftId) => 'orders_$shiftId';

  Future<void> _save(String shiftId, List<Order> orders) async {
    try {
      final p = await prefs;
      await p.setString(_key(shiftId),
          jsonEncode(orders.map(orderToJson).toList()));
    } catch (_) {}
  }

  Future<List<Order>?> _loadCached(String shiftId) async {
    try {
      final p   = await prefs;
      final raw = p.getString(_key(shiftId));
      if (raw == null) return null;
      return (jsonDecode(raw) as List)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (_) { return null; }
  }
}
DART

# =============================================================================
# 11. lib/main.dart
#     Fix: wire OfflineSyncService ↔ OrderHistoryProvider,
#          global error handler, branded splash, proper bootstrap.
# =============================================================================
write lib/main.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/branch_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/menu_provider.dart';
import 'core/providers/order_history_provider.dart';
import 'core/providers/shift_provider.dart';
import 'core/router/router.dart';
import 'core/services/offline_sync_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error handler — prevents red-screen crashes in release
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Init offline service BEFORE runApp — but syncAll() is deferred inside
  // init() via Future.microtask so providers exist when it fires.
  await offlineSyncService.init();

  runApp(const RuePOS());
}

class RuePOS extends StatelessWidget {
  const RuePOS({super.key});

  @override
  Widget build(BuildContext context) {
    final branchProvider = BranchProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OfflineSyncService>.value(
            value: offlineSyncService),
        ChangeNotifierProvider<BranchProvider>.value(value: branchProvider),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(branchProvider)..init(),
        ),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(
          create: (ctx) {
            final history = OrderHistoryProvider();
            // Wire offline sync → history so synced orders appear immediately
            offlineSyncService.onOrderSynced = history.onOrderSynced;
            return history;
          },
        ),
      ],
      child: Builder(builder: (ctx) {
        final auth = ctx.watch<AuthProvider>();
        if (auth.loading) return const _SplashScreen();
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/TheRue.png', height: 64),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ]),
          ),
        ),
      );
}
DART

# =============================================================================
# 12. lib/shared/widgets/app_button.dart
#     Fix: Cairo font, press-scale animation.
# =============================================================================
write lib/shared/widgets/app_button.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum BtnVariant { primary, danger, outline, ghost }

class AppButton extends StatefulWidget {
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
    this.loading  = false,
    this.variant  = BtnVariant.primary,
    this.width,
    this.icon,
    this.height   = 48,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _enabled => !widget.loading && widget.onTap != null;

  void _onTapDown(TapDownDetails _) { if (_enabled) _ctrl.forward(); }
  void _onTapUp(TapUpDetails _)     { if (_enabled) { _ctrl.reverse(); widget.onTap!(); } }
  void _onTapCancel()               { _ctrl.reverse(); }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, borderColor) = switch (widget.variant) {
      BtnVariant.primary => (AppColors.primary,       Colors.white,            Colors.transparent),
      BtnVariant.danger  => (AppColors.danger,         Colors.white,            Colors.transparent),
      BtnVariant.outline => (Colors.transparent,       AppColors.primary,       AppColors.primary),
      BtnVariant.ghost   => (Colors.transparent,       AppColors.textSecondary, Colors.transparent),
    };

    return GestureDetector(
      onTapDown:   _onTapDown,
      onTapUp:     _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width:  widget.width,
          height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color:        _enabled ? bg : bg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: fg),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 17, color: fg),
                      const SizedBox(width: 7),
                    ],
                    Text(widget.label,
                        style: cairo(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      fg,
                        )),
                  ]),
          ),
        ),
      ),
    );
  }
}
DART

# =============================================================================
# 13. lib/shared/widgets/label_value.dart
#     Fix: Cairo font.
# =============================================================================
write lib/shared/widgets/label_value.dart << 'DART'
import 'package:flutter/material.dart';
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
        Text(label,
            style: cairo(fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: cairo(
              fontSize:   13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color:      valueColor ?? AppColors.textPrimary,
            )),
      ],
    ),
  );
}
DART

# =============================================================================
# 14. lib/shared/widgets/error_banner.dart
#     Fix: Cairo font.
# =============================================================================
write lib/shared/widgets/error_banner.dart << 'DART'
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
      color:        AppColors.danger.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: AppColors.danger.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: AppColors.danger, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: cairo(fontSize: 13, color: AppColors.danger))),
      if (onRetry != null)
        TextButton(
          onPressed: onRetry,
          child: Text('Retry',
              style: cairo(fontSize: 13,
                  fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
    ]),
  );
}
DART

# =============================================================================
# 15. lib/shared/widgets/pin_pad.dart
#     Fix: Cairo font, larger keys scale on tablet.
# =============================================================================
write lib/shared/widgets/pin_pad.dart << 'DART'
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final String               pin;
  final int                  maxLength;
  final void Function(String) onDigit;
  final VoidCallback         onBackspace;

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
  Widget build(BuildContext context) {
    final w       = MediaQuery.of(context).size.width;
    final keySize = w >= 768 ? 80.0 : 68.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // PIN dots
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
      // Keys
      ..._rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) {
              return SizedBox(width: keySize, height: keySize);
            }
            return _Key(
              label:   k,
              size:    keySize,
              onTap:   () => k == '⌫' ? onBackspace() : onDigit(k),
            );
          }).toList(),
        ),
      )),
    ]);
  }
}

class _Key extends StatefulWidget {
  final String       label;
  final double       size;
  final VoidCallback onTap;
  const _Key({required this.label, required this.size, required this.onTap});
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => _ctrl.forward(),
    onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: ()  => _ctrl.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width:  widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset:     const Offset(0, 2),
          )],
        ),
        alignment: Alignment.center,
        child: Text(widget.label,
            style: cairo(
              fontSize:   widget.label == '⌫' ? 18 : 22,
              fontWeight: FontWeight.w600,
              color:      AppColors.textPrimary,
            )),
      ),
    ),
  );
}
DART

# =============================================================================
# 16. lib/features/home/home_screen.dart
#     Fix: remove direct API imports, type shift properly, offline stats banner.
# =============================================================================
write lib/features/home/home_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/order.dart';
import '../../core/models/shift.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int  _orderCount  = 0;
  int  _salesTotal  = 0;
  int  _systemCash  = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = context.read<AuthProvider>().user?.branchId;
    if (branchId == null) return;
    await context.read<ShiftProvider>().load(branchId);
    await _loadStats();
  }

  Future<void> _loadStats() async {
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null || !shift.isOpen) return;

    // Use already-loaded order history if available; else load it
    final history = context.read<OrderHistoryProvider>();
    if (history.orders.isEmpty || history.fromCache) {
      await history.loadForShift(shift.id);
    }

    if (!mounted) return;
    final orders = history.orders;

    // System cash: opening + cash orders (no voided)
    final cashOrders = orders
        .where((o) => o.status != 'voided' && o.paymentMethod == 'cash')
        .fold(0, (s, o) => s + o.totalAmount);

    setState(() {
      _orderCount  = orders.where((o) => o.status != 'voided').length;
      _salesTotal  = orders
          .where((o) => o.status != 'voided')
          .fold(0, (s, o) => s + o.totalAmount);
      _systemCash  = shift.openingCash + cashOrders;
      _statsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user     = context.watch<AuthProvider>().user!;
    final shift    = context.watch<ShiftProvider>();
    final w        = MediaQuery.of(context).size.width;
    final isTablet = w >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 36 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Image.asset('assets/TheRue.png',
                    height: isTablet ? 52 : 44),
                const Spacer(),
                Text(user.name,
                    style: cairo(
                        fontSize:   isTablet ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textSecondary)),
                const SizedBox(width: 12),
                _SignOutBtn(),
              ]),
              SizedBox(height: isTablet ? 36 : 28),

              // ── Greeting ─────────────────────────────────────────────────
              Text(
                _greet(user.name.split(' ').first),
                style: cairo(
                    fontSize:   isTablet ? 28 : 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                user.role.replaceAll('_', ' ').toUpperCase(),
                style: cairo(
                    fontSize:      11,
                    fontWeight:    FontWeight.w600,
                    color:         AppColors.textMuted,
                    letterSpacing: 1),
              ),
              SizedBox(height: isTablet ? 32 : 24),

              // ── Body ─────────────────────────────────────────────────────
              if (shift.loading)
                const Center(child: CircularProgressIndicator(
                    color: AppColors.primary))
              else if (shift.error != null)
                _ErrorBanner(message: shift.error!, onRetry: _load)
              else if (shift.hasOpen)
                _OpenShiftView(
                  shift:       shift.shift!,
                  orderCount:  _orderCount,
                  salesTotal:  _salesTotal,
                  systemCash:  _systemCash,
                  statsLoaded: _statsLoaded,
                  fromCache:   context.watch<OrderHistoryProvider>().fromCache,
                  onRefresh:   _loadStats,
                  isTablet:    isTablet,
                )
              else
                _NoShiftView(
                  suggested: shift.preFill?.suggestedOpeningCash ?? 0,
                  isTablet:  isTablet,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _greet(String first) {
    final h    = DateTime.now().hour;
    final word = h < 12 ? 'Morning' : h < 17 ? 'Afternoon' : 'Evening';
    return 'Good $word, $first';
  }
}

// ── Open Shift View ───────────────────────────────────────────────────────────
class _OpenShiftView extends StatelessWidget {
  final Shift        shift;
  final int          orderCount;
  final int          salesTotal;
  final int          systemCash;
  final bool         statsLoaded;
  final bool         fromCache;
  final VoidCallback onRefresh;
  final bool         isTablet;

  const _OpenShiftView({
    required this.shift,
    required this.orderCount,
    required this.salesTotal,
    required this.systemCash,
    required this.statsLoaded,
    required this.fromCache,
    required this.onRefresh,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<OfflineSyncService>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 30 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primary.withOpacity(0.25),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Offline / cache banner
          if (!sync.isOnline)
            _Banner(
              icon: Icons.wifi_off_rounded,
              text: 'Offline — cached data shown. Orders queue until online.',
            ),
          if (sync.isOnline && fromCache)
            _Banner(
              icon: Icons.history_rounded,
              text: 'Showing cached stats — tap refresh to update.',
            ),
          if (sync.isOnline && sync.count > 0)
            _Banner(
              icon:    Icons.sync_rounded,
              text:    'Syncing ${sync.count} offline order${sync.count == 1 ? "" : "s"}…',
              animate: true,
            ),
          if (sync.stuckCount > 0)
            _Banner(
              icon:  Icons.warning_amber_rounded,
              text:  '${sync.stuckCount} order${sync.stuckCount == 1 ? "" : "s"} failed to sync — check connection or discard.',
              warn:  true,
            ),

          // Status row
          Row(children: [
            _StatusPill(),
            const Spacer(),
            Text('Since ${timeShort(shift.openedAt)}',
                style: cairo(fontSize: 11, color: Colors.white60)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.white54),
            ),
          ]),
          SizedBox(height: isTablet ? 26 : 20),

          // Stats row
          Row(children: [
            _ShiftStat(label: 'Sales',       value: egp(salesTotal),  loading: !statsLoaded, isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(label: 'Orders',      value: '$orderCount',    loading: !statsLoaded, isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(
              label:    'System Cash',
              value:    egp(systemCash),
              sublabel: '${egp(shift.openingCash)} opening',
              loading:  !statsLoaded,
              isTablet: isTablet,
            ),
          ]),
          SizedBox(height: isTablet ? 28 : 22),

          // Action buttons
          Row(children: [
            Expanded(child: _CardBtn(label: 'New Order', icon: Icons.add_shopping_cart_rounded, onTap: () => context.go('/order'),         isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(label: 'History',   icon: Icons.receipt_long_rounded,       onTap: () => context.go('/order-history'), isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(label: 'Shifts',    icon: Icons.history_rounded,             onTap: () => context.go('/shift-history'), isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(
              label:    'Close',
              icon:     Icons.lock_outline_rounded,
              onTap:    !sync.isOnline
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Internet required to close shift'),
                            backgroundColor: Color(0xFF856404)))
                  : () => _confirmClose(context),
              danger:   true,
              isTablet: isTablet,
            )),
          ]),
        ]),
      ),
    ]);
  }

  void _confirmClose(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:   Text('Close Shift?', style: cairo(fontWeight: FontWeight.w800)),
        content: Text(
          'You will count cash and inventory on the next screen.',
          style: cairo(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: cairo(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go('/close-shift'); },
            child: Text('Continue',
                style: cairo(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String   text;
  final bool     animate;
  final bool     warn;
  const _Banner({required this.icon, required this.text,
      this.animate = false, this.warn = false});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color:        warn
          ? Colors.orange.withOpacity(0.25)
          : Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      animate
          ? SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: warn ? Colors.orange : Colors.white70))
          : Icon(icon, size: 13,
                color: warn ? Colors.orange : Colors.white70),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: cairo(fontSize: 11,
              color: warn ? Colors.orange : Colors.white70))),
    ]),
  );
}

class _StatusPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color:        Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 7, height: 7,
        decoration: const BoxDecoration(
            color: Color(0xFF4ADE80), shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('SHIFT OPEN',
          style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: 0.8)),
    ]),
  );
}

class _ShiftStat extends StatelessWidget {
  final String  label;
  final String  value;
  final String? sublabel;
  final bool    loading;
  final bool    isTablet;
  const _ShiftStat({required this.label, required this.value,
      this.sublabel, this.loading = false, this.isTablet = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: cairo(fontSize: 11, color: Colors.white60,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      loading
          ? Container(width: 50, height: 16,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4)))
          : Text(value, style: cairo(fontSize: isTablet ? 20 : 17,
              fontWeight: FontWeight.w800, color: Colors.white)),
      if (sublabel != null) ...[
        const SizedBox(height: 2),
        Text(sublabel!, style: cairo(fontSize: 10, color: Colors.white38)),
      ],
    ]),
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 44,
    color:  Colors.white.withOpacity(0.15),
    margin: const EdgeInsets.symmetric(horizontal: 14),
  );
}

class _CardBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;
  final bool         danger;
  final bool         isTablet;
  const _CardBtn({required this.label, required this.icon, required this.onTap,
      this.danger = false, this.isTablet = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 11),
      decoration: BoxDecoration(
        color:        danger
            ? Colors.white.withOpacity(0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size:  isTablet ? 18 : 16,
            color: danger ? Colors.white : AppColors.primary),
        const SizedBox(height: 4),
        Text(label, style: cairo(
            fontSize:   isTablet ? 12 : 11,
            fontWeight: FontWeight.w700,
            color:      danger ? Colors.white : AppColors.primary)),
      ]),
    ),
  );
}

// ── No Shift View ─────────────────────────────────────────────────────────────
class _NoShiftView extends StatelessWidget {
  final int  suggested;
  final bool isTablet;
  const _NoShiftView({required this.suggested, required this.isTablet});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
        child: CardContainer(
          padding: EdgeInsets.all(isTablet ? 28 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.wb_sunny_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No Open Shift',
                    style: cairo(fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w700)),
                if (suggested > 0)
                  Text('Last closing: ${egp(suggested)}',
                      style: cairo(fontSize: 12,
                          color: AppColors.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 22),
            AppButton(
              label: 'Open Shift',
              width: double.infinity,
              icon:  Icons.play_arrow_rounded,
              onTap: () => context.go('/open-shift'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
        child: OutlinedButton.icon(
          onPressed: () => context.go('/shift-history'),
          icon:  const Icon(Icons.history_rounded, size: 16),
          label: Text('View Shift History', style: cairo(fontSize: 14)),
          style: OutlinedButton.styleFrom(
            minimumSize:    const Size(double.infinity, 48),
            shape:          RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side:           const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

// ── Shared small widgets ──────────────────────────────────────────────────────
class _SignOutBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      await context.read<AuthProvider>().logout();
      if (context.mounted) context.go('/login');
    },
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(11),
          border:       Border.all(color: AppColors.border)),
      alignment: Alignment.center,
      child: const Icon(Icons.logout_rounded,
          size: 15, color: AppColors.textSecondary),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color:        AppColors.danger.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: AppColors.danger.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: AppColors.danger, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: cairo(fontSize: 13, color: AppColors.danger))),
      TextButton(
        onPressed: onRetry,
        child: Text('Retry',
            style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ),
    ]),
  );
}
DART

# =============================================================================
# 17. lib/features/order/order_screen.dart   (LARGE)
#     Fix: mobile-responsive (bottom-sheet cart on phones <768px),
#          offline checkout queue, scalable grid, keyboard-safe sheets,
#          normaliseName from utils.
# =============================================================================
write lib/features/order/order_screen.dart << 'DART'
import 'dart:math' show max;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/menu_api.dart';
import '../../core/api/order_api.dart';
import '../../core/models/menu.dart';
import '../../core/models/order.dart';
import '../../core/models/pending_order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/menu_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/label_value.dart';

const _skeletonBase      = Color(0xFFF0EBE3);
const _skeletonHighlight = Color(0xFFE8E0D5);

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = context.read<AuthProvider>().user?.orgId;
      if (orgId != null) context.read<MenuProvider>().load(orgId);
    });
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isTablet = w >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // Mobile: floating cart button in bottom-right
      floatingActionButton: isTablet ? null : _MobileCartFab(),
      body: SafeArea(
        child: Column(children: [
          _TopBar(ctrl: _searchCtrl, query: _query),
          Expanded(
            child: isTablet
                ? Row(children: [
                    if (_query.isEmpty) const _CategoryRail(),
                    Expanded(child: _contentArea()),
                    const _CartPanel(),
                  ])
                : Row(children: [
                    if (_query.isEmpty) const _CategoryRail(),
                    Expanded(child: _contentArea()),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _contentArea() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    switchInCurve:  Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child:   SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    ),
    child: _query.isNotEmpty
        ? _SearchResults(key: ValueKey(_query), query: _query)
        : const _MenuGrid(key: ValueKey('grid')),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String                query;
  const _TopBar({required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context) {
    final cart    = context.watch<CartProvider>();
    final sync    = context.watch<OfflineSyncService>();
    final isTablet = MediaQuery.of(context).size.width >= 768;

    final bar = Container(
      color:   Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(children: [
        _IconBtn(icon: Icons.arrow_back_rounded, onTap: () => context.go('/home')),
        const SizedBox(width: 10),
        Image.asset('assets/TheRue.png', height: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: ctrl,
              style: cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText:    'Search menu…',
                hintStyle:   cairo(fontSize: 14, color: AppColors.textMuted),
                prefixIcon:  const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(onTap: ctrl.clear,
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textMuted))
                    : null,
                border:          InputBorder.none,
                enabledBorder:   InputBorder.none,
                focusedBorder:   InputBorder.none,
                contentPadding:  const EdgeInsets.symmetric(vertical: 10),
                isDense:         true,
                filled:          false,
              ),
            ),
          ),
        ),
        // On tablet show the cart pill; on mobile it's the FAB
        if (isTablet) ...[
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: cart.isEmpty
                ? const SizedBox.shrink(key: ValueKey('empty'))
                : Container(
                    key: const ValueKey('pill'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color:      AppColors.primary.withOpacity(0.28),
                          blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('${cart.count} · ${egp(cart.total)}',
                          style: cairo(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                  ),
          ),
        ],
      ]),
    );

    if (!sync.isOnline || sync.count > 0) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        bar,
        if (!sync.isOnline)
          _StatusBanner(
            color: const Color(0xFFFFF3CD),
            icon:  Icons.wifi_off_rounded,
            text:  'Offline — cached menu. Orders will sync when connected.',
            textColor: const Color(0xFF856404),
          ),
        if (sync.isOnline && sync.count > 0)
          _StatusBanner(
            color:     const Color(0xFFCFE2FF),
            icon:      Icons.sync_rounded,
            text:      'Syncing ${sync.count} offline order${sync.count == 1 ? "" : "s"}…',
            textColor: const Color(0xFF084298),
            animate:   true,
          ),
      ]);
    }
    return bar;
  }
}

class _StatusBanner extends StatelessWidget {
  final Color    color;
  final IconData icon;
  final String   text;
  final Color    textColor;
  final bool     animate;
  const _StatusBanner({required this.color, required this.icon,
      required this.text, required this.textColor, this.animate = false});

  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    color:   color,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child:   Row(children: [
      animate
          ? SizedBox(width: 11, height: 11,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: textColor))
          : Icon(icon, size: 13, color: textColor),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: cairo(fontSize: 11, color: textColor))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY RAIL
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    return Container(
      width: 86,
      decoration: const BoxDecoration(
          color:  Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFF0F0F0)))),
      child: ListView.builder(
        padding:     const EdgeInsets.symmetric(vertical: 8),
        itemCount:   menu.categories.length,
        itemBuilder: (_, i) {
          final cat = menu.categories[i];
          final sel = cat.id == menu.selectedId;
          return GestureDetector(
            onTap: () => menu.select(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve:    Curves.easeOutCubic,
              margin:   const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              padding:  const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color:        sel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Icon(_catIcon(cat.name),
                    size:  20,
                    color: sel ? Colors.white : AppColors.textMuted),
                const SizedBox(height: 5),
                Text(normaliseName(cat.name),
                    style: cairo(
                        fontSize:   9.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color:      sel ? Colors.white : AppColors.textSecondary,
                        height:     1.25),
                    textAlign: TextAlign.center,
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
  }

  IconData _catIcon(String name) => _CatStyle.of(name).icon;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU GRID  — adaptive columns based on available width
// ─────────────────────────────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final menu  = context.watch<MenuProvider>();
    final items = menu.filtered.where((i) => i.isActive).toList();

    if (menu.loading) {
      return _grid(8, (_, __) => const _MenuCardSkeleton());
    }
    if (menu.error != null) {
      return _ErrorState(
        message: menu.error!,
        onRetry: () {
          final orgId = context.read<AuthProvider>().user?.orgId;
          if (orgId != null) context.read<MenuProvider>().refresh(orgId);
        },
      );
    }
    if (items.isEmpty) {
      return Center(child: Text('No items in this category',
          style: cairo(color: AppColors.textMuted)));
    }
    return _grid(items.length, (_, i) => _MenuCard(item: items[i]));
  }

  Widget _grid(int count, Widget Function(BuildContext, int) builder) =>
      LayoutBuilder(builder: (ctx, constraints) {
        // Adaptive: aim for cards ~160px wide, min 2, max 5
        final cols = (constraints.maxWidth / 160).floor().clamp(2, 5);
        final extent = constraints.maxWidth / cols;
        return GridView.builder(
          padding:  const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   cols,
            mainAxisSpacing:  10,
            crossAxisSpacing: 10,
            childAspectRatio: extent / (extent * 1.3),
          ),
          itemCount:   count,
          itemBuilder: builder,
        );
      });
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH RESULTS
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResults extends StatelessWidget {
  final String query;
  const _SearchResults({required this.query, super.key});

  @override
  Widget build(BuildContext context) {
    final found = context.watch<MenuProvider>().allItems.where((i) =>
        i.isActive &&
        (i.name.toLowerCase().contains(query) ||
         (i.description?.toLowerCase().contains(query) ?? false))).toList();

    if (found.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 160, height: 160,
            child: Lottie.asset('assets/lottie/no_results.json',
                fit: BoxFit.contain, repeat: true)),
        const SizedBox(height: 8),
        Text('No results for "$query"',
            style: cairo(fontSize: 14, color: AppColors.textSecondary)),
      ]));
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final cols   = (constraints.maxWidth / 160).floor().clamp(2, 5);
      final extent = constraints.maxWidth / cols;
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          mainAxisSpacing:  10,
          crossAxisSpacing: 10,
          childAspectRatio: extent / (extent * 1.3),
        ),
        itemCount:   found.length,
        itemBuilder: (_, i) => _MenuCard(item: found[i]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE CART FAB
// ─────────────────────────────────────────────────────────────────────────────
class _MobileCartFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (cart.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed:       () => _MobileCartSheet.show(context),
      backgroundColor: AppColors.primary,
      label: Text('${cart.count} items · ${egp(cart.total)}',
          style: cairo(fontSize: 13, fontWeight: FontWeight.w700,
              color: Colors.white)),
      icon: const Icon(Icons.shopping_bag_outlined,
          size: 18, color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE CART BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _MobileCartSheet extends StatelessWidget {
  const _MobileCartSheet();

  static void show(BuildContext ctx) => showModalBottomSheet(
    context:           ctx,
    isScrollControlled: true,
    backgroundColor:   Colors.transparent,
    builder:           (_) => const _MobileCartSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color:        const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2)))),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color:        AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${cart.count}',
                  style: cairo(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () {
                  cart.clear();
                  Navigator.pop(context);
                },
                child: Text('Clear',
                    style: cairo(fontSize: 13, color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: cart.isEmpty
              ? Center(child: Text('Cart is empty',
                  style: cairo(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding:          const EdgeInsets.all(12),
                  itemCount:        cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder:      (_, i) => _CartRow(index: i),
                ),
        ),
        if (!cart.isEmpty) _CartFooter(),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON
// ─────────────────────────────────────────────────────────────────────────────
class _MenuCardSkeleton extends StatefulWidget {
  const _MenuCardSkeleton();
  @override
  State<_MenuCardSkeleton> createState() => _MenuCardSkeletonState();
}

class _MenuCardSkeletonState extends State<_MenuCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) {
      final c = Color.lerp(_skeletonBase, _skeletonHighlight, _anim.value)!;
      return Container(
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          Expanded(child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(color: c))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(child: Container(height: 11,
                  decoration: BoxDecoration(color: c,
                      borderRadius: BorderRadius.circular(4)))),
              const SizedBox(width: 12),
              Container(width: 44, height: 11,
                  decoration: BoxDecoration(color: c,
                      borderRadius: BorderRadius.circular(4))),
            ]),
          ),
        ]),
      );
    },
  );
}

class _ImageSkeleton extends StatefulWidget {
  @override
  State<_ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<_ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
          color: Color.lerp(_skeletonBase, _skeletonHighlight, _anim.value)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY STYLES
// ─────────────────────────────────────────────────────────────────────────────
class _CatStyle {
  final IconData icon;
  final Color bgTop, bgBottom, iconColor, accent;
  const _CatStyle({required this.icon, required this.bgTop,
      required this.bgBottom, required this.iconColor, required this.accent});

  static _CatStyle of(String name) {
    final n = name.toLowerCase();
    if (n.contains('matcha'))
      return const _CatStyle(icon: Icons.eco_rounded,
          bgTop: Color(0xFFE8F5E9), bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF2E7D32), accent: Color(0xFF388E3C));
    if (n.contains('latte') || n.contains('espresso') ||
        n.contains('americano') || n.contains('cappuc') ||
        n.contains('flat') || n.contains('cortado') ||
        n.contains('coffee') || n.contains('v60') ||
        n.contains('blended') || n.contains('cold brew'))
      return const _CatStyle(icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF5EEE6), bgBottom: Color(0xFFEDD9C0),
          iconColor: Color(0xFF5D4037), accent: Color(0xFF795548));
    if (n.contains('chocolate') || n.contains('mocha'))
      return const _CatStyle(icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF3E5E5), bgBottom: Color(0xFFE8CECE),
          iconColor: Color(0xFF6D4C41), accent: Color(0xFF8D3A3A));
    if (n.contains('croissant') || n.contains('brownie') ||
        n.contains('cookie') || n.contains('pastry') ||
        n.contains('pastries') || n.contains('cake') || n.contains('waffle'))
      return const _CatStyle(icon: Icons.bakery_dining_rounded,
          bgTop: Color(0xFFFFF8E8), bgBottom: Color(0xFFFFF0C8),
          iconColor: Color(0xFFE65100), accent: Color(0xFFF57C00));
    if (n.contains('sandwich') || n.contains('chicken') ||
        n.contains('turkey') || n.contains('food'))
      return const _CatStyle(icon: Icons.lunch_dining_rounded,
          bgTop: Color(0xFFFFF3E0), bgBottom: Color(0xFFFFE0B2),
          iconColor: Color(0xFFE64A19), accent: Color(0xFFEF6C00));
    if (n.contains('affogato') || n.contains('ice cream'))
      return const _CatStyle(icon: Icons.icecream_rounded,
          bgTop: Color(0xFFF3E5F5), bgBottom: Color(0xFFE1BEE7),
          iconColor: Color(0xFF7B1FA2), accent: Color(0xFF9C27B0));
    if (n.contains('lemon') || n.contains('lemonade') ||
        n.contains('refresher') || n.contains('juice'))
      return const _CatStyle(icon: Icons.local_drink_rounded,
          bgTop: Color(0xFFFFFDE7), bgBottom: Color(0xFFFFF9C4),
          iconColor: Color(0xFFF57F17), accent: Color(0xFFFBC02D));
    if (n.contains('tea') || n.contains('chai'))
      return const _CatStyle(icon: Icons.emoji_food_beverage_rounded,
          bgTop: Color(0xFFE8F5E9), bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF388E3C), accent: Color(0xFF43A047));
    if (n.contains('water') || n.contains('sparkling'))
      return const _CatStyle(icon: Icons.water_drop_rounded,
          bgTop: Color(0xFFE3F2FD), bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF1565C0), accent: Color(0xFF1976D2));
    if (n.contains('iced'))
      return const _CatStyle(icon: Icons.ac_unit_rounded,
          bgTop: Color(0xFFE3F2FD), bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF0277BD), accent: Color(0xFF0288D1));
    return const _CatStyle(icon: Icons.local_cafe_rounded,
        bgTop: Color(0xFFF5EEE6), bgBottom: Color(0xFFEDD9C0),
        iconColor: Color(0xFF795548), accent: Color(0xFF8D6E63));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MenuCard extends StatefulWidget {
  final MenuItem item;
  const _MenuCard({required this.item, super.key});
  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard>
    with SingleTickerProviderStateMixin {
  bool _fetching = false;
  late final AnimationController _pressCtrl;
  late final Animation<double>   _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _pressAnim = Tween<double>(begin: 1, end: 0.96)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  Future<void> _onTap() async {
    if (_fetching) return;
    setState(() => _fetching = true);
    try {
      final full = await menuApi.item(widget.item.id);
      if (mounted) { setState(() => _fetching = false); ItemDetailSheet.show(context, full); }
    } catch (_) {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item     = widget.item;
    final style    = _CatStyle.of(item.name);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) async { await _pressCtrl.reverse(); _onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: style.accent.withOpacity(0.12),
                  blurRadius: 12, offset: const Offset(0, 4)),
              BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,  offset: const Offset(0, 1)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: [
              Expanded(child: Stack(children: [
                Positioned.fill(child: hasImage
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover,
                        loadingBuilder: (_, child, prog) =>
                            prog == null ? child : _ImageSkeleton(),
                        errorBuilder:   (_, __, ___) =>
                            _CardBackground(style: style))
                    : _CardBackground(style: style)),
                if (!hasImage) Center(child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                      color: style.iconColor.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(style.icon, size: 28, color: style.iconColor),
                )),
                if (_fetching) Positioned.fill(child: Container(
                  color:     Colors.black.withOpacity(0.3),
                  alignment: Alignment.center,
                  child:     const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white)),
                )),
              ])),
              Container(
                color:   Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child:   Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Container(width: 4, height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: style.accent,
                          borderRadius: BorderRadius.circular(2))),
                  Expanded(child: Text(normaliseName(item.name),
                      style: cairo(fontSize: 12, fontWeight: FontWeight.w700,
                          height: 1.25),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  Text(egp(item.basePrice),
                      style: cairo(fontSize: 11, fontWeight: FontWeight.w800,
                          color: style.accent)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CardBackground extends StatelessWidget {
  final _CatStyle style;
  const _CardBackground({required this.style});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: [style.bgTop, style.bgBottom],
        begin: Alignment.topLeft, end: Alignment.bottomRight)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  static void show(BuildContext ctx, MenuItem item) => showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(item: item));

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  String?                     _selectedSize;
  final Map<String, String>   _single = {};
  final Map<String, Set<String>> _multi = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty)
      _selectedSize = widget.item.sizes.first.label;
  }

  int get _unitPrice   => widget.item.priceForSize(_selectedSize);
  int get _addonsTotal {
    int t = 0;
    for (final g in widget.item.optionGroups) {
      if (g.isMultiSelect) {
        for (final o in g.items) {
          if ((_multi[g.id] ?? {}).contains(o.id)) t += o.price;
        }
      } else {
        for (final o in g.items) {
          if (o.id == _single[g.id]) { t += o.price; break; }
        }
      }
    }
    return t;
  }

  int  get _lineTotal => (_unitPrice + _addonsTotal) * _qty;
  bool get _canAdd {
    for (final g in widget.item.optionGroups) {
      if (!g.isRequired) continue;
      if (g.isMultiSelect) { if ((_multi[g.id] ?? {}).isEmpty) return false; }
      else                  { if (!_single.containsKey(g.id))  return false; }
    }
    return true;
  }

  void _toggleSingle(String gId, String oId, bool req) => setState(() {
    if (_single[gId] == oId) { if (!req) _single.remove(gId); }
    else _single[gId] = oId;
  });

  void _toggleMulti(String gId, String oId) => setState(() {
    final s = _multi.putIfAbsent(gId, () => {});
    s.contains(oId) ? s.remove(oId) : s.add(oId);
    if (s.isEmpty) _multi.remove(gId);
  });

  void _addToCart() {
    final addons = <SelectedAddon>[];
    for (final g in widget.item.optionGroups) {
      if (g.isMultiSelect) {
        for (final o in g.items) {
          if ((_multi[g.id] ?? {}).contains(o.id)) {
            addons.add(SelectedAddon(addonItemId: o.addonItemId,
                drinkOptionItemId: o.id, name: o.name, priceModifier: o.price));
          }
        }
      } else {
        final sId = _single[g.id];
        if (sId == null) continue;
        for (final o in g.items) {
          if (o.id == sId) {
            addons.add(SelectedAddon(addonItemId: o.addonItemId,
                drinkOptionItemId: o.id, name: o.name, priceModifier: o.price));
            break;
          }
        }
      }
    }
    context.read<CartProvider>().add(CartItem(
        menuItemId: widget.item.id,
        itemName:   normaliseName(widget.item.name),
        sizeLabel:  _selectedSize,
        unitPrice:  _unitPrice,
        quantity:   _qty,
        addons:     addons));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: mq.size.height * 0.90),
        decoration: const BoxDecoration(
            color: Color(0xFFFAF8F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDDD8D0),
                    borderRadius: BorderRadius.circular(2))))),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            decoration: const BoxDecoration(color: Color(0xFFFAF8F5),
                border: Border(bottom: BorderSide(color: Color(0xFFECE8E0)))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(normaliseName(widget.item.name),
                    style: cairo(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                if (widget.item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.item.description!,
                      style: cairo(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
                ],
              ])),
              const SizedBox(width: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, -0.3), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child)),
                child: Container(
                  key: ValueKey(_unitPrice + _addonsTotal),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(egp(_unitPrice + _addonsTotal),
                      style: cairo(fontSize: 16, fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
            ]),
          ),
          // Options scroll area
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.item.sizes.isNotEmpty) ...[
                _SectionLabel('Size'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8,
                    children: widget.item.sizes.map((s) => _Chip(
                      label:    normaliseName(s.label),
                      sublabel: egp(s.price),
                      selected: s.label == _selectedSize,
                      checkbox: false,
                      onTap:    () => setState(() => _selectedSize = s.label),
                    )).toList()),
                const SizedBox(height: 20),
              ],
              for (final g in widget.item.optionGroups) ...[
                _OptionGroupCard(
                  group:          g,
                  selectedSingle: _single[g.id],
                  selectedMulti:  _multi[g.id] ?? {},
                  onToggleSingle: (oId) => _toggleSingle(g.id, oId, g.isRequired),
                  onToggleMulti:  (oId) => _toggleMulti(g.id, oId),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 6),
            ]),
          )),
          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: const BoxDecoration(color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECE8E0)))),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF5F0EB),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _QtyBtn(icon: Icons.remove,
                      onTap: () => setState(() => _qty = (_qty - 1).clamp(1, 99))),
                  SizedBox(width: 40, child: Center(child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text('$_qty', key: ValueKey(_qty),
                          style: cairo(fontSize: 16, fontWeight: FontWeight.w800))))),
                  _QtyBtn(icon: Icons.add,
                      onTap: () => setState(() => _qty = (_qty + 1).clamp(1, 99))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: AppButton(
                label: _canAdd
                    ? 'Add to Order — ${egp(_lineTotal)}'
                    : 'Select required options',
                height: 50,
                onTap:  _canAdd ? _addToCart : null,
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OPTION GROUP CARD
// ─────────────────────────────────────────────────────────────────────────────
class _OptionGroupCard extends StatefulWidget {
  final dynamic               group;
  final String?               selectedSingle;
  final Set<String>           selectedMulti;
  final void Function(String) onToggleSingle;
  final void Function(String) onToggleMulti;
  const _OptionGroupCard({required this.group, required this.selectedSingle,
      required this.selectedMulti, required this.onToggleSingle,
      required this.onToggleMulti});
  @override
  State<_OptionGroupCard> createState() => _OptionGroupCardState();
}

class _OptionGroupCardState extends State<_OptionGroupCard> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final g       = widget.group;
    final allOpts = g.items as List;
    final showSearch = allOpts.length > 5;
    final opts = _query.isEmpty ? allOpts
        : allOpts.where((o) =>
            (o.name as String).toLowerCase().contains(_query)).toList();
    final selCount = g.isMultiSelect
        ? widget.selectedMulti.length
        : (widget.selectedSingle != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selCount > 0
            ? AppColors.primary.withOpacity(0.2)
            : const Color(0xFFECE8E0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: Row(children: [
              Text(g.displayName.toString().toUpperCase(),
                  style: cairo(fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.7)),
              const SizedBox(width: 6),
              if (g.isRequired)  _Pill('Required', AppColors.danger),
              if (g.isMultiSelect) ...[
                const SizedBox(width: 4), _Pill('Multi', AppColors.primary)],
            ])),
            if (selCount > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$selCount', style: cairo(fontSize: 10,
                  fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
        ),
        if (showSearch) ...[
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(height: 34,
              decoration: BoxDecoration(color: const Color(0xFFF5F0EB),
                  borderRadius: BorderRadius.circular(9)),
              child: TextField(controller: _searchCtrl,
                style: cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText:  'Search options…',
                  hintStyle: cairo(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 15, color: AppColors.textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(onTap: _searchCtrl.clear,
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.textMuted))
                      : null,
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  isDense: true, filled: false,
                )),
            )),
        ],
        Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: opts.isEmpty
              ? Text('No options match "$_query"',
                  style: cairo(fontSize: 12, color: AppColors.textMuted))
              : Wrap(spacing: 7, runSpacing: 7, children: opts.map((opt) {
                  final sel = g.isMultiSelect
                      ? widget.selectedMulti.contains(opt.id)
                      : widget.selectedSingle == opt.id;
                  return _Chip(
                    label:    normaliseName(opt.name as String),
                    sublabel: (opt.price as int) > 0
                        ? '+${egp(opt.price as int)}' : null,
                    selected: sel,
                    checkbox: g.isMultiSelect,
                    onTap:    () => g.isMultiSelect
                        ? widget.onToggleMulti(opt.id as String)
                        : widget.onToggleSingle(opt.id as String),
                  );
                }).toList()),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART PANEL (tablet sidebar)
// ─────────────────────────────────────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    // Adaptive cart width: 26% of screen, clamped 280–380px
    final cartW = (w * 0.26).clamp(280.0, 380.0);
    final cart  = context.watch<CartProvider>();

    return Container(
      width: cartW,
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(children: [
            Text('Order', style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            if (!cart.isEmpty) ...[
              const SizedBox(width: 8),
              AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(cart.count),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${cart.count}', style: cairo(fontSize: 11,
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
                )),
            ],
            const Spacer(),
            if (!cart.isEmpty) GestureDetector(
              onTap: () => _confirmClear(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Clear', style: cairo(fontSize: 12,
                    fontWeight: FontWeight.w600, color: AppColors.danger)),
              ),
            ),
          ]),
        ),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  key:              const ValueKey('items'),
                  padding:          const EdgeInsets.all(10),
                  itemCount:        cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder:      (_, i) => _CartRow(index: i)),
        )),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: cart.isEmpty ? const SizedBox.shrink() : _CartFooter(),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:   Text('Clear Order?', style: cairo(fontWeight: FontWeight.w700)),
      content: Text('Remove all items from the cart.', style: cairo()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: cairo(color: AppColors.textSecondary))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); context.read<CartProvider>().clear(); },
          child: Text('Clear', style: cairo(color: AppColors.danger,
              fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 130, height: 130,
          child: Lottie.asset('assets/lottie/empty_cart.json',
              fit: BoxFit.contain, repeat: true)),
      const SizedBox(height: 8),
      Text('Cart is empty', style: cairo(fontSize: 14,
          fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text('Tap any item to add it',
          style: cairo(fontSize: 12, color: AppColors.textMuted)),
    ]),
  );
}

class _CartRow extends StatelessWidget {
  final int index;
  const _CartRow({required this.index});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items[index];
    return Container(
      padding:     const EdgeInsets.all(10),
      decoration:  BoxDecoration(color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(
            item.itemName + (item.sizeLabel != null
                ? ' · ${normaliseName(item.sizeLabel!)}' : ''),
            style: cairo(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3))),
          const SizedBox(width: 8),
          Text(egp(item.lineTotal),
              style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        if (item.addons.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(spacing: 4, runSpacing: 4,
              children: item.addons.map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(
                    a.priceModifier > 0
                        ? '${normaliseName(a.name)} +${egp(a.priceModifier)}'
                        : normaliseName(a.name),
                    style: cairo(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              )).toList()),
        ],
        const SizedBox(height: 8),
        Row(children: [
          _InlineBtn(icon: Icons.remove,
              onTap: () => cart.setQty(index, item.quantity - 1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}',
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w700))),
          _InlineBtn(icon: Icons.add,
              onTap: () => cart.setQty(index, item.quantity + 1)),
          const Spacer(),
          GestureDetector(
            onTap: () => cart.removeAt(index),
            child: Container(width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Icon(Icons.delete_outline_rounded,
                  size: 15, color: AppColors.danger)),
          ),
        ]),
      ]),
    );
  }
}

class _CartFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(children: [
        LabelValue('Subtotal', egp(cart.subtotal)),
        if (cart.discountAmount > 0)
          LabelValue('Discount', '− ${egp(cart.discountAmount)}',
              valueColor: AppColors.success),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, -0.3), end: Offset.zero)
                      .animate(anim),
                  child: FadeTransition(opacity: anim, child: child)),
              child: Text(egp(cart.total), key: ValueKey(cart.total),
                  style: cairo(fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
          ])),
        const SizedBox(height: 4),
        AppButton(label: 'Checkout', width: double.infinity, height: 50,
            icon: Icons.arrow_forward_rounded,
            onTap: () => CheckoutSheet.show(context)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT SHEET
//  FIXED: saves to offline queue when network is unavailable.
// ─────────────────────────────────────────────────────────────────────────────
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});
  static void show(BuildContext ctx) => showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutSheet());
  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool    _loading = false;
  String? _error;
  final _customerCtrl = TextEditingController();
  static const _methods = ['cash', 'card'];

  @override
  void dispose() { _customerCtrl.dispose(); super.dispose(); }

  Future<void> _place() async {
    final cart     = context.read<CartProvider>();
    final shift    = context.read<ShiftProvider>().shift;
    final sync     = context.read<OfflineSyncService>();
    final customer = _customerCtrl.text.trim().isEmpty
        ? null : _customerCtrl.text.trim();

    if (shift == null) { setState(() => _error = 'No open shift'); return; }
    setState(() { _loading = true; _error = null; });

    // ── OFFLINE PATH ──────────────────────────────────────────────────────
    if (!sync.isOnline) {
      final pending = PendingOrder(
        localId:       const Uuid().v4(),
        branchId:      shift.branchId,
        shiftId:       shift.id,
        paymentMethod: cart.payment,
        customerName:  customer,
        discountType:  cart.discountTypeStr,
        discountValue: cart.discountValue,
        items:         cart.items.toList(),
        createdAt:     DateTime.now(),
      );
      await sync.savePending(pending);
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order saved offline — will sync when connected'),
          backgroundColor: Color(0xFF856404),
          duration: Duration(seconds: 4),
        ));
      }
      return;
    }

    // ── ONLINE PATH ───────────────────────────────────────────────────────
    try {
      final order = await orderApi.create(
        branchId:      shift.branchId,
        shiftId:       shift.id,
        paymentMethod: cart.payment,
        items:         cart.items.toList(),
        customerName:  customer,
        discountType:  cart.discountTypeStr,
        discountValue: cart.discountValue,
        idempotencyKey: const Uuid().v4(),
      );
      context.read<OrderHistoryProvider>().addOrder(order);
      final total = cart.total;
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context, order: order, total: total);
      }
    } catch (e) {
      if (e is DioException) debugPrint('ORDER ${e.response?.statusCode}: ${e.response?.data}');
      // If we lost connection mid-flight, queue it
      if (e is DioException && (
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout)) {
        final pending = PendingOrder(
          localId:       const Uuid().v4(),
          branchId:      shift.branchId,
          shiftId:       shift.id,
          paymentMethod: cart.payment,
          customerName:  customer,
          discountType:  cart.discountTypeStr,
          discountValue: cart.discountValue,
          items:         cart.items.toList(),
          createdAt:     DateTime.now(),
        );
        await context.read<OfflineSyncService>().savePending(pending);
        cart.clear();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Connection lost — order saved offline'),
            backgroundColor: Color(0xFF856404),
            duration: Duration(seconds: 4),
          ));
        }
      } else {
        setState(() { _error = 'Failed to place order — please retry'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final mq   = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 14, 24, mq.viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),
        Text('Checkout', style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        // Totals
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            LabelValue('Subtotal', egp(cart.subtotal)),
            if (cart.discountAmount > 0)
              LabelValue('Discount', '− ${egp(cart.discountAmount)}',
                  valueColor: AppColors.success),
            const Divider(height: 16, color: Color(0xFFEEEEEE)),
            LabelValue('Total', egp(cart.total), bold: true),
          ]),
        ),
        const SizedBox(height: 18),
        // Customer
        Text('CUSTOMER NAME (OPTIONAL)',
            style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(controller: _customerCtrl,
            textCapitalization: TextCapitalization.words,
            style: cairo(fontSize: 15),
            decoration: InputDecoration(
              hintText:   'e.g. Ahmed',
              hintStyle:  cairo(fontSize: 15, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 18, color: AppColors.textMuted),
            )),
        const SizedBox(height: 18),
        // Payment
        Text('PAYMENT', style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(children: _methods.map((m) {
          final sel   = cart.payment == m;
          final label = m[0].toUpperCase() + m.substring(1);
          final icon  = m == 'cash'
              ? Icons.payments_outlined : Icons.credit_card_rounded;
          return Expanded(child: GestureDetector(
            onTap: () => cart.setPayment(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin:   const EdgeInsets.only(right: 8),
              padding:  const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:        sel ? AppColors.primary : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? AppColors.primary
                    : const Color(0xFFE8E8E8))),
              child: Column(children: [
                Icon(icon, size: 22,
                    color: sel ? Colors.white : AppColors.textSecondary),
                const SizedBox(height: 6),
                Text(label, style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textSecondary)),
              ]),
            ),
          ));
        }).toList()),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
              const SizedBox(width: 8),
              Text(_error!, style: cairo(fontSize: 13, color: AppColors.danger)),
            ])),
        ],
        const SizedBox(height: 20),
        AppButton(label: 'Place Order', loading: _loading,
            width: double.infinity, height: 52,
            icon: Icons.check_rounded, onTap: _place),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class ReceiptSheet extends StatefulWidget {
  final Order order;
  final int   total;
  const ReceiptSheet({super.key, required this.order, required this.total});

  static void show(BuildContext ctx, {required Order order, required int total}) =>
      showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent,
          builder: (_) => ReceiptSheet(order: order, total: total));

  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  bool    _printing   = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _print();
    });
  }

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter) return;
    setState(() { _printing = true; _printError = null; });
    final err = await PrinterService.print(
        ip: bp.printerIp!, port: bp.printerPort,
        order: widget.order, branchName: bp.branchName);
    if (mounted) setState(() { _printing = false; _printError = err; });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 14, 24,
          MediaQuery.of(context).padding.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        SizedBox(width: 120, height: 120,
            child: Lottie.asset('assets/lottie/success.json',
                repeat: false, fit: BoxFit.contain)),
        const SizedBox(height: 8),
        Text('Order Placed!', style: cairo(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Order #${o.orderNumber}',
            style: cairo(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Container(width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            LabelValue('Payment',
                o.paymentMethod[0].toUpperCase() +
                o.paymentMethod.substring(1).replaceAll('_', ' ')),
            if (o.customerName != null && o.customerName!.isNotEmpty)
              LabelValue('Customer', o.customerName!),
            LabelValue('Total', egp(o.totalAmount), bold: true),
            LabelValue('Time', timeShort(o.createdAt)),
          ]),
        ),
        const SizedBox(height: 16),
        _printing
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Printing…', style: cairo(fontSize: 13,
                    color: AppColors.textSecondary)),
              ])
            : GestureDetector(
                onTap: _print,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.print_rounded, size: 16,
                        color: _printError != null
                            ? AppColors.danger : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(_printError != null ? 'Retry Print' : 'Reprint Receipt',
                        style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                            color: _printError != null
                                ? AppColors.danger : AppColors.primary)),
                  ]),
                ),
              ),
        const SizedBox(height: 16),
        AppButton(label: 'New Order', width: double.infinity, height: 52,
            icon: Icons.add_rounded, onTap: () => Navigator.pop(context)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: cairo(fontSize: 10.5, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.7));
}

class _Pill extends StatelessWidget {
  final String text;
  final Color  color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: cairo(fontSize: 9, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.3)));
}

class _Chip extends StatelessWidget {
  final String    label;
  final String?   sublabel;
  final bool      selected;
  final bool      checkbox;
  final VoidCallback onTap;
  const _Chip({required this.label, this.sublabel, required this.selected,
      required this.checkbox, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        selected ? AppColors.primary : const Color(0xFFF5F0EB),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE4DDD4),
              width: selected ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (checkbox) ...[
            Icon(selected ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
                size: 15, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          Text(label, style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary)),
          if (sublabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(sublabel!, style: cairo(fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary)),
            ),
          ],
        ]),
      ));
}

class _QtyBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 38, height: 38, alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary)));
}

class _InlineBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _InlineBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 26, height: 26,
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFE0E0E0))),
        alignment: Alignment.center,
        child: Icon(icon, size: 13, color: AppColors.textPrimary)));
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.bg,
            borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.textPrimary)));
}

class _ErrorState extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(message, style: cairo(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]));
}
DART

# =============================================================================
# 18. lib/features/shift/close_shift_screen.dart
#     Fix: inventory validation (warn on 0 stock), submit button always
#          at bottom regardless of column height, discrepancy race condition.
# =============================================================================
write lib/features/shift/close_shift_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/inventory_api.dart';
import '../../core/api/shift_api.dart';
import '../../core/models/inventory.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/label_value.dart';
import '../../core/services/offline_sync_service.dart';

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});
  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<InventoryItem>                   _inv        = [];
  final Map<String, TextEditingController> _ctrs    = {};
  final Map<String, bool>               _zeroWarn   = {};

  bool    _loadingInv  = true;
  bool    _loadingCash = true;
  bool    _submitting  = false;
  String? _error;

  int _systemCash      = 0;
  int _cashDiscrepancy = 0;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_updateDiscrepancy);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSystemCash();
      _loadInventory();
    });
  }

  @override
  void dispose() {
    _cashCtrl.removeListener(_updateDiscrepancy);
    _cashCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _ctrs.values) c.dispose();
    super.dispose();
  }

  void _updateDiscrepancy() {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null) { setState(() => _cashDiscrepancy = 0); return; }
    final declared = (raw * 100).round();
    setState(() => _cashDiscrepancy = declared - _systemCash);
  }

  Future<void> _loadSystemCash() async {
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) { setState(() => _loadingCash = false); return; }
    try {
      final system = await shiftApi.getSystemCash(shift.id, shift.openingCash);
      if (mounted) {
        setState(() { _systemCash = system; _loadingCash = false; });
        _updateDiscrepancy();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCash = false);
    }
  }

  Future<void> _loadInventory() async {
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
              text: i.currentStock.toStringAsFixed(2))
            ..addListener(() => _checkZero(i.id));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingInv = false);
    }
  }

  void _checkZero(String id) {
    final val = double.tryParse(_ctrs[id]?.text ?? '');
    final wasWarn = _zeroWarn[id] ?? false;
    final isWarn  = val == 0.0;
    if (wasWarn != isWarn) setState(() => _zeroWarn[id] = isWarn);
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }
    // Warn if any inventory field is exactly 0 (likely accidentally cleared)
    final zeroItems = _inv.where((i) {
      final v = double.tryParse(_ctrs[i.id]?.text ?? '');
      return v == null || v == 0.0;
    }).map((i) => i.name).toList();

    if (zeroItems.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Zero Stock Warning',
              style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'The following items have 0 stock:\n\n${zeroItems.join(", ")}\n\nAre you sure you want to submit?',
            style: cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Go Back', style: cairo(color: AppColors.primary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Submit Anyway',
                    style: cairo(color: AppColors.danger, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() { _submitting = true; _error = null; });

    final counts = _ctrs.entries.map((e) => {
      'inventory_item_id': e.key,
      'actual_stock':      double.tryParse(e.value.text) ?? 0.0,
    }).toList();

    final ok = await context.read<ShiftProvider>().closeShift(
      closingCash:     (raw * 100).round(),
      note:            _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      inventoryCounts: counts,
    );

    if (mounted) {
      if (ok) { context.go('/home'); }
      else {
        setState(() {
          _error     = context.read<ShiftProvider>().error ?? 'Failed to close shift';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift    = context.watch<ShiftProvider>().shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: Text('Close Shift',
            style: cairo(fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        backgroundColor:    Colors.white,
        elevation:          0,
        surfaceTintColor:   Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0F0F0))),
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : isTablet
              ? _TabletLayout(state: this, shift: shift)
              : _PhoneLayout(state: this, shift: shift),
    );
  }
}

// ── Phone Layout ──────────────────────────────────────────────────────────────
class _PhoneLayout extends StatelessWidget {
  final _CloseShiftScreenState state;
  final dynamic                shift;
  const _PhoneLayout({required this.state, required this.shift});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child:   Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ShiftSummaryCard(shift: shift),
        const SizedBox(height: 16),
        _CashCard(state: state),
        const SizedBox(height: 16),
        _InventoryCard(state: state),
        const SizedBox(height: 16),
        _SubmitSection(state: state),
        const SizedBox(height: 32),
      ]),
    )),
  );
}

// ── Tablet Layout ─────────────────────────────────────────────────────────────
// Submit button is always at the bottom of the SCREEN, not bottom of a column.
class _TabletLayout extends StatelessWidget {
  final _CloseShiftScreenState state;
  final dynamic                shift;
  const _TabletLayout({required this.state, required this.shift});

  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [
          _ShiftSummaryCard(shift: shift),
          const SizedBox(height: 16),
          _CashCard(state: state),
        ])),
        const SizedBox(width: 20),
        Expanded(child: _InventoryCard(state: state)),
      ]),
    )),
    // Submit always pinned at the bottom on tablet
    Container(
      color:   AppColors.bg,
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child:   _SubmitSection(state: state),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARDS (same as before, extracted cleanly)
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftSummaryCard extends StatelessWidget {
  final dynamic shift;
  const _ShiftSummaryCard({required this.shift});
  @override
  Widget build(BuildContext context) => CardContainer(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.summarize_outlined,
              color: AppColors.primary, size: 18)),
        const SizedBox(width: 12),
        Text('Shift Summary', style: cairo(fontSize: 14,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
      const SizedBox(height: 16),
      LabelValue('Teller',       shift.tellerName),
      LabelValue('Opening Cash', egp(shift.openingCash)),
      LabelValue('Opened At',    dateTime(shift.openedAt)),
    ]),
  );
}

class _CashCard extends StatelessWidget {
  final _CloseShiftScreenState state;
  const _CashCard({required this.state});
  @override
  Widget build(BuildContext context) => CardContainer(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.payments_outlined,
              color: AppColors.success, size: 18)),
        const SizedBox(width: 12),
        Text('Cash Count', style: cairo(fontSize: 14,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
      const SizedBox(height: 18),
      // System cash info
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('System Cash', style: cairo(fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Text('Opening + cash orders + movements',
                style: cairo(fontSize: 11, color: AppColors.textMuted)),
          ])),
          state._loadingCash
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : Text(egp(state._systemCash),
                  style: cairo(fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
        ]),
      ),
      const SizedBox(height: 16),
      Text('ACTUAL CASH IN DRAWER',
          style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      TextField(
        controller:    state._cashCtrl,
        keyboardType:  const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        style: cairo(fontSize: 28, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixText:  'EGP  ',
          prefixStyle: cairo(fontSize: 20, color: AppColors.textSecondary),
          hintText:    '0',
          hintStyle:   cairo(fontSize: 28, fontWeight: FontWeight.w800,
              color: AppColors.border),
          border:        InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve:    Curves.easeOut,
        child:    !state._loadingCash && state._cashCtrl.text.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child:   _DiscrepancyRow(
                  discrepancy: state._cashDiscrepancy,
                  systemCash:  state._systemCash))
            : const SizedBox.shrink(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: state._noteCtrl,
        decoration: InputDecoration(
          hintText:   'Cash note (optional)',
          hintStyle:  cairo(fontSize: 14, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.notes_rounded,
              size: 16, color: AppColors.textMuted),
        ),
      ),
    ]),
  );
}

class _InventoryCard extends StatelessWidget {
  final _CloseShiftScreenState state;
  const _InventoryCard({required this.state});
  @override
  Widget build(BuildContext context) => CardContainer(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.inventory_2_outlined,
              color: AppColors.warning, size: 18)),
        const SizedBox(width: 12),
        Text('Inventory Count', style: cairo(fontSize: 14,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
      const SizedBox(height: 16),
      if (state._loadingInv)
        const Center(child: Padding(padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.primary)))
      else if (state._inv.isEmpty)
        Text('No inventory items',
            style: cairo(fontSize: 13, color: AppColors.textMuted))
      else
        ...state._inv.map((item) {
          final warn = state._zeroWarn[item.id] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child:   Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: cairo(fontSize: 14,
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('System: ${item.currentStock} ${item.unit}',
                    style: cairo(fontSize: 12, color: AppColors.textSecondary)),
                if (warn)
                  Text('⚠ Value is 0 — confirm this is correct',
                      style: cairo(fontSize: 11, color: AppColors.warning)),
              ])),
              const SizedBox(width: 12),
              SizedBox(width: 130,
                child: TextField(
                  controller:    state._ctrs[item.id],
                  keyboardType:  const TextInputType.numberWithOptions(decimal: true),
                  textAlign:     TextAlign.center,
                  style:         cairo(fontSize: 14, fontWeight: FontWeight.w600,
                      color: warn ? AppColors.warning : AppColors.textPrimary),
                  decoration:    InputDecoration(
                    suffixText:     item.unit,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: warn ? AppColors.warning : AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2)),
                  ),
                ),
              ),
            ]),
          );
        }),
    ]),
  );
}

class _SubmitSection extends StatelessWidget {
  final _CloseShiftScreenState state;
  const _SubmitSection({required this.state});
  @override
  Widget build(BuildContext context) => Column(children: [
    AnimatedSize(duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      child: state._error != null
          ? Padding(padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color:        AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.danger.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 15, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Flexible(child: Text(state._error!,
                      style: cairo(fontSize: 13, color: AppColors.danger))),
                ]),
              ))
          : const SizedBox.shrink(),
    ),
    Builder(builder: (bCtx) {
      final offline = !bCtx.watch<OfflineSyncService>().isOnline;
      return Column(children: [
        if (offline)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700))),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 14, color: Color(0xFF856404)),
                const SizedBox(width: 8),
                Expanded(child: Text('Internet required to close a shift.',
                    style: cairo(fontSize: 12, color: const Color(0xFF856404)))),
              ]),
            )),
        AppButton(
          label:   'Close Shift',
          variant: BtnVariant.danger,
          loading: state._submitting,
          width:   double.infinity,
          icon:    Icons.lock_outline_rounded,
          onTap:   offline ? null : state._close,
        ),
      ]);
    }),
  ]);
}

class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy;
  final int systemCash;
  const _DiscrepancyRow({required this.discrepancy, required this.systemCash});
  @override
  Widget build(BuildContext context) {
    final isExact = discrepancy == 0;
    final isOver  = discrepancy > 0;
    final color   = isExact ? AppColors.success
        : isOver  ? AppColors.warning : AppColors.danger;
    final icon    = isExact ? Icons.check_circle_rounded
        : isOver  ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label   = isExact ? 'Exact match'
        : isOver  ? 'Over by ${egp(discrepancy.abs())}'
                  : 'Short by ${egp(discrepancy.abs())}';

    return AnimatedContainer(
      duration:  const Duration(milliseconds: 250),
      padding:   const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
            color: color)),
        const Spacer(),
        if (!isExact)
          Text('System: ${egp(systemCash)}',
              style: cairo(fontSize: 11, color: color.withOpacity(0.8))),
      ]),
    );
  }
}
DART

# =============================================================================
# 19. lib/features/order/order_history_screen.dart
#     Fix: mainAxisExtent on grid (was fixed 100, now auto), wide-tablet sheet.
# =============================================================================
write lib/features/order/order_history_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/label_value.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
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
    final history  = context.watch<OrderHistoryProvider>();
    final shift    = context.watch<ShiftProvider>().shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: Text('Order History',
            style: cairo(fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        backgroundColor:  Colors.white,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0F0F0))),
        actions: [
          if (shift != null)
            IconButton(
              icon:    const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () =>
                  context.read<OrderHistoryProvider>().refresh(shift.id),
            ),
        ],
      ),
      body: shift == null
          ? _placeholder('No open shift',
              icon: Icons.lock_outline_rounded, isTablet: isTablet)
          : history.loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary))
              : history.error != null
                  ? Padding(padding: const EdgeInsets.all(24),
                      child: ErrorBanner(
                          message: history.error!, onRetry: _load))
                  : history.orders.isEmpty
                      ? _placeholder('No orders yet for this shift',
                          icon: Icons.receipt_long_outlined,
                          isTablet: isTablet, useLottie: true)
                      : _buildList(history.orders, isTablet),
    );
  }

  Widget _buildList(List<Order> orders, bool isTablet) {
    final total = orders.where((o) => o.status != 'voided')
        .fold(0, (s, o) => s + o.totalAmount);
    final count = orders.where((o) => o.status != 'voided').length;

    return Column(children: [
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16, vertical: 14),
        child: Row(children: [
          _StatChip(label: 'Orders',      value: '$count',   color: AppColors.primary),
          const SizedBox(width: 10),
          _StatChip(label: 'Total Sales', value: egp(total), color: AppColors.success),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),
      Expanded(child: isTablet
          ? _TwoColumnList(orders: orders)
          : ListView.builder(
              padding:     const EdgeInsets.all(16),
              itemCount:   orders.length,
              itemBuilder: (_, i) => _OrderTile(order: orders[i]))),
    ]);
  }

  Widget _placeholder(String msg, {required IconData icon,
      required bool isTablet, bool useLottie = false}) =>
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (useLottie)
          SizedBox(width: isTablet ? 200 : 160, height: isTablet ? 200 : 160,
              child: Lottie.asset('assets/lottie/no_orders.json',
                  fit: BoxFit.contain, repeat: true))
        else ...[
          Icon(icon, size: isTablet ? 56 : 48, color: AppColors.border),
          const SizedBox(height: 12),
        ],
        Text(msg, style: cairo(fontSize: isTablet ? 17 : 15,
            color: AppColors.textSecondary)),
      ]));
}

// ── Two-column list — no fixed mainAxisExtent, cards auto-size ────────────────
class _TwoColumnList extends StatelessWidget {
  final List<Order> orders;
  const _TwoColumnList({required this.orders});
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 520,
      mainAxisSpacing:    10,
      crossAxisSpacing:   10,
      childAspectRatio:   3.8,   // wide cards, height auto-scales with content
    ),
    itemCount:   orders.length,
    itemBuilder: (_, i) => _OrderTile(order: orders[i]),
  );
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: cairo(fontSize: 12, fontWeight: FontWeight.w500,
          color: color.withOpacity(0.8))),
      const SizedBox(width: 8),
      Text(value, style: cairo(fontSize: 14, fontWeight: FontWeight.w800,
          color: color)),
    ]),
  );
}

// ── Order Tile ────────────────────────────────────────────────────────────────
class _OrderTile extends StatefulWidget {
  final Order order;
  const _OrderTile({required this.order});
  @override
  State<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<_OrderTile> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final full = await orderApi.get(widget.order.id);
      if (mounted) { setState(() => _loading = false); _show(full); }
    } catch (_) {
      // Fall back to the summary order we already have
      if (mounted) { setState(() => _loading = false); _show(widget.order); }
    }
  }

  void _show(Order o) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      constraints: isTablet
          ? BoxConstraints(maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.85)
          : null,
      builder: (_) => _OrderDetailSheet(order: o),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o        = widget.order;
    final isVoided = o.status == 'voided';

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration:    const Duration(milliseconds: 150),
        margin:      const EdgeInsets.only(bottom: 8),
        decoration:  BoxDecoration(
          color:        isVoided ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: isVoided
              ? AppColors.border : const Color(0xFFEEEEEE)),
          boxShadow: isVoided ? [] : [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Stack(children: [
          Padding(padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(
                    color:        isVoided ? AppColors.border
                        : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13)),
                alignment: Alignment.center,
                child: Text('#${o.orderNumber}', style: cairo(fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isVoided ? AppColors.textMuted : AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _PaymentBadge(method: o.paymentMethod, voided: isVoided),
                  if (isVoided) ...[const SizedBox(width: 6), _VoidedBadge()],
                  const Spacer(),
                  Text(timeShort(o.createdAt),
                      style: cairo(fontSize: 11, color: AppColors.textMuted)),
                ]),
                const SizedBox(height: 5),
                Text(egp(o.totalAmount), style: cairo(fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isVoided ? AppColors.textMuted : AppColors.textPrimary,
                    decoration: isVoided ? TextDecoration.lineThrough : null)),
                if (o.customerName != null) ...[
                  const SizedBox(height: 2),
                  Text(o.customerName!, style: cairo(fontSize: 11,
                      color: AppColors.textSecondary)),
                ],
              ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
          if (_loading)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary)),
            )),
        ]),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String method; final bool voided;
  const _PaymentBadge({required this.method, required this.voided});
  @override
  Widget build(BuildContext context) {
    final label = method[0].toUpperCase() + method.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color:        voided ? AppColors.borderLight
              : AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
          color: voided ? AppColors.textMuted : AppColors.primary,
          letterSpacing: 0.2)),
    );
  }
}

class _VoidedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text('VOIDED', style: cairo(fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.danger,
          letterSpacing: 0.3)));
}

// ── Order Detail Sheet ────────────────────────────────────────────────────────
class _OrderDetailSheet extends StatefulWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});
  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool    _printing   = false;
  String? _printError;

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter || bp.printerIp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('No printer configured for this branch'),
        backgroundColor: AppColors.warning,
        duration:        Duration(seconds: 3),
      ));
      return;
    }
    setState(() { _printing = true; _printError = null; });
    final err = await PrinterService.print(
        ip: bp.printerIp!, port: bp.printerPort,
        order: widget.order, branchName: bp.branchName);
    if (mounted) setState(() { _printing = false; _printError = err; });
  }

  @override
  Widget build(BuildContext context) {
    final order    = widget.order;
    final isVoided = order.status == 'voided';

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.only(top: 12),
          child: Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2))))),
        Padding(padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${order.orderNumber}',
                  style: cairo(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(dateTime(order.createdAt),
                  style: cairo(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            if (!isVoided)
              _printing
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : GestureDetector(
                      onTap: _print,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: (_printError != null
                                ? AppColors.danger : AppColors.primary)
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.print_rounded, size: 15,
                              color: _printError != null
                                  ? AppColors.danger : AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_printError != null ? 'Retry' : 'Print',
                              style: cairo(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _printError != null
                                      ? AppColors.danger : AppColors.primary)),
                        ]),
                      )),
            if (isVoided)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color:        AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('VOIDED', style: cairo(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.danger,
                    letterSpacing: 0.4)),
              ),
          ])),
        const Divider(height: 1, color: AppColors.border),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (order.items.isEmpty)
              Text('No item details available',
                  style: cairo(fontSize: 13, color: AppColors.textMuted))
            else
              ...order.items.map((item) => _ItemRow(item: item)),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            LabelValue('Subtotal', egp(order.subtotal)),
            if (order.discountAmount > 0)
              LabelValue('Discount', '− ${egp(order.discountAmount)}',
                  valueColor: AppColors.success),
            if (order.taxAmount > 0)
              LabelValue('Tax', egp(order.taxAmount)),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: cairo(fontSize: 15,
                      fontWeight: FontWeight.w800)),
                  Text(egp(order.totalAmount), style: cairo(fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isVoided ? AppColors.textMuted : AppColors.primary,
                      decoration: isVoided ? TextDecoration.lineThrough : null)),
                ])),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            LabelValue('Payment', order.paymentMethod[0].toUpperCase() +
                order.paymentMethod.substring(1)),
            if (order.customerName != null)
              LabelValue('Customer', order.customerName!),
            if (order.tellerName.isNotEmpty)
              LabelValue('Teller', order.tellerName),
            LabelValue('Time', timeShort(order.createdAt)),
          ],
        )),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child:   Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text('${item.quantity}', style: cairo(fontSize: 12,
            fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.itemName + (item.sizeLabel != null
            ? ' · ${item.sizeLabel}' : ''),
            style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
        if (item.addons.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 4, runSpacing: 4,
              children: item.addons.map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color:        AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(
                    a.unitPrice > 0
                        ? '${a.addonName} +${egp(a.unitPrice)}'
                        : a.addonName,
                    style: cairo(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              )).toList()),
        ],
      ])),
      const SizedBox(width: 12),
      Text(egp(item.lineTotal),
          style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );
}
DART

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "✅  All files patched successfully."
echo ""
echo "⚠️   One manual step required:"
echo "    Add  'uuid: ^4.0.0'  to your pubspec.yaml dependencies"
echo "    (used for idempotency keys in offline order queuing)."
echo ""
echo "    Then run:  flutter pub get"
echo "    Then run:  flutter run"
echo ""
echo "Summary of changes:"
echo "  • lib/core/utils/formatting.dart          — added normaliseName()"
echo "  • lib/core/models/pending_order.dart       — fixed toJson/fromJson (item names, prices)"
echo "  • lib/core/api/client.dart                 — 401 interceptor, sendTimeout, error helper"
echo "  • lib/core/api/order_api.dart              — idempotency key, canonical orderToJson"
echo "  • lib/core/providers/branch_provider.dart  — offline cache for branch/printer data"
echo "  • lib/core/providers/auth_provider.dart    — offline-safe init (no logout on network error)"
echo "  • lib/core/providers/cart_provider.dart    — correct addon equality merge"
echo "  • lib/core/providers/menu_provider.dart    — parallel fetch, smarter reload guard"
echo "  • lib/core/providers/order_history_provider.dart — uses canonical orderToJson"
echo "  • lib/core/services/offline_sync_service.dart — skip stuck orders, idempotency, callbacks"
echo "  • lib/main.dart                            — wires sync→history, logo splash, error handler"
echo "  • lib/shared/widgets/app_button.dart       — Cairo font, press-scale animation"
echo "  • lib/shared/widgets/label_value.dart      — Cairo font"
echo "  • lib/shared/widgets/error_banner.dart     — Cairo font"
echo "  • lib/shared/widgets/pin_pad.dart          — Cairo font, adaptive key size"
echo "  • lib/features/home/home_screen.dart       — typed shift, no direct API, cache banners"
echo "  • lib/features/order/order_screen.dart     — mobile FAB cart, offline checkout, adaptive grid"
echo "  • lib/features/shift/close_shift_screen.dart — inventory zero-warn, tablet submit pinned"
echo "  • lib/features/order/order_history_screen.dart — auto-height grid, proper tablet sheet"
DART