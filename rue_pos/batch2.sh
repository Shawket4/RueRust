#!/bin/bash

echo "Writing lib/core/providers/auth_notifier.dart..."
cat << 'EOF' > lib/core/providers/auth_notifier.dart
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
  final bool isLoading;
  final User? user;
  final Branch? branch;
  final String? error;
  final SessionExpiry sessionExpiry;
  final String? blockedByName;

  const AuthState({
    this.isLoading = true,
    this.user,
    this.branch,
    this.error,
    this.sessionExpiry = SessionExpiry.none,
    this.blockedByName,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    User? user,
    Branch? branch,
    String? error,
    SessionExpiry? sessionExpiry,
    String? blockedByName,
    bool clearUser = false,
    bool clearBranch = false,
    bool clearError = false,
    bool clearBlocked = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        user: clearUser ? null : (user ?? this.user),
        branch: clearBranch ? null : (branch ?? this.branch),
        error: clearError ? null : (error ?? this.error),
        sessionExpiry: sessionExpiry ?? this.sessionExpiry,
        blockedByName:
            clearBlocked ? null : (blockedByName ?? this.blockedByName),
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    onUnauthorizedCallback = () {
      if (state.user != null) {
        _forceLogout(expiry: SessionExpiry.expired);
      }
    };
    Future.microtask(init);
    return const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true); // Task 1.8

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final session = await ref.read(authRepositoryProvider).restoreSession();
    if (session == null) {
      state = const AuthState(isLoading: false);
      return;
    }
    await _hydrateAfterAuth(session.user, emitLoading: false);
  }

  Future<String?> login({required String name, required String pin}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearBlocked: true,
      sessionExpiry: SessionExpiry.none,
    );
    try {
      final session =
          await ref.read(authRepositoryProvider).login(name: name, pin: pin);
      final blockError =
          await _hydrateAfterAuth(session.user, emitLoading: true);
      return blockError;
    } catch (e) {
      final msg = friendlyError(e); // Task 4.2
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  Future<String?> _hydrateAfterAuth(User user,
      {required bool emitLoading}) async {
    if (emitLoading) state = state.copyWith(isLoading: true);

    Branch? branch;
    if (user.branchId != null) {
      try {
        branch = await ref.read(branchApiProvider).get(user.branchId!);
        await ref
            .read(storageServiceProvider)
            .saveBranch(user.branchId!, branch.toJson());
      } catch (_) {
        final cached =
            ref.read(storageServiceProvider).loadBranch(user.branchId!);
        if (cached != null) branch = Branch.fromJson(cached);
      }
    }

    if (user.branchId != null) {
      try {
        final preFill =
            await ref.read(shiftApiProvider).current(user.branchId!);
        final openShift = preFill.openShift;

        if (openShift != null &&
            openShift.isOpen &&
            openShift.tellerId != user.id) {
          await ref.read(authRepositoryProvider).logout();
          final msg = 'Branch has an open shift belonging to '
              '"${openShift.tellerName}". '
              'That shift must be closed before anyone else can sign in.';
          state = AuthState(
            isLoading: false,
            sessionExpiry: SessionExpiry.blockedByOtherShift,
            blockedByName: openShift.tellerName,
            error: msg,
          );
          return msg;
        }

        if (openShift != null) {
          await ref
              .read(storageServiceProvider)
              .saveShift(user.branchId!, openShift.toJson());
        }
      } catch (_) {
        // Network error during shift check — allow login
      }
    }

    state = state.copyWith(
      isLoading: false,
      user: user,
      branch: branch,
      clearError: true,
      clearBlocked: true,
      sessionExpiry: SessionExpiry.none,
    );
    return null;
  }

  Future<bool> canLogout() async {
    final branchId = state.user?.branchId;
    if (branchId == null) return true;
    try {
      final preFill = await ref.read(shiftApiProvider).current(branchId);
      return !(preFill.openShift?.isOpen ?? false);
    } catch (_) {
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

  // Task 1.7: Await logout
  Future<void> _forceLogout({required SessionExpiry expiry}) async {
    await ref.read(authRepositoryProvider).logout();
    state = AuthState(isLoading: false, sessionExpiry: expiry);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
EOF

echo "Writing lib/core/providers/cart_notifier.dart..."
cat << 'EOF' > lib/core/providers/cart_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';

class CartNotifier extends Notifier<CartState> {
  CartItem? _lastRemovedItem;
  int? _lastRemovedIndex;

  @override
  CartState build() => CartState.empty;

  void add(CartItem incoming) {
    final idx = state.items.indexWhere((i) =>
        i.menuItemId == incoming.menuItemId &&
        i.sizeLabel  == incoming.sizeLabel &&
        CartItem.addonsMatch(i.addons, incoming.addons) &&
        CartItem.optionalsMatch(i.optionals, incoming.optionals));

    if (idx >= 0) {
      final updated = List<CartItem>.of(state.items);
      updated[idx] = updated[idx]
          .copyWith(quantity: updated[idx].quantity + incoming.quantity);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, incoming]);
    }
  }

  void removeAt(int index) {
    _lastRemovedItem = state.items[index];
    _lastRemovedIndex = index;
    final updated = List<CartItem>.of(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  // Task 3.6: Restore method
  void restoreLastRemoved() {
    if (_lastRemovedItem == null || _lastRemovedIndex == null) return;
    
    final safeIndex = _lastRemovedIndex!.clamp(0, state.items.length);
    final updated = List<CartItem>.of(state.items)..insert(safeIndex, _lastRemovedItem!);
    state = state.copyWith(items: updated);
    
    _lastRemovedItem = null;
    _lastRemovedIndex = null;
  }

  void setQty(int index, int qty) {
    if (qty <= 0) { removeAt(index); return; }
    final updated = List<CartItem>.of(state.items);
    updated[index] = updated[index].copyWith(quantity: qty);
    state = state.copyWith(items: updated);
  }

  void replaceAt(int index, CartItem incoming) {
    final updated = List<CartItem>.of(state.items);
    updated[index] = incoming;
    state = state.copyWith(items: updated);
  }

  void setPayment(String m) =>
      state = state.copyWith(payment: m, clearSplits: true);

  void setCustomer(String? n) =>
      state = state.copyWith(customerName: n, clearCustomer: n == null);

  void setNotes(String? n) => state = state.copyWith(notes: n);

  void setDiscount(DiscountType? type, int? value) => state = type == null
      ? state.copyWith(clearDiscount: true, clearDiscountId: true)
      : state.copyWith(
          discountType: type, discountValue: value, clearDiscountId: true);

  void setDiscountById(String id, DiscountType type, int value) => state =
      state.copyWith(discountId: id, discountType: type, discountValue: value);

  void clearDiscount() =>
      state = state.copyWith(clearDiscount: true, clearDiscountId: true);

  void setAmountTendered(int? amount) => state =
      state.copyWith(amountTendered: amount, clearTendered: amount == null);

  void setTip(int? tip) => state = state.copyWith(tipAmount: tip);

  void setPaymentSplits(List<PaymentSplit> splits) {
    final method = splits.length == 1 ? splits.first.method : 'mixed';
    state = state.copyWith(paymentSplits: splits, payment: method);
  }

  void clearSplits() =>
      state = state.copyWith(clearSplits: true, payment: 'cash');

  void clear() {
    _lastRemovedItem = null;
    _lastRemovedIndex = null;
    state = CartState.empty;
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
EOF

echo "Writing lib/core/providers/order_history_notifier.dart..."
cat << 'EOF' > lib/core/providers/order_history_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';

class OrderHistoryState {
  final List<Order> orders;
  final bool isLoading;
  final bool fromCache;
  final String? error;
  final String? shiftId;

  const OrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.fromCache = false,
    this.error,
    this.shiftId,
  });

  OrderHistoryState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? fromCache,
    String? error,
    String? shiftId,
    bool clearError = false,
  }) =>
      OrderHistoryState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        fromCache: fromCache ?? this.fromCache,
        error: clearError ? null : (error ?? this.error),
        shiftId: shiftId ?? this.shiftId,
      );
}

class OrderHistoryNotifier extends Notifier<OrderHistoryState> {
  @override
  OrderHistoryState build() => const OrderHistoryState();

  Future<void> loadForShift(String shiftId, {bool force = false}) async {
    if (!force && state.shiftId == shiftId && state.orders.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders =
          await ref.read(orderRepositoryProvider).listForShift(shiftId);
      state = state.copyWith(
          isLoading: false, orders: orders, shiftId: shiftId, fromCache: false);
    } catch (_) {
      state = state.copyWith(
          isLoading: false,
          fromCache: true,
          error: 'Could not load orders — check connection');
    }
  }

  Future<void> refresh(String shiftId) => loadForShift(shiftId, force: true);

  void addOrder(Order order) {
    if (state.orders.any((o) => o.id == order.id)) return;
    final updated = [order, ...state.orders];
    state = state.copyWith(orders: updated);
    if (state.shiftId != null) {
      // Task 1.1: Pass the updated list directly, let repository save it without prepending
      ref
          .read(orderRepositoryProvider)
          .saveOrdersToCache(state.shiftId!, updated);
    }
  }

  // Task 1.5: Replace optimistic order
  void replaceOrder(String localId, Order synced) {
    final idx = state.orders.indexWhere((o) => o.id == localId);
    if (idx >= 0) {
      final updated = List<Order>.of(state.orders);
      updated[idx] = synced;
      state = state.copyWith(orders: updated);
      if (state.shiftId != null) {
        ref.read(orderRepositoryProvider).saveOrdersToCache(state.shiftId!, updated);
      }
    } else {
      addOrder(synced);
    }
  }

  void updateOrder(Order updated) {
    final newOrders = state.orders.map((o) => o.id == updated.id ? updated : o).toList();
    state = state.copyWith(orders: newOrders);
    if (state.shiftId != null) {
        ref.read(orderRepositoryProvider).saveOrdersToCache(state.shiftId!, newOrders);
    }
  }

  void clear() => state = const OrderHistoryState();
}

final orderHistoryProvider =
    NotifierProvider<OrderHistoryNotifier, OrderHistoryState>(
        OrderHistoryNotifier.new);
EOF

echo "Writing lib/core/providers/shift_notifier.dart..."
cat << 'EOF' > lib/core/providers/shift_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../api/client.dart';
import '../models/inventory.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../repositories/shift_repository.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue.dart';
import '../storage/storage_service.dart';
import 'auth_notifier.dart';

class ShiftState {
  final bool               isLoading;
  final Shift?             shift;
  final int                suggestedOpeningCash;
  final List<InventoryItem> inventory;
  final int                systemCash;
  final bool               systemCashLoading;
  final String?            error;
  final bool               fromCache;
  final bool               isLocalShift;

  const ShiftState({
    this.isLoading            = false,
    this.shift,
    this.suggestedOpeningCash = 0,
    this.inventory            = const [],
    this.systemCash           = 0,
    this.systemCashLoading    = false,
    this.error,
    this.fromCache            = false,
    this.isLocalShift         = false,
  });

  bool get hasOpenShift => shift?.isOpen ?? false;

  ShiftState copyWith({
    bool?               isLoading,
    Shift?              shift,
    int?                suggestedOpeningCash,
    List<InventoryItem>? inventory,
    int?                systemCash,
    bool?               systemCashLoading,
    String?             error,
    bool?               fromCache,
    bool?               isLocalShift,
    bool                clearShift = false,
    bool                clearError = false,
  }) => ShiftState(
    isLoading:            isLoading            ?? this.isLoading,
    shift:                clearShift ? null    : (shift ?? this.shift),
    suggestedOpeningCash: suggestedOpeningCash ?? this.suggestedOpeningCash,
    inventory:            inventory            ?? this.inventory,
    systemCash:           systemCash           ?? this.systemCash,
    systemCashLoading:    systemCashLoading    ?? this.systemCashLoading,
    error:                clearError ? null    : (error ?? this.error),
    fromCache:            fromCache            ?? this.fromCache,
    isLocalShift:         isLocalShift         ?? this.isLocalShift,
  );
}

class ShiftNotifier extends Notifier<ShiftState> {
  @override
  ShiftState build() => const ShiftState();

  Future<void> load(String branchId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preFill = await ref.read(shiftRepositoryProvider)
          .currentShift(branchId);
      state = state.copyWith(
        isLoading:            false,
        shift:                preFill.openShift,
        suggestedOpeningCash: preFill.suggestedOpeningCash,
        fromCache:            false,
        isLocalShift:         false,
        clearShift:           preFill.openShift == null,
      );
    } catch (_) {
      final cached = ref.read(storageServiceProvider).loadShift(branchId);
      if (cached != null) {
        state = state.copyWith(
          isLoading: false, fromCache: true,
          shift: Shift.fromJson(cached),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load shift — check connection',
        );
      }
    }
  }

  Future<bool> openShift(String branchId, int openingCash) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final isOnline = ConnectivityService.instance.isOnline;

    if (isOnline) {
      try {
        final shift = await ref.read(shiftRepositoryProvider)
            .openShift(branchId, openingCash);
        state = state.copyWith(
            isLoading: false, shift: shift, isLocalShift: false);
        return true;
      } catch (e) {
        state = state.copyWith(isLoading: false, error: friendlyError(e)); // Task 4.2
        return false;
      }
    }

    // ── OFFLINE ──────────────────────────────────────────────
    // Task 1.3: Stamp offline shifts
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = state.copyWith(isLoading: false, error: 'User not authenticated');
      return false;
    }

    final shiftId  = const Uuid().v4();
    final now      = DateTime.now();
    final localShift = Shift(
      id:           shiftId,
      branchId:     branchId,
      tellerId:     user.id,
      tellerName:   user.name,
      status:       'open',
      openingCash:  openingCash,
      openedAt:     now,
    );

    await ref.read(storageServiceProvider)
        .saveShift(branchId, localShift.toJson());

    await ref.read(offlineQueueProvider.notifier).enqueueShiftOpen(
      PendingShiftOpen(
        localId:     const Uuid().v4(),
        createdAt:   now,
        branchId:    branchId,
        shiftId:     shiftId,
        openingCash: openingCash,
        openedAt:    now,
      ),
    );

    state = state.copyWith(
        isLoading: false, shift: localShift, isLocalShift: true);
    return true;
  }

  Future<bool> closeShift({
    required String branchId,
    required int    closingCash,
    String?         note,
    required List<Map<String, dynamic>> inventoryCounts,
  }) async {
    if (state.shift == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    
    // Task 2.1: strictly online action
    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      state = state.copyWith(isLoading: false, error: 'Internet required to close shift');
      return false;
    }

    final shiftId  = state.shift!.id;

    try {
      await ref.read(shiftRepositoryProvider).closeShift(
        shiftId,
        branchId:        branchId,
        closingCash:     closingCash,
        note:            note,
        inventoryCounts: inventoryCounts,
      );
      await ref.read(storageServiceProvider).removeShift(branchId);
      state = state.copyWith(
          isLoading: false, clearShift: true, systemCash: 0);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e)); // Task 4.2
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
    final items = await ref.read(shiftRepositoryProvider)
        .getInventory(branchId);
    state = state.copyWith(inventory: items);
  }
}

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftState>(ShiftNotifier.new);
EOF

echo "Writing lib/core/repositories/order_repository.dart..."
cat << 'EOF' > lib/core/repositories/order_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../models/cart.dart';
import '../models/order.dart';
import '../storage/storage_service.dart';

class OrderRepository {
  final OrderApi _api;
  final StorageService _storage;
  OrderRepository(this._api, this._storage);

  Future<Order> create({
    required String branchId,
    required String shiftId,
    required CartState cart,
    required String idempotencyKey,
  }) =>
      _api.create(
        branchId: branchId,
        shiftId: shiftId,
        paymentMethod: cart.payment,
        items: cart.items,
        customerName: cart.customerName,
        discountType: cart.discountType?.apiValue,
        discountValue: cart.discountValue,
        idempotencyKey: idempotencyKey,
      );

  Future<List<Order>> listForShift(String shiftId) async {
    try {
      final orders = await _api.list(shiftId: shiftId);
      await _storage.saveOrders(
          shiftId, orders.map((o) => o.toJson()).toList());
      return orders;
    } catch (_) {
      final cached = _storage.loadOrders(shiftId);
      if (cached != null) return cached.map(Order.fromJson).toList();
      rethrow;
    }
  }

  Future<Order> get(String id) => _api.get(id);

  // Task 1.2: Remove force unwrapping on reason
  Future<Order> voidOrder(String id,
          {String? reason, bool restoreInventory = false}) =>
      _api.voidOrder(id, reason: reason ?? 'No reason provided', restoreInventory: restoreInventory);

  // Task 1.1: Replace append with save since the notifier handles the list merging
  void saveOrdersToCache(String shiftId, List<Order> current) {
    _storage.saveOrders(shiftId, current.map((o) => o.toJson()).toList());
  }
}

final orderRepositoryProvider =
    Provider<OrderRepository>((ref) => OrderRepository(
          ref.watch(orderApiProvider),
          ref.watch(storageServiceProvider),
        ));
EOF

echo "Writing lib/main.dart..."
cat << 'EOF' > lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/auth_notifier.dart';
import 'core/providers/order_history_notifier.dart';
import 'core/providers/shift_notifier.dart';
import 'core/router/router.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_queue.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  await ConnectivityService.instance.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(StorageService(prefs)),
    ],
    child: const _App(),
  ));
}

class _App extends ConsumerStatefulWidget {
  const _App();
  @override
  ConsumerState<_App> createState() => _AppState();
}

class _AppState extends ConsumerState<_App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queue        = ref.read(offlineQueueProvider.notifier);
      final history      = ref.read(orderHistoryProvider.notifier);
      final shiftNotif   = ref.read(shiftProvider.notifier);

      // Task 1.5: Wire up optimistic replacement
      queue.onOrderSynced      = (order, localId) => history.replaceOrder(localId, order);
      queue.onVoidSynced       = history.updateOrder;
      queue.onShiftOpenSynced  = (shift) {
        final current = ref.read(shiftProvider).shift;
        if (current != null && current.id == shift.id) {
          shiftNotif.state = shiftNotif.state.copyWith(
            shift:        shift,
            isLocalShift: false,
          );
        }
      };
      queue.onShiftCloseSynced = (_) {};

      queue.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final router = ref.watch(routerProvider);

    if (auth.isLoading) return const _SplashScreen();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Rue POS',
      theme: AppTheme.light,
      routerConfig: router,
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
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/TheRue.png', height: 64),
        const SizedBox(height: 32),
        const SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary)),
      ])),
    ),
  );
}
EOF

echo "Writing lib/features/auth/login_screen.dart..."
cat << 'EOF' > lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pin_pad.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  String _pin = '';
  bool _loading = false;
  static const _max = 6;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  void _digit(String d) {
    if (_loading || _pin.length >= _max) return;
    setState(() => _pin += d);
    // Task 1.8: clearError helper
    if (ref.read(authProvider).error != null) {
      ref.read(authProvider.notifier).clearError();
    }
    if (_pin.length == _max) _submit();
  }

  void _back() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _shakeCtrl.forward(from: 0);
      setState(() => _pin = '');
      ref.read(authProvider.notifier).state =
          ref.read(authProvider).copyWith(error: 'Please enter your name');
      return;
    }
    if (_pin.length < 4) return;

    setState(() => _loading = true);

    final err =
        await ref.read(authProvider.notifier).login(name: name, pin: _pin);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _pin = '';
    });

    if (err != null) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiry = ref.watch(authProvider.select((s) => s.sessionExpiry));
    final blockedBy = ref.watch(authProvider.select((s) => s.blockedByName));
    final authError = ref.watch(authProvider.select((s) => s.error));
    // Task 3.7: Device-type based sizing
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final displayError = expiry == SessionExpiry.blockedByOtherShift
        ? null
        : authError;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isTablet
          ? _TabletLayout(
              form: _buildForm(
              expiry: expiry,
              blockedBy: blockedBy,
              displayError: displayError,
            ))
          : _buildForm(
              expiry: expiry,
              blockedBy: blockedBy,
              displayError: displayError,
            ),
    );
  }

  Widget _buildForm({
    required SessionExpiry expiry,
    required String? blockedBy,
    required String? displayError,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/TheRue.png', height: 48),
            const SizedBox(height: 8),
            Text(
              'Point of Sale',
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1.6),
            ),
            const SizedBox(height: 32),

            if (expiry == SessionExpiry.expired)
              _InfoBanner(
                icon: Icons.lock_clock_outlined,
                text: 'Your session expired — please sign in again.',
                color: AppColors.warning,
              ),

            if (expiry == SessionExpiry.blockedByOtherShift &&
                blockedBy != null)
              _InfoBanner(
                icon: Icons.block_rounded,
                text: 'Branch has an open shift belonging to "$blockedBy". '
                    'They must close it before you can sign in.',
                color: AppColors.danger,
                bold: true,
              ),

            Row(children: [
              const Expanded(child: Divider(color: AppColors.borderLight)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Sign in',
                    style: cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.6)),
              ),
              const Expanded(child: Divider(color: AppColors.borderLight)),
            ]),
            const SizedBox(height: 24),

            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0), child: child),
              child: TextField(
                controller: _nameCtrl,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  // Task 1.8: clearError
                  if (ref.read(authProvider).error != null) {
                    ref.read(authProvider.notifier).clearError();
                  }
                },
                style: cairo(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 32),

            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0), child: child),
              child: PinPad(
                pin: _pin,
                maxLength: _max,
                onDigit: _digit,
                onBackspace: _back,
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: displayError != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                              color: AppColors.danger.withOpacity(0.18)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 15, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(displayError,
                                  style: cairo(
                                      fontSize: 13, color: AppColors.danger))),
                        ]),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            if (_loading) ...[
              const SizedBox(height: 28),
              const CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ],
          ]),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: cairo(
                      fontSize: 13,
                      color: color,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      height: 1.4))),
        ]),
      );
}

class _TabletLayout extends StatelessWidget {
  final Widget form;
  const _TabletLayout({required this.form});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(52),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/TheRue.png',
                        height: 56,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn),
                    const SizedBox(height: 40),
                    Text('Welcome\nback.',
                        style: cairo(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Text('Sign in to start your shift\nand manage orders.',
                        style: cairo(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.72),
                            height: 1.65)),
                    const SizedBox(height: 48),
                    Row(children: [
                      _Dot(AppColors.surface.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      _Dot(AppColors.surface.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      _Dot(AppColors.surface.withOpacity(0.15)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(color: Colors.white, child: form),
        ),
      ]);
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
EOF

echo "Writing lib/features/home/home_screen.dart..."
cat << 'EOF' > lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/shift.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/order_history_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../shift/cash_movement_sheet.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/sync_status_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) return;
    await ref.read(shiftProvider.notifier).load(branchId);
    final shift = ref.read(shiftProvider).shift;
    if (shift != null) {
      await ref.read(orderHistoryProvider.notifier).loadForShift(shift.id);
      await ref.read(shiftProvider.notifier).loadSystemCash();
    }
  }

  Future<void> _onSignOut() async {
    final canLeave = await ref.read(authProvider.notifier).canLogout();
    if (!mounted) return;
    if (canLeave) {
      await ref.read(authProvider.notifier).logout();
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Close Shift First',
              style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'You have an open shift. You must close it before signing out.',
            style: cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: cairo(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/close-shift');
              },
              child: Text('Close Shift',
                  style: cairo(
                      color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final shiftSt = ref.watch(shiftProvider);
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 36 : 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Image.asset('assets/TheRue.png', height: isTablet ? 52 : 44),
              const Spacer(),
              Text(user.name,
                  style: cairo(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              _SignOutBtn(onTap: _onSignOut),
            ]),
            SizedBox(height: isTablet ? 36 : 28),
            Text(_greet(user.name.split(' ').first),
                style: cairo(
                    fontSize: isTablet ? 28 : 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(user.role.replaceAll('_', ' ').toUpperCase(),
                style: cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1)),
            SizedBox(height: isTablet ? 32 : 24),
            if (shiftSt.isLoading)
              const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
            else if (shiftSt.error != null && !shiftSt.hasOpenShift)
              _ErrorBanner(message: shiftSt.error!, onRetry: _load)
            else if (shiftSt.hasOpenShift)
              _OpenShiftView(
                  shift: shiftSt.shift!,
                  shiftState: shiftSt,
                  onRefresh: _load,
                  isTablet: isTablet)
            else
              _NoShiftView(
                  suggested: shiftSt.suggestedOpeningCash, isTablet: isTablet),
          ]),
        ),
      ),
    );
  }

  String _greet(String first) {
    final h = DateTime.now().hour;
    final w = h < 12
        ? 'Morning'
        : h < 17
            ? 'Afternoon'
            : 'Evening';
    return 'Good $w, $first';
  }
}

class _OpenShiftView extends ConsumerWidget {
  final Shift shift;
  final ShiftState shiftState;
  final VoidCallback onRefresh;
  final bool isTablet;

  const _OpenShiftView(
      {required this.shift,
      required this.shiftState,
      required this.onRefresh,
      required this.isTablet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(offlineQueueProvider);
    final history = ref.watch(orderHistoryProvider);
    final isOnline = ref.watch(isOnlineProvider);

    final active = history.orders.where((o) => o.status != 'voided').toList();
    final orderCount = active.length;
    final salesTotal = active.fold(0, (s, o) => s + o.totalAmount);
    final statsReady = !shiftState.systemCashLoading;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 30 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Task 3.1: Use shared banner
          if (!isOnline)
            const SyncStatusBanner(
              variant: SyncBannerVariant.offline,
              text: 'Offline — cached data shown. Orders queue until online.'
            ),
          if (isOnline && history.fromCache)
            const SyncStatusBanner(
              variant: SyncBannerVariant.offline,
              text: 'Showing cached stats — tap refresh to update.'
            ),
          if (isOnline && sync.orderCount > 0)
            SyncStatusBanner(
              variant: SyncBannerVariant.syncing,
              text: 'Syncing ${sync.orderCount} offline order${sync.orderCount == 1 ? "" : "s"}…'
            ),
          if (sync.hasStuck)
            SyncStatusBanner(
              variant: SyncBannerVariant.stuck,
              text: '${sync.stuckCount} order${sync.stuckCount == 1 ? "" : "s"} failed to sync — check connection or discard.'
            ),
            
          Row(children: [
            _StatusPill(),
            const Spacer(),
            Text('Since ${timeShort(shift.openedAt)}',
                style: cairo(fontSize: 11, color: Colors.white60)),
            const SizedBox(width: 8),
            GestureDetector(
                onTap: onRefresh,
                child: const Icon(Icons.refresh_rounded,
                    size: 16, color: Colors.white54)),
          ]),
          SizedBox(height: isTablet ? 26 : 20),
          Row(children: [
            _ShiftStat(
                label: 'Sales',
                value: egp(salesTotal),
                loading: !statsReady,
                isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(
                label: 'Orders',
                value: '$orderCount',
                loading: !statsReady,
                isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(
                label: 'System Cash',
                value: egp(shiftState.systemCash),
                sublabel: '${egp(shift.openingCash)} opening',
                loading: shiftState.systemCashLoading,
                isTablet: isTablet),
          ]),
          SizedBox(height: isTablet ? 28 : 22),
          Row(children: [
            Expanded(
                child: _CardBtn(
                    label: 'New Order',
                    icon: Icons.add_shopping_cart_rounded,
                    onTap: () => context.go('/order'),
                    isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
                    label: 'History',
                    icon: Icons.receipt_long_rounded,
                    onTap: () => context.go('/order-history'),
                    isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
                    label: 'Shifts',
                    icon: Icons.history_rounded,
                    onTap: () => context.go('/shift-history'),
                    isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
              label: 'Pending',
              icon: Icons.pending_actions_rounded,
              onTap: () => context.go('/pending-orders'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
              label: 'Cash',
              icon: Icons.payments_outlined,
              isTablet: isTablet,
              onTap: () => CashMovementSheet.show(
                context,
                shiftId: shift.id,
                onSuccess: onRefresh,
              ))), // Task 2.3: Remove tooltip/disabled check so offline works
            const SizedBox(width: 8),
            Expanded(
                // Task 2.4: Added Tooltip 
                child: Tooltip(
                  message: !isOnline ? 'Internet connection required to close shift.' : '',
                  child: _CardBtn(
                                label: 'Close',
                                icon: Icons.lock_outline_rounded,
                                danger: true,
                                isTablet: isTablet,
                                disabled: !isOnline,
                                onTap: !isOnline
                                    ? () {}
                                    : () => _confirmClose(context),
                              ),
                )),
          ]),
        ]),
      ),
    ]);
  }

  void _confirmClose(BuildContext context) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              Text('Close Shift?', style: cairo(fontWeight: FontWeight.w800)),
          content: Text('You will count cash and inventory on the next screen.',
              style: cairo(fontSize: 14, color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: cairo(color: AppColors.textSecondary))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/close-shift');
              },
              child: Text('Continue',
                  style: cairo(
                      color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _NoShiftView extends StatelessWidget {
  final int suggested;
  final bool isTablet;
  const _NoShiftView({required this.suggested, required this.isTablet});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
            child: CardContainer(
              padding: EdgeInsets.all(isTablet ? 28 : 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.wb_sunny_outlined,
                              color: AppColors.primary, size: 22)),
                      const SizedBox(width: 14),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No Open Shift',
                                style: cairo(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w700)),
                            if (suggested > 0)
                              Text('Last closing: ${egp(suggested)}',
                                  style: cairo(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ]),
                    ]),
                    const SizedBox(height: 22),
                    AppButton(
                        label: 'Open Shift',
                        width: double.infinity,
                        icon: Icons.play_arrow_rounded,
                        onTap: () => context.go('/open-shift')),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/shift-history'),
              icon: const Icon(Icons.history_rounded, size: 16),
              label: Text('View Shift History', style: cairo(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
}

class _SignOutBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: const Icon(Icons.logout_rounded,
              size: 15, color: AppColors.textSecondary),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('SHIFT OPEN',
              style: cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.8)),
        ]),
      );
}

class _ShiftStat extends StatelessWidget {
  final String label, value;
  final String? sublabel;
  final bool loading, isTablet;
  const _ShiftStat(
      {required this.label,
      required this.value,
      this.sublabel,
      this.loading = false,
      this.isTablet = false});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: cairo(
                  fontSize: 11,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          loading
              ? Container(
                  width: 50,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4)))
              : Text(value,
                  style: cairo(
                      fontSize: isTablet ? 20 : 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
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
        width: 1,
        height: 44,
        color: Colors.white.withOpacity(0.15),
        margin: const EdgeInsets.symmetric(horizontal: 14),
      );
}

class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger, isTablet, disabled;
  const _CardBtn(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.danger = false,
      this.isTablet = false,
      this.disabled = false});
  @override
  Widget build(BuildContext context) {
    final bgColor = disabled 
        ? Colors.white.withOpacity(0.4) 
        : danger 
            ? Colors.white.withOpacity(0.12) 
            : Colors.white;
    final fgColor = disabled 
        ? Colors.black38
        : danger 
            ? Colors.white 
            : AppColors.primary;

    return GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 11),
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: isTablet ? 18 : 16,
                color: fgColor),
            const SizedBox(height: 4),
            Text(label,
                style: cairo(
                    fontSize: isTablet ? 12 : 11,
                    fontWeight: FontWeight.w700,
                    color: fgColor)),
          ]),
        ),
      );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: cairo(fontSize: 13, color: AppColors.danger))),
          TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary))),
        ]),
      );
}
EOF

echo "Writing lib/features/shift/open_shift_screen.dart..."
cat << 'EOF' > lib/features/shift/open_shift_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';

class OpenShiftScreen extends ConsumerStatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  ConsumerState<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends ConsumerState<OpenShiftScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(shiftProvider).suggestedOpeningCash;
      if (s > 0) _ctrl.text = (s / 100).toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final raw = double.tryParse(_ctrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid cash amount');
      return;
    }
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) {
      setState(() => _error = 'No branch assigned to your account');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await ref
        .read(shiftProvider.notifier)
        .openShift(branchId, (raw * 100).round());

    if (mounted) {
      if (ok) {
        context.go('/home');
      } else {
        setState(() {
          _error = ref.read(shiftProvider).error ?? 'Failed to open shift';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final isOnline = ref.watch(isOnlineProvider);
    final suggested =
        ref.watch(shiftProvider.select((s) => s.suggestedOpeningCash));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: const Text('Open Shift'),
        elevation: 0,
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 500 : 480),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 32 : 20),
            child: CardContainer(
              elevated: true,
              padding: EdgeInsets.all(isTablet ? 36 : 28),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.09),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm)),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: AppColors.primary, size: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Open New Shift',
                                  style: cairo(
                                      fontSize: isTablet ? 18 : 16,
                                      fontWeight: FontWeight.w800)),
                              Text('Enter the opening cash amount',
                                  style: cairo(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                            ]),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    if (suggested > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.14))),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Suggested from last close: ${egp(suggested)}',
                                style: cairo(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),

                    Text('OPENING CASH',
                        style: cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      style: cairo(
                          fontSize: isTablet ? 34 : 30,
                          fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        prefixText: 'EGP  ',
                        prefixStyle: cairo(
                            fontSize: isTablet ? 22 : 19,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                        hintText: '0',
                        hintStyle: cairo(
                            fontSize: isTablet ? 34 : 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.border),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),

                    const Divider(color: AppColors.borderLight, height: 24),
                    const SizedBox(height: 4),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: _error != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 14, color: AppColors.danger),
                                const SizedBox(width: 6),
                                Flexible(
                                    child: Text(_error!,
                                        style: cairo(
                                            fontSize: 13,
                                            color: AppColors.danger))),
                              ]))
                          : const SizedBox.shrink(),
                    ),

                    // Task 2.1: Removed the !isOnline gate on the onTap for offline-open to work seamlessly.
                    AppButton(
                      label: 'Open Shift',
                      loading: _loading,
                      width: double.infinity,
                      icon: Icons.play_arrow_rounded,
                      onTap: _loading ? null : _open,
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
EOF

echo "Writing lib/features/shift/close_shift_screen.dart..."
cat << 'EOF' > lib/features/shift/close_shift_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/shift_api.dart';
import 'shift_report_preview_sheet.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/label_value.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});
  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Map<String, TextEditingController> _invCtrs  = {};
  final Map<String, bool>                  _zeroWarn = {};

  bool    _loadingInv = true;
  bool    _submitting = false;
  bool    _printing   = false;
  String? _error;
  int     _declaredCash = 0;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_updateDeclared);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(shiftProvider.notifier).loadSystemCash();
      await _loadInventory();
    });
  }

  @override
  void dispose() {
    _cashCtrl
      ..removeListener(_updateDeclared)
      ..dispose();
    _noteCtrl.dispose();
    for (final c in _invCtrs.values) c.dispose();
    super.dispose();
  }

  void _updateDeclared() {
    final raw = double.tryParse(_cashCtrl.text);
    setState(() => _declaredCash = raw != null ? (raw * 100).round() : 0);
  }

  Future<void> _loadInventory() async {
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) { setState(() => _loadingInv = false); return; }
    await ref.read(shiftProvider.notifier).loadInventory(branchId);
    if (!mounted) return;
    final items = ref.read(shiftProvider).inventory;
    setState(() {
      _loadingInv = false;
      for (final i in items) {
        _invCtrs[i.id] =
            TextEditingController(text: i.currentStock.toStringAsFixed(2))
              ..addListener(() {
                final v   = double.tryParse(_invCtrs[i.id]?.text ?? '');
                final was = _zeroWarn[i.id] ?? false;
                final is0 = v == 0.0;
                if (was != is0) setState(() => _zeroWarn[i.id] = is0);
              });
      }
    });
  }

  Future<void> _printReport() async {
    final shift = ref.read(shiftProvider).shift;
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No open shift'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _printing = true);
    try {
      final report = await ref.read(shiftApiProvider).getReport(shift.id);
      if (mounted) {
        setState(() => _printing = false);
        await ShiftReportPreviewSheet.show(context, report);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _printing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load report: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }

    final inv       = ref.read(shiftProvider).inventory;
    final zeroItems = inv
        .where((i) {
          final v = double.tryParse(_invCtrs[i.id]?.text ?? '');
          return v == null || v == 0.0;
        })
        .map((i) => i.name)
        .toList();

    if (zeroItems.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:   Text('Zero Stock Warning', style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
              'The following items have 0 stock:\n\n${zeroItems.join(", ")}'
              '\n\nAre you sure you want to submit?',
              style: cairo(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Go Back', style: cairo(color: AppColors.primary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Submit Anyway',
                    style: cairo(color: AppColors.danger, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() { _submitting = true; _error = null; });

    final counts = _invCtrs.entries
        .map((e) => {
              'branch_inventory_id': e.key,
              'actual_stock':        double.tryParse(e.value.text) ?? 0.0,
            })
        .toList();

    final branchId = ref.read(authProvider).user!.branchId!;
    final ok       = await ref.read(shiftProvider.notifier).closeShift(
          branchId:        branchId,
          closingCash:     (raw * 100).round(),
          note:            _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          inventoryCounts: counts,
        );

    if (!mounted) return;

    if (ok) {
      final canNowLogout = await ref.read(authProvider.notifier).canLogout();
      if (!mounted) return;
      if (canNowLogout) {
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.go('/login');
      } else {
        context.go('/home');
      }
    } else {
      setState(() {
        _error      = ref.read(shiftProvider).error ?? 'Failed to close shift';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift    = ref.watch(shiftProvider).shift;
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title:            const Text('Close Shift'),
        backgroundColor:  Colors.white,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
        actions: [
          if (shift != null)
            _printing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)))
                : IconButton(
                    icon:      const Icon(Icons.print_rounded),
                    tooltip:   'Print shift report',
                    onPressed: _printReport),
        ],
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : isTablet ? _buildTablet(shift) : _buildPhone(shift),
    );
  }

  Widget _buildPhone(dynamic shift) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SummaryCard(shift: shift),
              const SizedBox(height: 16),
              _CashCard(state: this),
              const SizedBox(height: 16),
              _InventoryCard(state: this),
              const SizedBox(height: 16),
              _SubmitSection(state: this),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      );

  Widget _buildTablet(dynamic shift) => Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [
                _SummaryCard(shift: shift),
                const SizedBox(height: 16),
                _CashCard(state: this),
              ])),
              const SizedBox(width: 20),
              Expanded(child: _InventoryCard(state: this)),
            ]),
          ),
        ),
        Container(
          color:   AppColors.bg,
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
          child:   _SubmitSection(state: this),
        ),
      ]);
}

// ── Section cards ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color    iconBg, iconColor;
  final String   title;
  const _SectionHeader({required this.icon, required this.iconBg,
      required this.iconColor, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(AppRadius.xs)),
            child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 12),
        Text(title, style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
      ]);
}

class _SummaryCard extends StatelessWidget {
  final dynamic shift;
  const _SummaryCard({required this.shift});
  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader(icon: Icons.summarize_outlined,
              iconBg: Color(0xFFEEF2FF), iconColor: AppColors.primary,
              title: 'Shift Summary'),
          const SizedBox(height: 18),
          LabelValue('Teller',       shift.tellerName),
          LabelValue('Opening Cash', egp(shift.openingCash)),
          LabelValue('Opened At',    dateTime(shift.openedAt)),
        ]),
      );
}

class _CashCard extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _CashCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemCash  = ref.watch(shiftProvider.select((s) => s.systemCash));
    final cashLoading = ref.watch(shiftProvider.select((s) => s.systemCashLoading));
    final discrepancy = state._declaredCash - systemCash;
    final showDiscrep = !cashLoading && state._cashCtrl.text.isNotEmpty;

    return CardContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.payments_outlined,
            iconBg: Color(0xFFECFDF5), iconColor: AppColors.success,
            title: 'Cash Count'),
        const SizedBox(height: 18),
        Container(
          padding:    const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('System Cash', style: cairo(fontSize: 12,
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text('Opening + cash orders + movements',
                  style: cairo(fontSize: 11, color: AppColors.textMuted)),
            ])),
            cashLoading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Text(egp(systemCash),
                    style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 18),
        Text('ACTUAL CASH IN DRAWER',
            style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: state._cashCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: cairo(fontSize: 30, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText:  'EGP  ',
            prefixStyle: cairo(fontSize: 20, color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
            hintText:  '0',
            hintStyle: cairo(fontSize: 30, fontWeight: FontWeight.w800,
                color: AppColors.border),
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeOut,
          child: showDiscrep
              ? Padding(padding: const EdgeInsets.only(top: 14),
                  child: _DiscrepancyRow(
                      discrepancy: discrepancy, systemCash: systemCash))
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
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
}

class _InventoryCard extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _InventoryCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(shiftProvider.select((s) => s.inventory));
    return CardContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.inventory_2_outlined,
            iconBg: Color(0xFFFFFBEB), iconColor: AppColors.warning,
            title: 'Inventory Count'),
        const SizedBox(height: 18),
        if (state._loadingInv)
          const Center(child: Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary)))
        else if (inventory.isEmpty)
          Text('No inventory items',
              style: cairo(fontSize: 13, color: AppColors.textMuted))
        else
          ...inventory.map((item) {
            final warn = state._zeroWarn[item.id] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('System: ${item.currentStock} ${item.unit}',
                      style: cairo(fontSize: 12, color: AppColors.textSecondary)),
                  if (warn)
                    Padding(padding: const EdgeInsets.only(top: 3),
                      child: Text('⚠ Value is 0 — confirm this is correct',
                          style: cairo(fontSize: 11, color: AppColors.warning))),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 130, child: TextField(
                  controller:   state._invCtrs[item.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign:    TextAlign.center,
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w600,
                      color: warn ? AppColors.warning : AppColors.textPrimary),
                  decoration: InputDecoration(
                    suffixText:     item.unit,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide:   BorderSide(
                            color: warn ? AppColors.warning : AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide:   const BorderSide(
                            color: AppColors.primary, width: 2)),
                  ),
                )),
              ]),
            );
          }),
      ]),
    );
  }
}

class _SubmitSection extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _SubmitSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    return Column(children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeOut,
        child: state._error != null
            ? Padding(padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color:        AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.danger.withOpacity(0.18))),
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
      if (!isOnline)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color:        const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border:       Border.all(color: const Color(0xFFFFD700))),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              Expanded(child: Text('Internet required to close a shift.',
                  style: cairo(fontSize: 12, color: const Color(0xFF856404)))),
            ]),
          ),
        ),
      AppButton(
        label:   'Close Shift',
        variant: BtnVariant.danger,
        loading: state._submitting,
        width:   double.infinity,
        icon:    Icons.lock_outline_rounded,
        onTap:   (!isOnline || state._submitting) ? null : state._close,
      ),
    ]);
  }
}

class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy, systemCash;
  const _DiscrepancyRow({required this.discrepancy, required this.systemCash});

  @override
  Widget build(BuildContext context) {
    final isExact = discrepancy == 0;
    final isOver  = discrepancy > 0;
    final color   = isExact ? AppColors.success
        : isOver ? AppColors.warning : AppColors.danger;
    final icon  = isExact ? Icons.check_circle_outline_rounded
        : isOver ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label = isExact ? 'Exact match'
        : isOver ? 'Over by ${egp(discrepancy.abs())}'
                 : 'Short by ${egp(discrepancy.abs())}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color:        color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border:       Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(label, style: cairo(fontSize: 13,
            fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        if (!isExact)
          Text('System: ${egp(systemCash)}',
              style: cairo(fontSize: 11, color: color.withOpacity(0.75))),
      ]),
    );
  }
}
EOF

echo "Writing lib/features/shift/cash_movement_sheet.dart..."
cat << 'EOF' > lib/features/shift/cash_movement_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/shift_api.dart';
import '../../core/api/client.dart';
import '../../core/models/pending_action.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/responsive_sheet.dart';

class CashMovementSheet extends ConsumerStatefulWidget {
  final String shiftId;
  final void Function()? onSuccess;

  const CashMovementSheet({
    super.key,
    required this.shiftId,
    this.onSuccess,
  });

  // Task 3.2: Use ResponsiveSheet
  static Future<void> show(
    BuildContext context, {
    required String shiftId,
    void Function()? onSuccess,
  }) =>
      ResponsiveSheet.show(
        context: context,
        builder: (_) => CashMovementSheet(
          shiftId: shiftId,
          onSuccess: onSuccess,
        ),
      );

  @override
  ConsumerState<CashMovementSheet> createState() => _CashMovementSheetState();
}

class _CashMovementSheetState extends ConsumerState<CashMovementSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  bool   _isIn      = true;   // true = Cash In, false = Cash Out
  bool   _loading   = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = double.tryParse(_amountCtrl.text);
    if (raw == null || raw <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_noteCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Note is required');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final isOnline = ref.read(isOnlineProvider);
    final piastres = (raw * 100).round();
    final signed   = _isIn ? piastres : -piastres;

    try {
      if (isOnline) {
        await ref.read(shiftApiProvider).addCashMovement(
          widget.shiftId,
          signed,
          _noteCtrl.text.trim(),
        );
      } else {
        // Task 2.3: Offline Queueing
        await ref.read(offlineQueueProvider.notifier).enqueueCashMovement(
          PendingCashMovement(
            localId: const Uuid().v4(),
            createdAt: DateTime.now(),
            shiftId: widget.shiftId,
            amount: signed,
            note: _noteCtrl.text.trim(),
          )
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
      }
    } catch (e) {
      setState(() {
        _error   = friendlyError(e); // Task 4.2
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.sheetRadius,
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, mq.viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text('Cash Movement',
              style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (!isOnline)
            Text('Offline — will be queued and applied when connected',
                style: cairo(fontSize: 12, color: AppColors.warning)),
          const SizedBox(height: 18),

          // Direction toggle
          Row(children: [
            Expanded(child: _DirectionBtn(
              label: 'Cash In',
              icon: Icons.add_circle_outline_rounded,
              selected: _isIn,
              color: AppColors.success,
              onTap: () => setState(() => _isIn = true),
            )),
            const SizedBox(width: 10),
            Expanded(child: _DirectionBtn(
              label: 'Cash Out',
              icon: Icons.remove_circle_outline_rounded,
              selected: !_isIn,
              color: AppColors.danger,
              onTap: () => setState(() => _isIn = false),
            )),
          ]),
          const SizedBox(height: 18),

          // Amount
          Text('AMOUNT',
              style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            autofocus: true,
            style: cairo(fontSize: 28, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: 'EGP  ',
              prefixStyle: cairo(fontSize: 18, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              hintText: '0',
              hintStyle: cairo(fontSize: 28, fontWeight: FontWeight.w800,
                  color: AppColors.border),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Note
          Text('NOTE',
              style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: cairo(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Safe drop, float top-up…',
              hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.notes_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: AppColors.danger.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(_error!, style: cairo(fontSize: 13, color: AppColors.danger)),
              ]),
            ),
          ],
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isIn ? AppColors.success : AppColors.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_isIn
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(isOnline ? (_isIn ? 'Record Cash In' : 'Record Cash Out') : 'Queue Offline',
                          style: cairo(fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _DirectionBtn({
    required this.label, required this.icon,
    required this.selected, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? color : AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: selected ? Colors.white : color),
        const SizedBox(width: 8),
        Text(label,
            style: cairo(fontSize: 14, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary)),
      ]),
    ),
  );
}
EOF

echo "Batch 2 complete."