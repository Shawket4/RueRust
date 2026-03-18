#!/usr/bin/env bash
# =============================================================================
#  RuePOS Update Script — fully standalone, bash-safe
#  Usage:  bash update.sh [path/to/flutter/project]
#  Default project path: current directory (.)
# =============================================================================
set -e
PROJ="${1:-.}"
[ -d "$PROJ" ] || { echo "ERROR: Project directory not found: $PROJ"; exit 1; }
echo "==> Updating RuePOS at: $(cd "$PROJ" && pwd)"

write() {
  local dest="$PROJ/$1"
  mkdir -p "$(dirname "$dest")"
  # read stdin into the file
  cat > "$dest"
  echo "  written: $1"
}

# ────────────────────────────────────────────────────────────────────────
# lib/core/models/branch.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/models/branch.dart' << 'DART_EOF'
class Branch {
  final String  id;
  final String  orgId;
  final String  name;
  final String? address;
  final String? phone;
  final String? printerIp;
  final int     printerPort;
  final bool    isActive;

  const Branch({
    required this.id,
    required this.orgId,
    required this.name,
    this.address,
    this.phone,
    this.printerIp,
    this.printerPort = 9100,
    required this.isActive,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id:          j['id']            as String,
        orgId:       j['org_id']        as String,
        name:        j['name']          as String,
        address:     j['address']       as String?,
        phone:       j['phone']         as String?,
        printerIp:   j['printer_ip']    as String?,
        printerPort: (j['printer_port'] as int?) ?? 9100,
        isActive:    (j['is_active']    as bool?) ?? true,
      );

  bool get hasPrinter => printerIp != null && printerIp!.trim().isNotEmpty;
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/models/order.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/models/order.dart' << 'DART_EOF'
class SelectedAddon {
  final String addonItemId;
  final String drinkOptionItemId;
  final String name;
  final int    priceModifier;

  const SelectedAddon({
    required this.addonItemId,
    required this.drinkOptionItemId,
    required this.name,
    required this.priceModifier,
  });
}

class CartItem {
  final String              menuItemId;
  final String              itemName;
  final String?             sizeLabel;
  final int                 unitPrice;
  int                       quantity;
  final List<SelectedAddon> addons;
  final String?             notes;

  CartItem({
    required this.menuItemId,
    required this.itemName,
    this.sizeLabel,
    required this.unitPrice,
    this.quantity = 1,
    this.addons   = const [],
    this.notes,
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
    required this.id,
    required this.addonName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderItemAddon.fromJson(Map<String, dynamic> j) => OrderItemAddon(
        id:        j['id'],
        addonName: j['addon_name'],
        unitPrice: j['unit_price'],
        quantity:  j['quantity'],
        lineTotal: j['line_total'],
      );
}

class OrderItem {
  final String               id;
  final String               itemName;
  final String?              sizeLabel;
  final int                  unitPrice;
  final int                  quantity;
  final int                  lineTotal;
  final List<OrderItemAddon> addons;

  const OrderItem({
    required this.id,
    required this.itemName,
    this.sizeLabel,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.addons,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id:        j['id'],
        itemName:  j['item_name'],
        sizeLabel: j['size_label'],
        unitPrice: j['unit_price'],
        quantity:  j['quantity'],
        lineTotal: j['line_total'],
        addons: (j['addons'] as List? ?? [])
            .map((a) => OrderItemAddon.fromJson(a))
            .toList(),
      );
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
  final DateTime        createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.branchId,
    required this.shiftId,
    required this.tellerId,
    required this.tellerName,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.subtotal,
    this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    this.customerName,
    this.notes,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id:             j['id'],
        branchId:       j['branch_id'],
        shiftId:        j['shift_id'],
        tellerId:       (j['teller_id']    as String?) ?? '',
        tellerName:     (j['teller_name']  as String?) ?? '',
        orderNumber:    j['order_number'],
        status:         j['status'],
        paymentMethod:  j['payment_method'],
        subtotal:       (j['subtotal']       as int?) ?? 0,
        discountType:   j['discount_type']   as String?,
        discountValue:  (j['discount_value'] as int?) ?? 0,
        discountAmount: (j['discount_amount'] as int?) ?? 0,
        taxAmount:      (j['tax_amount']     as int?) ?? 0,
        totalAmount:    j['total_amount'],
        customerName:   j['customer_name']   as String?,
        notes:          j['notes']           as String?,
        createdAt:      DateTime.parse(j['created_at']),
        items: (j['items'] as List? ?? [])
            .map((i) => OrderItem.fromJson(i))
            .toList(),
      );
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/api/branch_api.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/api/branch_api.dart' << 'DART_EOF'
import 'client.dart';
import '../models/branch.dart';

class BranchApi {
  Future<Branch> get(String branchId) async {
    final res = await dio.get('/branches/$branchId');
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }
}

final branchApi = BranchApi();

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/api/shift_api.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/api/shift_api.dart' << 'DART_EOF'
import 'client.dart';
import '../models/shift.dart';

class ShiftApi {
  Future<ShiftPreFill> current(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId/current');
    return ShiftPreFill.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Shift>> list(String branchId) async {
    final res = await dio.get('/shifts/branches/$branchId');
    return (res.data as List).map((s) => Shift.fromJson(s)).toList();
  }

  Future<Shift> open(String branchId, int openingCash) async {
    final res = await dio.post(
      '/shifts/branches/$branchId/open',
      data: {'opening_cash': openingCash},
    );
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
    final body = res.data as Map<String, dynamic>;
    return Shift.fromJson(body['shift'] as Map<String, dynamic>);
  }

  Future<int> getSystemCash(String shiftId, int openingCash) async {
    final ordersRes =
        await dio.get('/orders', queryParameters: {'shift_id': shiftId});
    final orders = ordersRes.data as List;
    final cashFromOrders = orders
        .where((o) =>
            o['payment_method'] == 'cash' &&
            o['status'] != 'voided' &&
            o['status'] != 'refunded')
        .fold<int>(0, (sum, o) => sum + (o['total_amount'] as int));

    final movRes = await dio.get('/shifts/$shiftId/cash-movements');
    final movements = movRes.data as List;
    final cashMovements =
        movements.fold<int>(0, (sum, m) => sum + (m['amount'] as int));

    return openingCash + cashFromOrders + cashMovements;
  }
}

final shiftApi = ShiftApi();

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/providers/branch_provider.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/providers/branch_provider.dart' << 'DART_EOF'
import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../api/branch_api.dart';

class BranchProvider extends ChangeNotifier {
  Branch? _branch;
  bool    _loading = false;
  String? _error;

  Branch? get branch   => _branch;
  bool    get loading  => _loading;
  String? get error    => _error;

  bool get hasPrinter => _branch?.hasPrinter ?? false;
  String? get printerIp   => _branch?.printerIp;
  int     get printerPort  => _branch?.printerPort ?? 9100;
  String  get branchName   => _branch?.name ?? '';

  Future<void> load(String branchId) async {
    if (_branch?.id == branchId) return;
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _branch = await branchApi.get(branchId);
    } catch (e) {
      _error = e.toString();
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
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/providers/auth_provider.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/providers/auth_provider.dart' << 'DART_EOF'
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/auth_api.dart';
import '../api/client.dart';
import 'branch_provider.dart';

class AuthProvider extends ChangeNotifier {
  final BranchProvider branchProvider;

  AuthProvider(this.branchProvider);

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
    if (branchId != null) {
      await branchProvider.load(branchId);
    }
  }

  Future<void> _clear() async {
    authToken = null;
    _user     = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/services/printer_service.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/services/printer_service.dart' << 'DART_EOF'
// ESC/POS receipt printer over TCP port 9100.
// Works on Android, iOS, macOS, Windows, Linux.
// Web is excluded — dart:io is not available there.
// ignore: avoid_web_libraries_in_flutter
import 'dart:io';
import 'dart:typed_data';
import '../models/order.dart';
import '../utils/formatting.dart';

class PrinterService {
  static const _timeout = Duration(seconds: 5);

  // ── ESC/POS byte constants ────────────────────────────────────────────────
  static const _esc    = 0x1B;
  static const _gs     = 0x1D;
  static const _lf     = 0x0A;
  static const _cut    = [0x1D, 0x56, 0x41, 0x05]; // partial cut

  // Initialize printer
  static List<int> get _init => [_esc, 0x40];

  // Align: 0=left, 1=center, 2=right
  static List<int> _align(int a) => [_esc, 0x61, a];

  // Bold on/off
  static List<int> _bold(bool on) => [_esc, 0x45, on ? 1 : 0];

  // Double width+height on/off
  static List<int> _doubleSize(bool on) =>
      [_gs, 0x21, on ? 0x11 : 0x00];

  // Text to bytes (Latin-1 safe, replaces non-printable chars)
  static List<int> _text(String s) {
    final out = <int>[];
    for (final c in s.runes) {
      out.add(c < 256 ? c : 0x3F); // '?'
    }
    return out;
  }

  static List<int> _line(String s) => [..._text(s), _lf];

  static List<int> _divider([int width = 42]) =>
      _line('-' * width);

  // Two-column row: left text + right text, padded to width
  static List<int> _row(String left, String right, {int width = 42}) {
    final space = width - left.length - right.length;
    final padded = space > 0
        ? left + (' ' * space) + right
        : '${left.substring(0, width - right.length - 1)}… $right';
    return _line(padded);
  }

  // ── Build receipt bytes ───────────────────────────────────────────────────
  static Uint8List buildReceipt({
    required Order  order,
    required String branchName,
  }) {
    final buf = <int>[];

    buf.addAll(_init);

    // Header
    buf.addAll(_align(1)); // center
    buf.addAll(_doubleSize(true));
    buf.addAll(_bold(true));
    buf.addAll(_line('THE RUE COFFEE'));
    buf.addAll(_doubleSize(false));
    buf.addAll(_bold(false));
    buf.addAll(_line(branchName));
    buf.addAll(_line(''));
    buf.addAll(_divider());

    // Order info
    buf.addAll(_align(0)); // left
    buf.addAll(_bold(true));
    buf.addAll(_row(
      'Order #${order.orderNumber}',
      timeShort(order.createdAt),
    ));
    buf.addAll(_bold(false));
    buf.addAll(_divider());

    // Items
    for (final item in order.items) {
      final sizePart = item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
      final label    = '${item.quantity}x ${item.itemName}$sizePart';
      final price    = egp(item.lineTotal);
      buf.addAll(_row(label, price));

      for (final addon in item.addons) {
        final aLabel = '  + ${addon.addonName}';
        final aPrice = addon.unitPrice > 0 ? '+${egp(addon.unitPrice)}' : '';
        if (aPrice.isNotEmpty) buf.addAll(_row(aLabel, aPrice));
        else buf.addAll(_line(aLabel));
      }
    }

    buf.addAll(_divider());

    // Totals
    buf.addAll(_row('Subtotal', egp(order.subtotal)));
    if (order.discountAmount > 0) {
      buf.addAll(_row('Discount', '- ${egp(order.discountAmount)}'));
    }
    if (order.taxAmount > 0) {
      buf.addAll(_row('Tax', egp(order.taxAmount)));
    }
    buf.addAll(_bold(true));
    buf.addAll(_row('TOTAL', egp(order.totalAmount)));
    buf.addAll(_bold(false));
    buf.addAll(_divider());

    // Footer info
    final payLabel = order.paymentMethod[0].toUpperCase() +
        order.paymentMethod.substring(1).replaceAll('_', ' ');
    buf.addAll(_line('Payment : $payLabel'));
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buf.addAll(_line('Customer: ${order.customerName}'));
    }
    if (order.tellerName.isNotEmpty) {
      buf.addAll(_line('Teller  : ${order.tellerName}'));
    }
    buf.addAll(_line(''));
    buf.addAll(_align(1)); // center
    buf.addAll(_line('Thank you for visiting!'));
    buf.addAll(_line(''));
    buf.addAll(_line(''));
    buf.addAll(_line(''));

    // Cut
    buf.addAll(_cut);

    return Uint8List.fromList(buf);
  }

  // ── Send to printer ───────────────────────────────────────────────────────
  /// Returns null on success, or an error message string.
  static Future<String?> print({
    required String ip,
    required int    port,
    required Order  order,
    required String branchName,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: _timeout);
      final bytes = buildReceipt(order: order, branchName: branchName);
      socket.add(bytes);
      await socket.flush();
      return null; // success
    } on SocketException catch (e) {
      return 'Printer error: ${e.message}';
    } on OSError catch (e) {
      return 'Printer error: ${e.message}';
    } catch (e) {
      return 'Printer error: $e';
    } finally {
      await socket?.close();
    }
  }
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/core/router/router.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/core/router/router.dart' << 'DART_EOF'
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/shift/open_shift_screen.dart';
import '../../features/shift/close_shift_screen.dart';
import '../../features/shift/shift_history_screen.dart';
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
        GoRoute(path: '/shift-history', builder: (_, __) => const ShiftHistoryScreen()),
        GoRoute(path: '/order',         builder: (_, __) => const OrderScreen()),
        GoRoute(path: '/order-history', builder: (_, __) => const OrderHistoryScreen()),
      ],
    );

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/main.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/main.dart' << 'DART_EOF'
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
    // BranchProvider is created first so AuthProvider can receive it
    final branchProvider = BranchProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BranchProvider>.value(value: branchProvider),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(branchProvider)..init(),
        ),
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
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
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

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/features/home/home_screen.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/features/home/home_screen.dart' << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/order_api.dart';
import '../../core/api/shift_api.dart';
import '../../core/models/order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
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
    try {
      final results = await Future.wait([
        orderApi.list(shiftId: shift.id),
        shiftApi.getSystemCash(shift.id, shift.openingCash),
      ]);
      final orders = results[0] as List<Order>;
      final system = results[1] as int;
      if (mounted) {
        setState(() {
          _orderCount  = orders.where((o) => o.status != 'voided').length;
          _salesTotal  = orders
              .where((o) => o.status != 'voided')
              .fold(0, (s, o) => s + o.totalAmount);
          _systemCash  = system;
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user     = context.watch<AuthProvider>().user!;
    final shift    = context.watch<ShiftProvider>();
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 36 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/TheRue.png', height: isTablet ? 52 : 44),
                  const Spacer(),
                  Text(user.name,
                      style: cairo(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  _SignOutBtn(),
                ],
              ),
              SizedBox(height: isTablet ? 36 : 28),

              // Greeting
              Text(
                _greet(user.name.split(' ').first),
                style: cairo(
                    fontSize: isTablet ? 28 : 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                user.role.replaceAll('_', ' ').toUpperCase(),
                style: cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1),
              ),
              SizedBox(height: isTablet ? 32 : 24),

              // Main content
              if (shift.loading)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (shift.error != null)
                _ErrorBanner(message: shift.error!, onRetry: _load)
              else if (shift.hasOpen)
                _OpenShiftView(
                  shift:       shift.shift!,
                  orderCount:  _orderCount,
                  salesTotal:  _salesTotal,
                  systemCash:  _systemCash,
                  statsLoaded: _statsLoaded,
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
    final h = DateTime.now().hour;
    final word = h < 12 ? 'Morning' : h < 17 ? 'Afternoon' : 'Evening';
    return 'Good $word, $first';
  }
}

// ── Open Shift View ───────────────────────────────────────────────────────────
class _OpenShiftView extends StatelessWidget {
  final dynamic     shift;
  final int         orderCount;
  final int         salesTotal;
  final int         systemCash;
  final bool        statsLoaded;
  final VoidCallback onRefresh;
  final bool        isTablet;

  const _OpenShiftView({
    required this.shift,
    required this.orderCount,
    required this.salesTotal,
    required this.systemCash,
    required this.statsLoaded,
    required this.onRefresh,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
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
          // Status row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80), shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('SHIFT OPEN',
                    style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.8)),
              ]),
            ),
            const Spacer(),
            Text('Since ${timeShort(shift.openedAt)}',
                style: cairo(fontSize: 11, color: Colors.white60)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white54),
            ),
          ]),
          SizedBox(height: isTablet ? 26 : 20),

          // Stats
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

          // Action buttons — 4 buttons now
          Row(children: [
            Expanded(child: _CardBtn(
              label:   'New Order',
              icon:    Icons.add_shopping_cart_rounded,
              onTap:   () => context.go('/order'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(
              label:   'History',
              icon:    Icons.receipt_long_rounded,
              onTap:   () => context.go('/order-history'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(
              label:   'Shifts',
              icon:    Icons.history_rounded,
              onTap:   () => context.go('/shift-history'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(
              label:   'Close',
              icon:    Icons.lock_outline_rounded,
              onTap:   () => _confirmClose(context),
              danger:  true,
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
            child: Text('Cancel', style: cairo(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/close-shift');
            },
            child: Text('Continue',
                style: cairo(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ShiftStat extends StatelessWidget {
  final String  label;
  final String  value;
  final String? sublabel;
  final bool    loading;
  final bool    isTablet;

  const _ShiftStat({
    required this.label,
    required this.value,
    this.sublabel,
    this.loading  = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: cairo(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          loading
              ? Container(
                  width: 50, height: 16,
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
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
        width: 1, height: 44,
        color:  Colors.white.withOpacity(0.15),
        margin: const EdgeInsets.symmetric(horizontal: 14),
      );
}

class _CardBtn extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final VoidCallback onTap;
  final bool      danger;
  final bool      isTablet;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger   = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 11),
          decoration: BoxDecoration(
            color:        danger ? Colors.white.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size:  isTablet ? 18 : 16,
                color: danger ? Colors.white : AppColors.primary),
            const SizedBox(height: 4),
            Text(label,
                style: cairo(
                    fontSize: isTablet ? 12 : 11,
                    fontWeight: FontWeight.w700,
                    color: danger ? Colors.white : AppColors.primary)),
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
                      color:        AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wb_sunny_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('No Open Shift',
                        style: cairo(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w700)),
                    if (suggested > 0)
                      Text('Last closing: ${egp(suggested)}',
                          style: cairo(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ]),
                const SizedBox(height: 22),
                AppButton(
                  label:  'Open Shift',
                  width:  double.infinity,
                  icon:   Icons.play_arrow_rounded,
                  onTap:  () => context.go('/open-shift'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Shift history always accessible even without an open shift
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/shift-history'),
              icon:  const Icon(Icons.history_rounded, size: 16),
              label: Text('View Shift History', style: cairo(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                minimumSize:   const Size(double.infinity, 48),
                shape:         RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side:          const BorderSide(color: AppColors.border),
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
            border:       Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.logout_rounded, size: 15, color: AppColors.textSecondary),
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
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: cairo(fontSize: 13, color: AppColors.danger))),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry',
                style: cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ]),
      );
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/features/shift/shift_history_screen.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/features/shift/shift_history_screen.dart' << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/order_api.dart';
import '../../core/api/shift_api.dart';
import '../../core/models/order.dart';
import '../../core/models/shift.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';

class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});
  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  List<Shift> _shifts = [];
  bool        _loading = true;
  String?     _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = context.read<AuthProvider>().user?.branchId;
    if (branchId == null) {
      setState(() { _loading = false; _error = 'No branch assigned'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final shifts = await shiftApi.list(branchId);
      if (mounted) setState(() { _shifts = shifts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Shift History',
            style: cairo(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorBanner(message: _error!, onRetry: _load),
                )
              : _shifts.isEmpty
                  ? Center(
                      child: Text('No shifts found',
                          style: cairo(fontSize: 15, color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: EdgeInsets.all(isTablet ? 24 : 16),
                      itemCount: _shifts.length,
                      itemBuilder: (_, i) => _ShiftTile(shift: _shifts[i]),
                    ),
    );
  }
}

// ── Shift tile ────────────────────────────────────────────────────────────────
class _ShiftTile extends StatefulWidget {
  final Shift shift;
  const _ShiftTile({required this.shift});
  @override
  State<_ShiftTile> createState() => _ShiftTileState();
}

class _ShiftTileState extends State<_ShiftTile> {
  bool _expanded = false;
  bool _loadingOrders = false;
  List<Order> _orders = [];
  String? _ordersError;

  Future<void> _loadOrders() async {
    if (_orders.isNotEmpty) { setState(() => _expanded = !_expanded); return; }
    setState(() { _loadingOrders = true; _expanded = true; });
    try {
      final orders = await orderApi.list(shiftId: widget.shift.id);
      if (mounted) setState(() { _orders = orders; _loadingOrders = false; });
    } catch (e) {
      if (mounted) setState(() { _ordersError = e.toString(); _loadingOrders = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s      = widget.shift;
    final isOpen = s.status == 'open';

    final statusColor = isOpen
        ? AppColors.success
        : s.status == 'force_closed'
            ? AppColors.danger
            : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header row
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loadOrders,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Status dot
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    s.tellerName,
                    style: cairo(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateTime(s.openedAt),
                    style: cairo(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.status.replaceAll('_', ' ').toUpperCase(),
                    style: cairo(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
                const SizedBox(height: 4),
                if (s.closingCashDeclared != null)
                  Text(
                    egp(s.closingCashDeclared!),
                    style: cairo(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
              ]),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textMuted,
              ),
            ]),
          ),
        ),

        // Orders panel
        if (_expanded) ...[
          const Divider(height: 1, color: AppColors.border),
          if (_loadingOrders)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (_ordersError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_ordersError!, style: cairo(fontSize: 12, color: AppColors.danger)),
            )
          else if (_orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No orders in this shift', style: cairo(fontSize: 13, color: AppColors.textMuted)),
            )
          else
            ..._orders.map((o) => _PastOrderRow(order: o)),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

// ── Past order row inside an expanded shift ───────────────────────────────────
class _PastOrderRow extends StatefulWidget {
  final Order order;
  const _PastOrderRow({required this.order});
  @override
  State<_PastOrderRow> createState() => _PastOrderRowState();
}

class _PastOrderRowState extends State<_PastOrderRow> {
  bool _printing = false;

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer configured for this branch'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _printing = true);
    try {
      Order full;
      try {
        full = await orderApi.get(widget.order.id);
      } catch (_) {
        full = widget.order;
      }
      final err = await PrinterService.print(
        ip:         bp.printerIp!,
        port:       bp.printerPort,
        order:      full,
        branchName: bp.branchName,
      );
      if (mounted) {
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.danger),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt printed'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o        = widget.order;
    final isVoided = o.status == 'voided';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        isVoided ? AppColors.borderLight : AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text('#${o.orderNumber}',
              style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isVoided ? AppColors.textMuted : AppColors.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(timeShort(o.createdAt), style: cairo(fontSize: 12, color: AppColors.textSecondary)),
            if (o.customerName != null)
              Text(o.customerName!, style: cairo(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        Text(
          egp(o.totalAmount),
          style: cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color:      isVoided ? AppColors.textMuted : AppColors.textPrimary,
            decoration: isVoided ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(width: 8),
        if (!isVoided)
          _printing
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : GestureDetector(
                  onTap: _print,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.print_rounded, size: 15, color: AppColors.primary),
                  ),
                ),
      ]),
    );
  }
}

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/features/order/order_screen.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/features/order/order_screen.dart' << 'DART_EOF'

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/api/menu_api.dart';
import '../../core/api/order_api.dart';
import '../../core/models/menu.dart';
import '../../core/models/order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/menu_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/label_value.dart';

String _normaliseName(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

const _skeletonBase      = Color(0xFFF0EBE3);
const _skeletonHighlight = Color(0xFFE8E0D5);

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(ctrl: _searchCtrl, query: _query),
          Expanded(
            child: Row(children: [
              if (_query.isEmpty) const _CategoryRail(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve:  Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.04), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: _query.isNotEmpty
                      ? _SearchResults(key: ValueKey(_query), query: _query)
                      : const _MenuGrid(key: ValueKey('grid')),
                ),
              ),
              const _CartPanel(),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String query;
  const _TopBar({required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      color: Colors.white,
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
                hintText:   'Search menu…',
                hintStyle:  cairo(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(
                        onTap: ctrl.clear,
                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted))
                    : null,
                border:           InputBorder.none,
                enabledBorder:    InputBorder.none,
                focusedBorder:    InputBorder.none,
                contentPadding:   const EdgeInsets.symmetric(vertical: 10),
                isDense:          true,
                filled:           false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: cart.isEmpty
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : Container(
                  key: const ValueKey('pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color:      AppColors.primary.withOpacity(0.28),
                          blurRadius: 10,
                          offset:     const Offset(0, 3))
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('${cart.count} · ${egp(cart.total)}',
                        style: cairo(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
        ),
      ]),
    );
  }
}

// ── Category Rail ─────────────────────────────────────────────────────────────
class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    return Container(
      width: 86,
      decoration: const BoxDecoration(
        color:  Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding:     const EdgeInsets.symmetric(vertical: 4),
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
                    Text(_normaliseName(cat.name),
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
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  IconData _catIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('matcha'))   return Icons.eco_rounded;
    if (n.contains('latte') || n.contains('espresso') || n.contains('americano') ||
        n.contains('cappuc')  || n.contains('flat')   || n.contains('cortado') ||
        n.contains('machiato')|| n.contains('coffee')) return Icons.coffee_rounded;
    if (n.contains('chocolate'))return Icons.cake_rounded;
    if (n.contains('croissant')|| n.contains('pain')  || n.contains('brownie') ||
        n.contains('cookie')  || n.contains('tart')   || n.contains('melt') ||
        n.contains('chicken') || n.contains('turkey')) return Icons.bakery_dining_rounded;
    if (n.contains('bottle')   || n.contains('cold brew')) return Icons.liquor_rounded;
    if (n.contains('soft serve')|| n.contains('affogato')) return Icons.icecream_rounded;
    if (n.contains('lemon')    || n.contains('peach') || n.contains('strawberry') ||
        n.contains('water')   || n.contains('tea')   || n.contains('pina'))
      return Icons.local_drink_rounded;
    return Icons.restaurant_menu_rounded;
  }
}

// ── Menu Grid ─────────────────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final menu  = context.watch<MenuProvider>();
    final items = menu.filtered.where((i) => i.isActive).toList();

    if (menu.loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 185, mainAxisSpacing: 12,
            crossAxisSpacing: 12,   childAspectRatio: 0.72),
        itemCount:   8,
        itemBuilder: (_, __) => const _MenuCardSkeleton(),
      );
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
      return Center(
          child: Text('No items in this category',
              style: cairo(color: AppColors.textMuted)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 185, mainAxisSpacing: 12,
          crossAxisSpacing: 12,   childAspectRatio: 0.72),
      itemCount:   items.length,
      itemBuilder: (_, i) => _MenuCard(item: items[i]),
    );
  }
}

// ── Search Results ────────────────────────────────────────────────────────────
class _SearchResults extends StatelessWidget {
  final String query;
  const _SearchResults({required this.query, super.key});

  @override
  Widget build(BuildContext context) {
    final found = context
        .watch<MenuProvider>()
        .allItems
        .where((i) =>
            i.isActive &&
            (i.name.toLowerCase().contains(query) ||
                (i.description?.toLowerCase().contains(query) ?? false)))
        .toList();

    if (found.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 160, height: 160,
            child: Lottie.asset('assets/lottie/no_results.json',
                fit: BoxFit.contain, repeat: true),
          ),
          const SizedBox(height: 8),
          Text('No results for "$query"',
              style: cairo(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 185, mainAxisSpacing: 12,
          crossAxisSpacing: 12,   childAspectRatio: 0.72),
      itemCount:   found.length,
      itemBuilder: (_, i) => _MenuCard(item: found[i]),
    );
  }
}

// ── Menu Card Skeleton ────────────────────────────────────────────────────────
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(_skeletonBase, _skeletonHighlight, _anim.value)!;
        return Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(color: c))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 11, width: double.infinity,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 5),
                Container(height: 11, width: 80,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 13, width: 60,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ── Image Skeleton ────────────────────────────────────────────────────────────
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
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

// ── Menu Card ─────────────────────────────────────────────────────────────────
class _MenuCard extends StatefulWidget {
  final MenuItem item;
  const _MenuCard({required this.item, super.key});
  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> with SingleTickerProviderStateMixin {
  bool _fetching = false;
  late final AnimationController _pressCtrl;
  late final Animation<double>   _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
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
    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) async { await _pressCtrl.reverse(); _onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, 3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: widget.item.imageUrl != null
                    ? Image.network(widget.item.imageUrl!,
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        loadingBuilder: (_, child, prog) => prog == null ? child : _ImageSkeleton(),
                        errorBuilder:  (_, __, ___) => _Placeholder(item: widget.item))
                    : _Placeholder(item: widget.item),
              ),
              if (_fetching)
                Container(
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                    alignment: Alignment.center,
                    child: const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))),
            ])),
            SizedBox(
              height: 66,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_normaliseName(widget.item.name),
                          style: cairo(fontSize: 12.5, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(egp(widget.item.basePrice),
                          style: cairo(fontSize: 12, fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final MenuItem item;
  const _Placeholder({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _pick(item.name.toLowerCase());
    return Container(
        width: double.infinity, height: double.infinity,
        color: bg, alignment: Alignment.center,
        child: Icon(icon, size: 32, color: fg));
  }

  static (IconData, Color, Color) _pick(String n) {
    if (n.contains('matcha'))
      return (Icons.eco_rounded, const Color(0xFFE8F5E9), const Color(0xFF388E3C));
    if (n.contains('latte') || n.contains('espresso') || n.contains('americano') ||
        n.contains('cappuc')|| n.contains('flat')     || n.contains('cortado') ||
        n.contains('machiato') || n.contains('coffee'))
      return (Icons.coffee_rounded, const Color(0xFFF5EEE6), const Color(0xFF795548));
    if (n.contains('chocolate'))
      return (Icons.cake_rounded, const Color(0xFFF3E5E5), const Color(0xFF6D4C41));
    if (n.contains('croissant') || n.contains('pain') || n.contains('brownie') || n.contains('cookie') || n.contains('tart'))
      return (Icons.bakery_dining_rounded, const Color(0xFFFFF8E1), const Color(0xFFF9A825));
    if (n.contains('melt') || n.contains('chicken') || n.contains('turkey'))
      return (Icons.lunch_dining_rounded, const Color(0xFFFFF3E0), const Color(0xFFEF6C00));
    if (n.contains('affogato') || n.contains('soft serve'))
      return (Icons.icecream_rounded, const Color(0xFFF3E5F5), const Color(0xFF8E24AA));
    if (n.contains('lemon') || n.contains('peach') || n.contains('strawberry') ||
        n.contains('pina')  || n.contains('tea')   || n.contains('lemonade'))
      return (Icons.local_drink_rounded, const Color(0xFFFFF8E1), const Color(0xFFF57F17));
    if (n.contains('water') || n.contains('sparkling'))
      return (Icons.water_drop_rounded, const Color(0xFFE3F2FD), const Color(0xFF1976D2));
    return (Icons.coffee_maker_rounded, const Color(0xFFF5F5F5), const Color(0xFF90A4AE));
  }
}

// ── Item Detail Sheet ─────────────────────────────────────────────────────────
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  static void show(BuildContext ctx, MenuItem item) => showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(item: item));

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  String?                  _selectedSize;
  final Map<String, String> _single = {};
  final Map<String, Set<String>> _multi = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty)
      _selectedSize = widget.item.sizes.first.label;
  }

  int get _unitPrice => widget.item.priceForSize(_selectedSize);
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
        itemName:   _normaliseName(widget.item.name),
        sizeLabel:  _selectedSize,
        unitPrice:  _unitPrice,
        quantity:   _qty,
        addons:     addons));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: const BoxDecoration(
          color: Color(0xFFFAF8F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDDD8D0),
                  borderRadius: BorderRadius.circular(2)))),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
          decoration: const BoxDecoration(
              color: Color(0xFFFAF8F5),
              border: Border(bottom: BorderSide(color: Color(0xFFECE8E0)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_normaliseName(widget.item.name),
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
                  position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(anim),
                  child: FadeTransition(opacity: anim, child: child)),
              child: Container(
                key: ValueKey(_unitPrice + _addonsTotal),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(egp(_unitPrice + _addonsTotal),
                    style: cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.item.sizes.isNotEmpty) ...[
                _SectionLabel('Size'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: widget.item.sizes.map((s) => _Chip(
                    label:    _normaliseName(s.label),
                    sublabel: egp(s.price),
                    selected: s.label == _selectedSize,
                    checkbox: false,
                    onTap:    () => setState(() => _selectedSize = s.label),
                  )).toList(),
                ),
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
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(22, 12, 22, MediaQuery.of(context).padding.bottom + 16),
          decoration: const BoxDecoration(
              color:  Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFECE8E0)))),
          child: Row(children: [
            Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F0EB), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(icon: Icons.remove,
                    onTap: () => setState(() => _qty = (_qty - 1).clamp(1, 99))),
                SizedBox(
                  width: 40,
                  child: Center(child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Text('$_qty', key: ValueKey(_qty),
                        style: cairo(fontSize: 16, fontWeight: FontWeight.w800)))),
                ),
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
    );
  }
}

// ── Option Group Card ─────────────────────────────────────────────────────────
class _OptionGroupCard extends StatefulWidget {
  final dynamic        group;
  final String?        selectedSingle;
  final Set<String>    selectedMulti;
  final void Function(String) onToggleSingle;
  final void Function(String) onToggleMulti;

  const _OptionGroupCard({
    required this.group,
    required this.selectedSingle,
    required this.selectedMulti,
    required this.onToggleSingle,
    required this.onToggleMulti,
  });
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
    final g        = widget.group;
    final allOpts  = g.items as List;
    final showSearch = allOpts.length > 5;
    final opts     = _query.isEmpty
        ? allOpts
        : allOpts.where((o) => (o.name as String).toLowerCase().contains(_query)).toList();
    final selCount = g.isMultiSelect
        ? widget.selectedMulti.length
        : (widget.selectedSingle != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selCount > 0
              ? AppColors.primary.withOpacity(0.2)
              : const Color(0xFFECE8E0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: Row(children: [
              Text(g.displayName.toString().toUpperCase(),
                  style: cairo(fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.7)),
              const SizedBox(width: 6),
              if (g.isRequired)   _Pill('Required', AppColors.danger),
              if (g.isMultiSelect)...[const SizedBox(width: 4), _Pill('Multi', AppColors.primary)],
            ])),
            if (selCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                child: Text('$selCount',
                    style: cairo(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
          ]),
        ),
        if (showSearch) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F0EB), borderRadius: BorderRadius.circular(9)),
              child: TextField(
                controller: _searchCtrl,
                style: cairo(fontSize: 13),
                decoration: InputDecoration(
                  hintText:   'Search options…',
                  hintStyle:  cairo(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 15, color: AppColors.textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(onTap: _searchCtrl.clear,
                          child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted))
                      : null,
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  isDense: true, filled: false,
                ),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: opts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('No options match "$_query"',
                      style: cairo(fontSize: 12, color: AppColors.textMuted)))
              : Wrap(
                  spacing: 7, runSpacing: 7,
                  children: opts.map((opt) {
                    final sel = g.isMultiSelect
                        ? widget.selectedMulti.contains(opt.id)
                        : widget.selectedSingle == opt.id;
                    return _Chip(
                      label:    _normaliseName(opt.name as String),
                      sublabel: (opt.price as int) > 0 ? '+${egp(opt.price as int)}' : null,
                      selected: sel,
                      checkbox: g.isMultiSelect,
                      onTap:    () => g.isMultiSelect
                          ? widget.onToggleMulti(opt.id as String)
                          : widget.onToggleSingle(opt.id as String),
                    );
                  }).toList(),
                ),
        ),
      ]),
    );
  }
}

// ── Cart Panel ────────────────────────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      width: 310,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(children: [
            Text('Order', style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            if (!cart.isEmpty) ...[
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(cart.count),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${cart.count}',
                      style: cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ),
            ],
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () => _confirmClear(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Clear',
                      style: cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
                ),
              ),
          ]),
        ),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  key: const ValueKey('items'),
                  padding: const EdgeInsets.all(10),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _CartRow(index: i)),
        )),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: cart.isEmpty ? const SizedBox.shrink() : _CartFooter(),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   Text('Clear Order?', style: cairo(fontWeight: FontWeight.w700)),
        content: Text('Remove all items from the cart.', style: cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: cairo(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.read<CartProvider>().clear(); },
            child: Text('Clear',
                style: cairo(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 130, height: 130,
              child: Lottie.asset('assets/lottie/empty_cart.json', fit: BoxFit.contain, repeat: true)),
          const SizedBox(height: 8),
          Text('Cart is empty',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Tap any item to add it', style: cairo(fontSize: 12, color: AppColors.textMuted)),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color:        const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(
              item.itemName + (item.sizeLabel != null ? ' · ${_normaliseName(item.sizeLabel!)}' : ''),
              style: cairo(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3))),
          const SizedBox(width: 8),
          Text(egp(item.lineTotal), style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        if (item.addons.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 4, runSpacing: 4,
            children: item.addons.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(
                a.priceModifier > 0
                    ? '${_normaliseName(a.name)} +${egp(a.priceModifier)}'
                    : _normaliseName(a.name),
                style: cairo(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
            )).toList(),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          _InlineBtn(icon: Icons.remove, onTap: () => cart.setQty(index, item.quantity - 1)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}',
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w700))),
          _InlineBtn(icon: Icons.add, onTap: () => cart.setQty(index, item.quantity + 1)),
          const Spacer(),
          GestureDetector(
            onTap: () => cart.removeAt(index),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.danger)),
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
      decoration: const BoxDecoration(
          color:  Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(children: [
        LabelValue('Subtotal', egp(cart.subtotal)),
        if (cart.discountAmount > 0)
          LabelValue('Discount', '− ${egp(cart.discountAmount)}',
              valueColor: AppColors.success),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(anim),
                  child: FadeTransition(opacity: anim, child: child)),
              child: Text(egp(cart.total),
                  key: ValueKey(cart.total),
                  style: cairo(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        AppButton(
          label:  'Checkout',
          width:  double.infinity,
          height: 50,
          icon:   Icons.arrow_forward_rounded,
          onTap:  () => CheckoutSheet.show(context),
        ),
      ]),
    );
  }
}

// ── Checkout Sheet — cash|card only, + customer name, + print trigger ─────────
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});
  static void show(BuildContext ctx) => showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutSheet());
  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool    _loading = false;
  String? _error;
  final   _customerCtrl = TextEditingController();

  // Only cash and card — per product decision
  static const _methods = ['cash', 'card'];

  @override
  void dispose() { _customerCtrl.dispose(); super.dispose(); }

  Future<void> _place() async {
    final cart  = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) { setState(() => _error = 'No open shift'); return; }
    final customer = _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim();
    setState(() { _loading = true; _error = null; });
    try {
      final order = await orderApi.create(
        branchId:      shift.branchId,
        shiftId:       shift.id,
        paymentMethod: cart.payment,
        items:         cart.items.toList(),
        customerName:  customer,
        discountType:  cart.discountTypeStr,
        discountValue: cart.discountValue,
      );
      context.read<OrderHistoryProvider>().addOrder(order);
      final total = cart.total;
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        // Show receipt sheet, which handles print
        ReceiptSheet.show(context, order: order, total: total);
      }
    } catch (e) {
      if (e is DioException)
        debugPrint('ORDER ${e.response?.statusCode}: ${e.response?.data}');
      setState(() { _error = 'Failed to place order — please retry'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),
        Text('Checkout', style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),

        // Order totals
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            LabelValue('Subtotal', egp(cart.subtotal)),
            if (cart.discountAmount > 0)
              LabelValue('Discount', '− ${egp(cart.discountAmount)}', valueColor: AppColors.success),
            const Divider(height: 16, color: Color(0xFFEEEEEE)),
            LabelValue('Total', egp(cart.total), bold: true),
          ]),
        ),
        const SizedBox(height: 18),

        // Customer name (optional)
        Text('CUSTOMER NAME (OPTIONAL)',
            style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller:         _customerCtrl,
          textCapitalization: TextCapitalization.words,
          style:              cairo(fontSize: 15),
          decoration: InputDecoration(
            hintText:  'e.g. Ahmed',
            hintStyle: cairo(fontSize: 15, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 18),

        // Payment method — cash | card only
        Text('PAYMENT',
            style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(children: _methods.map((m) {
          final sel   = cart.payment == m;
          final label = m[0].toUpperCase() + m.substring(1);
          final icon  = m == 'cash' ? Icons.payments_outlined : Icons.credit_card_rounded;
          return Expanded(
            child: GestureDetector(
              onTap: () => cart.setPayment(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color:        sel ? AppColors.primary : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: sel ? AppColors.primary : const Color(0xFFE8E8E8))),
                child: Column(children: [
                  Icon(icon, size: 22, color: sel ? Colors.white : AppColors.textSecondary),
                  const SizedBox(height: 6),
                  Text(label,
                      style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.textSecondary)),
                ]),
              ),
            ),
          );
        }).toList()),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
              const SizedBox(width: 8),
              Text(_error!, style: cairo(fontSize: 13, color: AppColors.danger)),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label:  'Place Order',
          loading: _loading,
          width:  double.infinity,
          height: 52,
          icon:   Icons.check_rounded,
          onTap:  _place,
        ),
      ]),
    );
  }
}

// ── Receipt Sheet — shows success + triggers print ────────────────────────────
class ReceiptSheet extends StatefulWidget {
  final Order order;
  final int   total;
  const ReceiptSheet({super.key, required this.order, required this.total});

  static void show(BuildContext ctx, {required Order order, required int total}) =>
      showModalBottomSheet(
          context: ctx, backgroundColor: Colors.transparent,
          builder: (_) => ReceiptSheet(order: order, total: total));

  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  bool    _printing = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    // Auto-print after slight delay so sheet is visible first
    WidgetsBinding.instance.addPostFrameCallback((_) => _print());
  }

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer configured for this branch'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() { _printing = true; _printError = null; });
    final err = await PrinterService.print(
      ip:         bp.printerIp!,
      port:       bp.printerPort,
      order:      widget.order,
      branchName: bp.branchName,
    );
    if (mounted) {
      setState(() { _printing = false; _printError = err; });
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        SizedBox(width: 120, height: 120,
            child: Lottie.asset('assets/lottie/success.json', repeat: false, fit: BoxFit.contain)),
        const SizedBox(height: 8),
        Text('Order Placed!', style: cairo(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Order #${o.orderNumber}',
            style: cairo(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            LabelValue('Payment', o.paymentMethod[0].toUpperCase() +
                o.paymentMethod.substring(1).replaceAll('_', ' ')),
            if (o.customerName != null && o.customerName!.isNotEmpty)
              LabelValue('Customer', o.customerName!),
            LabelValue('Total', egp(o.totalAmount), bold: true),
            LabelValue('Time',  timeShort(o.createdAt)),
          ]),
        ),
        const SizedBox(height: 16),

        // Print status / reprint button
        if (_printing)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            const SizedBox(width: 10),
            Text('Printing…', style: cairo(fontSize: 13, color: AppColors.textSecondary)),
          ])
        else
          GestureDetector(
            onTap: _print,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.print_rounded, size: 16,
                    color: _printError != null ? AppColors.danger : AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _printError != null ? 'Retry Print' : 'Reprint Receipt',
                  style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                      color: _printError != null ? AppColors.danger : AppColors.primary),
                ),
              ]),
            ),
          ),

        const SizedBox(height: 16),
        AppButton(
          label:  'New Order',
          width:  double.infinity,
          height: 52,
          icon:   Icons.add_rounded,
          onTap:  () => Navigator.pop(context),
        ),
      ]),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────
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
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: cairo(fontSize: 9, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.3)));
}

class _Chip extends StatelessWidget {
  final String   label;
  final String?  sublabel;
  final bool     selected;
  final bool     checkbox;
  final VoidCallback onTap;
  const _Chip({required this.label, this.sublabel, required this.selected,
      required this.checkbox, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color:        selected ? AppColors.primary : const Color(0xFFF5F0EB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE4DDD4),
                width: selected ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (checkbox) ...[
            Icon(selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 15, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary)),
          if (sublabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(sublabel!,
                  style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.primary)),
            ),
          ],
        ]),
      ));
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 38, height: 38, alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary)));
}

class _InlineBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _InlineBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFE0E0E0))),
        alignment: Alignment.center,
        child: Icon(icon, size: 13, color: AppColors.textPrimary)));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.textPrimary)));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
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

DART_EOF

# ────────────────────────────────────────────────────────────────────────
# lib/features/order/order_history_screen.dart
# ────────────────────────────────────────────────────────────────────────
write 'lib/features/order/order_history_screen.dart' << 'DART_EOF'

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
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Order History',
            style: cairo(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor:    Colors.white,
        elevation:          0,
        surfaceTintColor:   Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
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
          ? _placeholder('No open shift', icon: Icons.lock_outline_rounded, isTablet: isTablet)
          : history.loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : history.error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorBanner(message: history.error!, onRetry: _load),
                    )
                  : history.orders.isEmpty
                      ? _placeholder('No orders yet for this shift',
                          icon: Icons.receipt_long_outlined, isTablet: isTablet, useLottie: true)
                      : _buildList(history.orders, isTablet),
    );
  }

  Widget _buildList(List<Order> orders, bool isTablet) {
    final total = orders
        .where((o) => o.status != 'voided')
        .fold(0, (s, o) => s + o.totalAmount);
    final count = orders.where((o) => o.status != 'voided').length;

    return Column(children: [
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 14),
        child: Row(children: [
          _StatChip(label: 'Orders',      value: '$count',    color: AppColors.primary),
          const SizedBox(width: 10),
          _StatChip(label: 'Total Sales', value: egp(total), color: AppColors.success),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),
      Expanded(
        child: isTablet
            ? _TwoColumnList(orders: orders)
            : ListView.builder(
                padding:     const EdgeInsets.all(16),
                itemCount:   orders.length,
                itemBuilder: (_, i) => _OrderTile(order: orders[i]),
              ),
      ),
    ]);
  }

  Widget _placeholder(String msg,
      {required IconData icon, required bool isTablet, bool useLottie = false}) =>
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (useLottie) ...[
            SizedBox(
              width: isTablet ? 200 : 160, height: isTablet ? 200 : 160,
              child: Lottie.asset('assets/lottie/no_orders.json',
                  fit: BoxFit.contain, repeat: true),
            ),
          ] else ...[
            Icon(icon, size: isTablet ? 56 : 48, color: AppColors.border),
            const SizedBox(height: 12),
          ],
          Text(msg, style: cairo(fontSize: isTablet ? 17 : 15, color: AppColors.textSecondary)),
        ]),
      );
}

// ── Two Column List ───────────────────────────────────────────────────────────
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
          mainAxisExtent:     100,
        ),
        itemCount:   orders.length,
        itemBuilder: (_, i) => _OrderTile(order: orders[i]),
      );
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: cairo(fontSize: 12, fontWeight: FontWeight.w500, color: color.withOpacity(0.8))),
          const SizedBox(width: 8),
          Text(value,
              style: cairo(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
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
      if (mounted) {
        setState(() => _loading = false);
        _OrderDetailSheet.show(context, full);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o        = widget.order;
    final isVoided = o.status == 'voided';

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:        isVoided ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: isVoided ? AppColors.border : const Color(0xFFEEEEEE)),
          boxShadow: isVoided
              ? []
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isVoided ? AppColors.border : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text('#${o.orderNumber}',
                    style: cairo(fontSize: 12, fontWeight: FontWeight.w800,
                        color: isVoided ? AppColors.textMuted : AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _PaymentBadge(method: o.paymentMethod, voided: isVoided),
                    if (isVoided) ...[const SizedBox(width: 6), _VoidedBadge()],
                    const Spacer(),
                    Text(timeShort(o.createdAt),
                        style: cairo(fontSize: 11, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 5),
                  Text(egp(o.totalAmount),
                      style: cairo(fontSize: 16, fontWeight: FontWeight.w800,
                          color: isVoided ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: isVoided ? TextDecoration.lineThrough : null)),
                  if (o.customerName != null) ...[
                    const SizedBox(height: 2),
                    Text(o.customerName!,
                        style: cairo(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ]),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String method;
  final bool   voided;
  const _PaymentBadge({required this.method, required this.voided});
  @override
  Widget build(BuildContext context) {
    final label = method[0].toUpperCase() + method.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: voided ? AppColors.borderLight : AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
              color: voided ? AppColors.textMuted : AppColors.primary, letterSpacing: 0.2)),
    );
  }
}

class _VoidedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text('VOIDED',
          style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.danger, letterSpacing: 0.3)));
}

// ── Order Detail Sheet with Print button ──────────────────────────────────────
class _OrderDetailSheet extends StatefulWidget {
  final Order order;
  const _OrderDetailSheet({required this.order});

  static void show(BuildContext ctx, Order order) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderDetailSheet(order: order),
      );

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool    _printing = false;
  String? _printError;

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('No printer configured for this branch'),
          backgroundColor: AppColors.warning,
          duration:        Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() { _printing = true; _printError = null; });
    final err = await PrinterService.print(
      ip:         bp.printerIp!,
      port:       bp.printerPort,
      order:      widget.order,
      branchName: bp.branchName,
    );
    if (mounted) {
      setState(() { _printing = false; _printError = err; });
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order    = widget.order;
    final isVoided = order.status == 'voided';
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth:  isTablet ? 600 : double.infinity,
      ),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2)))),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${order.orderNumber}',
                  style: cairo(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(dateTime(order.createdAt),
                  style: cairo(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const Spacer(),
            // Print button
            if (!isVoided)
              _printing
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : GestureDetector(
                      onTap: _print,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _printError != null
                              ? AppColors.danger.withOpacity(0.08)
                              : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.print_rounded, size: 15,
                              color: _printError != null ? AppColors.danger : AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_printError != null ? 'Retry' : 'Print',
                              style: cairo(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: _printError != null ? AppColors.danger : AppColors.primary)),
                        ]),
                      ),
                    ),
            if (isVoided) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('VOIDED',
                    style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.danger, letterSpacing: 0.4)),
              ),
            ],
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (order.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No item details available',
                      style: cairo(fontSize: 13, color: AppColors.textMuted)),
                )
              else
                ...order.items.map((item) => _ItemRow(item: item)),
              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              LabelValue('Subtotal', egp(order.subtotal)),
              if (order.discountAmount > 0)
                LabelValue('Discount', '− ${egp(order.discountAmount)}',
                    valueColor: AppColors.success),
              if (order.taxAmount > 0) LabelValue('Tax', egp(order.taxAmount)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(egp(order.totalAmount),
                      style: cairo(fontSize: 17, fontWeight: FontWeight.w800,
                          color: isVoided ? AppColors.textMuted : AppColors.primary,
                          decoration: isVoided ? TextDecoration.lineThrough : null)),
                ]),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              LabelValue('Payment',
                  order.paymentMethod[0].toUpperCase() + order.paymentMethod.substring(1)),
              if (order.customerName != null) LabelValue('Customer', order.customerName!),
              if (order.tellerName.isNotEmpty) LabelValue('Teller', order.tellerName),
              LabelValue('Time', timeShort(order.createdAt)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  const _ItemRow({required this.item});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: AppColors.borderLight, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text('${item.quantity}',
              style: cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              item.itemName + (item.sizeLabel != null ? ' · ${item.sizeLabel}' : ''),
              style: cairo(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (item.addons.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: item.addons.map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(
                    a.unitPrice > 0 ? '${a.addonName} +${egp(a.unitPrice)}' : a.addonName,
                    style: cairo(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                )).toList(),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        Text(egp(item.lineTotal),
            style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

DART_EOF


# =============================================================================
#  flutter pub get
# =============================================================================
echo ""
echo "==> Running flutter pub get..."
cd "$PROJ" && flutter pub get

echo ""
echo "========================================"
echo "  RuePOS update complete!"
echo "========================================"
echo ""
echo "Files updated (13 total):"
echo "  + lib/core/models/branch.dart"
echo "  + lib/core/models/order.dart"
echo "  + lib/core/api/branch_api.dart"
echo "  + lib/core/api/shift_api.dart"
echo "  + lib/core/providers/branch_provider.dart"
echo "  + lib/core/providers/auth_provider.dart"
echo "  + lib/core/services/printer_service.dart"
echo "  + lib/core/router/router.dart"
echo "  + lib/main.dart"
echo "  + lib/features/home/home_screen.dart"
echo "  + lib/features/shift/shift_history_screen.dart"
echo "  + lib/features/order/order_screen.dart"
echo "  + lib/features/order/order_history_screen.dart"
echo ""
echo "Printer notes:"
echo "  - Set printer_ip + printer_port on the branch in the dashboard"
echo "  - No printer configured => snackbar: 'No printer configured for this branch'"
echo "  - Auto-prints after every order placement"
echo "  - Manual reprint from order detail sheets"
echo ""