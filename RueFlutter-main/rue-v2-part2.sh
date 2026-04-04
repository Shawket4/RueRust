#!/usr/bin/env bash
# =============================================================================
#  RuePOS v2 — Part 2: Router, all screens, main.dart
#  Run from your Flutter project root AFTER part1.
#  Usage: chmod +x rue_pos_v2_part2.sh && ./rue_pos_v2_part2.sh
# =============================================================================
set -euo pipefail
echo "🚀  RuePOS v2 Part 2 — writing router, screens, main..."

mkdir -p lib/{core/router,features/{auth,home,order,shift}}

# =============================================================================
# ROUTER
# =============================================================================

cat > lib/core/router/router.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/order/order_history_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/shift/close_shift_screen.dart';
import '../../features/shift/open_shift_screen.dart';
import '../../features/shift/shift_history_screen.dart';
import '../providers/auth_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth    = ref.read(authProvider);
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
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
DART

# =============================================================================
# MAIN
# =============================================================================

cat > lib/main.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/auth_notifier.dart';
import 'core/providers/order_history_notifier.dart';
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
      final queue   = ref.read(offlineQueueProvider.notifier);
      final history = ref.read(orderHistoryProvider.notifier);
      queue.onOrderSynced = history.addOrder;
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
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/TheRue.png', height: 64),
          const SizedBox(height: 32),
          const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary)),
        ]),
      ),
    ),
  );
}
DART

# =============================================================================
# LOGIN SCREEN
# =============================================================================

cat > lib/features/auth/login_screen.dart << 'DART'
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
  String  _pin     = '';
  bool    _loading = false;
  String? _error;
  static const _max = 6;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

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
      _shakeCtrl.forward(from: 0);
      return;
    }
    if (_pin.length < 4) return;

    setState(() { _loading = true; _error = null; });

    final err = await ref.read(authProvider.notifier)
        .login(name: name, pin: _pin);

    if (!mounted) return;

    if (err != null) {
      setState(() { _error = err; _pin = ''; _loading = false; });
      _shakeCtrl.forward(from: 0);
    }
    // On success the router redirect navigates automatically
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiry   = ref.watch(authProvider.select((s) => s.sessionExpiry));
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isTablet
          ? _TabletLayout(form: _buildForm(expiry))
          : _buildForm(expiry),
    );
  }

  Widget _buildForm(SessionExpiry expiry) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/TheRue.png', height: 52),
            const SizedBox(height: 10),
            Text('Point of Sale', style: cairo(fontSize: 12,
                fontWeight: FontWeight.w600, color: AppColors.textMuted,
                letterSpacing: 1.2)),
            const SizedBox(height: 20),

            // ── Session expiry banner ─────────────────────────────────────
            if (expiry == SessionExpiry.expired)
              _InfoBanner(
                icon: Icons.lock_clock_outlined,
                text: 'Your session expired — please sign in again.',
                color: AppColors.warning,
              ),

            // ── Blocked by another teller's shift ─────────────────────────
            if (expiry == SessionExpiry.blockedByOtherShift && _error != null)
              _InfoBanner(
                icon: Icons.block_rounded,
                text: _error!,
                color: AppColors.danger,
                bold: true,
              ),

            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Sign in', style: cairo(fontSize: 12,
                    fontWeight: FontWeight.w600, color: AppColors.textMuted,
                    letterSpacing: 0.5)),
              ),
              const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
            ]),
            const SizedBox(height: 24),

            // ── Name field ────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) =>
                  Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
              child: TextField(
                controller: _nameCtrl,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _error = null),
                style: cairo(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── PIN pad ───────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) =>
                  Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
              child: PinPad(pin: _pin, maxLength: _max,
                  onDigit: _digit, onBackspace: _back),
            ),

            // ── Inline error (non-block errors only) ──────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: (_error != null &&
                      expiry != SessionExpiry.blockedByOtherShift)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.danger.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 15, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Flexible(child: Text(_error!, style: cairo(
                              fontSize: 13, color: AppColors.danger))),
                        ]),
                      ))
                  : const SizedBox.shrink(),
            ),

            if (_loading) ...[
              const SizedBox(height: 28),
              const CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ],
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    color;
  final bool     bold;
  const _InfoBanner({required this.icon, required this.text,
      required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: cairo(fontSize: 13, color: color,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
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
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/TheRue.png', height: 60,
                    color: Colors.white, colorBlendMode: BlendMode.srcIn),
                const SizedBox(height: 32),
                Text('Welcome back.', style: cairo(fontSize: 38,
                    fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                const SizedBox(height: 14),
                Text('Sign in to start your shift\nand manage orders.',
                    style: cairo(fontSize: 16,
                        color: Colors.white.withOpacity(0.75), height: 1.6)),
              ],
            ),
          ),
        ),
      ),
    ),
    Expanded(flex: 4, child: Container(color: Colors.white, child: form)),
  ]);
}
DART

# =============================================================================
# HOME SCREEN
# =============================================================================

cat > lib/features/home/home_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/shift.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/order_history_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';

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

  /// Logout guard: if shift is open, force close-shift first.
  Future<void> _onSignOut() async {
    final canLeave = await ref.read(authProvider.notifier).canLogout();
    if (!mounted) return;
    if (canLeave) {
      await ref.read(authProvider.notifier).logout();
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Close Shift First',
              style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'You have an open shift. You must close it before signing out.',
            style: cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: cairo(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/close-shift');
              },
              child: Text('Close Shift', style: cairo(
                  color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authProvider).user!;
    final shiftSt  = ref.watch(shiftProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 36 : 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Image.asset('assets/TheRue.png', height: isTablet ? 52 : 44),
              const Spacer(),
              Text(user.name, style: cairo(
                  fontSize: isTablet ? 14 : 13, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              _SignOutBtn(onTap: _onSignOut),
            ]),
            SizedBox(height: isTablet ? 36 : 28),

            Text(_greet(user.name.split(' ').first), style: cairo(
                fontSize: isTablet ? 28 : 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(user.role.replaceAll('_', ' ').toUpperCase(),
                style: cairo(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textMuted, letterSpacing: 1)),
            SizedBox(height: isTablet ? 32 : 24),

            if (shiftSt.isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else if (shiftSt.error != null && !shiftSt.hasOpenShift)
              _ErrorBanner(message: shiftSt.error!, onRetry: _load)
            else if (shiftSt.hasOpenShift)
              _OpenShiftView(shift: shiftSt.shift!, shiftState: shiftSt,
                  onRefresh: _load, isTablet: isTablet)
            else
              _NoShiftView(suggested: shiftSt.suggestedOpeningCash, isTablet: isTablet),
          ]),
        ),
      ),
    );
  }

  String _greet(String first) {
    final h = DateTime.now().hour;
    final w = h < 12 ? 'Morning' : h < 17 ? 'Afternoon' : 'Evening';
    return 'Good $w, $first';
  }
}

// ── Open Shift View ────────────────────────────────────────────────────────────
class _OpenShiftView extends ConsumerWidget {
  final Shift      shift;
  final ShiftState shiftState;
  final VoidCallback onRefresh;
  final bool       isTablet;

  const _OpenShiftView({required this.shift, required this.shiftState,
      required this.onRefresh, required this.isTablet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync     = ref.watch(offlineQueueProvider);
    final history  = ref.watch(orderHistoryProvider);
    final isOnline = ref.watch(isOnlineProvider);

    final active     = history.orders.where((o) => o.status != 'voided').toList();
    final orderCount = active.length;
    final salesTotal = active.fold(0, (s, o) => s + o.totalAmount);
    final statsReady = !shiftState.systemCashLoading;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(isTablet ? 30 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isOnline)
            _Banner(icon: Icons.wifi_off_rounded,
                text: 'Offline — cached data shown. Orders queue until online.'),
          if (isOnline && history.fromCache)
            _Banner(icon: Icons.history_rounded,
                text: 'Showing cached stats — tap refresh to update.'),
          if (isOnline && sync.count > 0)
            _Banner(icon: Icons.sync_rounded, animate: true,
                text: 'Syncing ${sync.count} offline order${sync.count == 1 ? "" : "s"}…'),
          if (sync.hasStuck)
            _Banner(icon: Icons.warning_amber_rounded, warn: true,
                text: '${sync.stuckCount} order${sync.stuckCount == 1 ? "" : "s"} '
                    'failed to sync — check connection or discard.'),

          Row(children: [
            _StatusPill(),
            const Spacer(),
            Text('Since ${timeShort(shift.openedAt)}',
                style: cairo(fontSize: 11, color: Colors.white60)),
            const SizedBox(width: 8),
            GestureDetector(onTap: onRefresh,
                child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white54)),
          ]),
          SizedBox(height: isTablet ? 26 : 20),

          Row(children: [
            _ShiftStat(label: 'Sales', value: egp(salesTotal),
                loading: !statsReady, isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(label: 'Orders', value: '$orderCount',
                loading: !statsReady, isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(label: 'System Cash', value: egp(shiftState.systemCash),
                sublabel: '${egp(shift.openingCash)} opening',
                loading: shiftState.systemCashLoading, isTablet: isTablet),
          ]),
          SizedBox(height: isTablet ? 28 : 22),

          Row(children: [
            Expanded(child: _CardBtn(label: 'New Order',
                icon: Icons.add_shopping_cart_rounded,
                onTap: () => context.go('/order'), isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(label: 'History',
                icon: Icons.receipt_long_rounded,
                onTap: () => context.go('/order-history'), isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(label: 'Shifts',
                icon: Icons.history_rounded,
                onTap: () => context.go('/shift-history'), isTablet: isTablet)),
            const SizedBox(width: 8),
            Expanded(child: _CardBtn(
              label: 'Close', icon: Icons.lock_outline_rounded,
              danger: true, isTablet: isTablet,
              onTap: !isOnline
                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Internet required to close shift'),
                      backgroundColor: Color(0xFF856404)))
                  : () => _confirmClose(context),
            )),
          ]),
        ]),
      ),
    ]);
  }

  void _confirmClose(BuildContext context) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Close Shift?', style: cairo(fontWeight: FontWeight.w800)),
      content: Text('You will count cash and inventory on the next screen.',
          style: cairo(fontSize: 14, color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: cairo(color: AppColors.textSecondary))),
        TextButton(
          onPressed: () { Navigator.pop(ctx); context.go('/close-shift'); },
          child: Text('Continue', style: cairo(
              color: AppColors.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ── No Shift View ──────────────────────────────────────────────────────────────
class _NoShiftView extends StatelessWidget {
  final int suggested; final bool isTablet;
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
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.wb_sunny_outlined,
                      color: AppColors.primary, size: 22)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No Open Shift', style: cairo(
                    fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.w700)),
                if (suggested > 0)
                  Text('Last closing: ${egp(suggested)}',
                      style: cairo(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 22),
            AppButton(label: 'Open Shift', width: double.infinity,
                icon: Icons.play_arrow_rounded,
                onTap: () => context.go('/open-shift')),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 480 : double.infinity),
        child: OutlinedButton.icon(
          onPressed: () => context.go('/shift-history'),
          icon: const Icon(Icons.history_rounded, size: 16),
          label: Text('View Shift History', style: cairo(fontSize: 14)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: AppColors.border),
            foregroundColor: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

// ── Shared small widgets ────────────────────────────────────────────────────────
class _SignOutBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border)),
      alignment: Alignment.center,
      child: const Icon(Icons.logout_rounded, size: 15,
          color: AppColors.textSecondary),
    ),
  );
}

class _Banner extends StatelessWidget {
  final IconData icon; final String text;
  final bool animate, warn;
  const _Banner({required this.icon, required this.text,
      this.animate = false, this.warn = false});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: warn ? Colors.orange.withOpacity(0.25) : Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      animate
          ? SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5,
                  color: warn ? Colors.orange : Colors.white70))
          : Icon(icon, size: 13, color: warn ? Colors.orange : Colors.white70),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: cairo(fontSize: 11,
          color: warn ? Colors.orange : Colors.white70))),
    ]),
  );
}

class _StatusPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7,
          decoration: const BoxDecoration(
              color: Color(0xFF4ADE80), shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('SHIFT OPEN', style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: 0.8)),
    ]),
  );
}

class _ShiftStat extends StatelessWidget {
  final String label, value; final String? sublabel;
  final bool loading, isTablet;
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
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
    width: 1, height: 44, color: Colors.white.withOpacity(0.15),
    margin: const EdgeInsets.symmetric(horizontal: 14),
  );
}

class _CardBtn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap; final bool danger, isTablet;
  const _CardBtn({required this.label, required this.icon, required this.onTap,
      this.danger = false, this.isTablet = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 11),
      decoration: BoxDecoration(
          color: danger ? Colors.white.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: isTablet ? 18 : 16,
            color: danger ? Colors.white : AppColors.primary),
        const SizedBox(height: 4),
        Text(label, style: cairo(fontSize: isTablet ? 12 : 11,
            fontWeight: FontWeight.w700,
            color: danger ? Colors.white : AppColors.primary)),
      ]),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.2))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: cairo(fontSize: 13, color: AppColors.danger))),
      TextButton(onPressed: onRetry,
          child: Text('Retry', style: cairo(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.primary))),
    ]),
  );
}
DART

# =============================================================================
# OPEN SHIFT SCREEN
# =============================================================================

cat > lib/features/shift/open_shift_screen.dart << 'DART'
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
  bool    _loading = false;
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
    setState(() { _loading = true; _error = null; });
    final ok = await ref.read(shiftProvider.notifier)
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
    final isTablet  = MediaQuery.of(context).size.width >= 768;
    final isOnline  = ref.watch(isOnlineProvider);
    final suggested = ref.watch(shiftProvider.select((s) => s.suggestedOpeningCash));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: const Text('Open Shift'),
        elevation: 0, backgroundColor: AppColors.bg,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 520 : 480),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 32 : 24),
            child: CardContainer(
              padding: EdgeInsets.all(isTablet ? 36 : 28),
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: AppColors.primary, size: 22)),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Open New Shift', style: cairo(
                        fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.w800)),
                    Text('Enter the opening cash amount',
                        style: cairo(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ]),
                const SizedBox(height: 28),

                if (suggested > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.15))),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Suggested from last close: ${egp(suggested)}',
                            style: cairo(fontSize: 12, color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),

                Text('OPENING CASH', style: cairo(fontSize: 11,
                    fontWeight: FontWeight.w700, color: AppColors.textMuted,
                    letterSpacing: 1.0)),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl, autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: cairo(fontSize: isTablet ? 34 : 30,
                      fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: 'EGP  ',
                    prefixStyle: cairo(fontSize: isTablet ? 22 : 20,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                    hintText: '0',
                    hintStyle: cairo(fontSize: isTablet ? 34 : 30,
                        fontWeight: FontWeight.w800, color: AppColors.border),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const Divider(color: Color(0xFFEEEEEE), height: 20),
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
                            Flexible(child: Text(_error!, style: cairo(
                                fontSize: 13, color: AppColors.danger))),
                          ]))
                      : const SizedBox.shrink(),
                ),

                if (!isOnline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFFD700))),
                      child: Row(children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 14, color: Color(0xFF856404)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                            'Internet required to open a shift.',
                            style: cairo(fontSize: 12,
                                color: const Color(0xFF856404)))),
                      ]),
                    ),
                  ),

                AppButton(
                  label: 'Open Shift', loading: _loading,
                  width: double.infinity, icon: Icons.play_arrow_rounded,
                  onTap: (!isOnline || _loading) ? null : _open,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
DART

# =============================================================================
# CLOSE SHIFT SCREEN
# =============================================================================

cat > lib/features/shift/close_shift_screen.dart << 'DART'
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
import '../../shared/widgets/label_value.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});
  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Map<String, TextEditingController> _invCtrs = {};
  final Map<String, bool> _zeroWarn = {};

  bool    _loadingInv = true;
  bool    _submitting = false;
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

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }

    final inv = ref.read(shiftProvider).inventory;
    final zeroItems = inv.where((i) {
      final v = double.tryParse(_invCtrs[i.id]?.text ?? '');
      return v == null || v == 0.0;
    }).map((i) => i.name).toList();

    if (zeroItems.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Zero Stock Warning',
              style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'The following items have 0 stock:\n\n${zeroItems.join(", ")}'
            '\n\nAre you sure you want to submit?',
            style: cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Go Back', style: cairo(color: AppColors.primary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Submit Anyway', style: cairo(
                    color: AppColors.danger, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() { _submitting = true; _error = null; });

    final counts = _invCtrs.entries.map((e) => {
      'inventory_item_id': e.key,
      'actual_stock': double.tryParse(e.value.text) ?? 0.0,
    }).toList();

    final branchId = ref.read(authProvider).user!.branchId!;
    final ok = await ref.read(shiftProvider.notifier).closeShift(
      branchId:        branchId,
      closingCash:     (raw * 100).round(),
      note:            _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      inventoryCounts: counts,
    );

    if (!mounted) return;

    if (ok) {
      // Shift is now closed — check if we should logout (user came from logout guard)
      final canNowLogout = await ref.read(authProvider.notifier).canLogout();
      if (!mounted) return;
      if (canNowLogout) {
        // Logout was pending, complete it now
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.go('/login');
      } else {
        context.go('/home');
      }
    } else {
      setState(() {
        _error = ref.read(shiftProvider).error ?? 'Failed to close shift';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift    = ref.watch(shiftProvider).shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You must close the shift before leaving.'),
            backgroundColor: AppColors.warning,
          ));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.lock_outline_rounded,
                color: AppColors.danger, size: 20),
          ),
          title: Text('Close Shift', style: cairo(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0F0F0)),
          ),
        ),
        body: shift == null
            ? const Center(child: Text('No open shift'))
            : isTablet
                ? _buildTablet(shift)
                : _buildPhone(shift),
      ),
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
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child: _SubmitSection(state: this),
    ),
  ]);
}

// ── Sub-cards ───────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final dynamic shift;
  const _SummaryCard({required this.shift});
  @override
  Widget build(BuildContext context) => CardContainer(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.summarize_outlined,
                color: AppColors.primary, size: 18)),
        const SizedBox(width: 12),
        Text('Shift Summary', style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 16),
      LabelValue('Teller', shift.tellerName),
      LabelValue('Opening Cash', egp(shift.openingCash)),
      LabelValue('Opened At', dateTime(shift.openedAt)),
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
        Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.payments_outlined,
                  color: AppColors.success, size: 18)),
          const SizedBox(width: 12),
          Text('Cash Count', style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 18),
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
            cashLoading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: AppColors.primary))
                : Text(egp(systemCash), style: cairo(
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('ACTUAL CASH IN DRAWER', style: cairo(fontSize: 11,
            fontWeight: FontWeight.w700, color: AppColors.textMuted,
            letterSpacing: 1.0)),
        const SizedBox(height: 8),
        TextField(
          controller: state._cashCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: cairo(fontSize: 28, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: 'EGP  ',
            prefixStyle: cairo(fontSize: 20, color: AppColors.textSecondary),
            hintText: '0',
            hintStyle: cairo(fontSize: 28, fontWeight: FontWeight.w800,
                color: AppColors.border),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: showDiscrep
              ? Padding(padding: const EdgeInsets.only(top: 12),
                  child: _DiscrepancyRow(
                      discrepancy: discrepancy, systemCash: systemCash))
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: state._noteCtrl,
          decoration: InputDecoration(
            hintText: 'Cash note (optional)',
            hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
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
        Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.warning, size: 18)),
          const SizedBox(width: 12),
          Text('Inventory Count',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
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
                  Text(item.name, style: cairo(
                      fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('System: ${item.currentStock} ${item.unit}',
                      style: cairo(fontSize: 12, color: AppColors.textSecondary)),
                  if (warn)
                    Text('⚠ Value is 0 — confirm this is correct',
                        style: cairo(fontSize: 11, color: AppColors.warning)),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 130, child: TextField(
                  controller: state._invCtrs[item.id],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w600,
                      color: warn ? AppColors.warning : AppColors.textPrimary),
                  decoration: InputDecoration(
                    suffixText: item.unit,
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
        curve: Curves.easeOut,
        child: state._error != null
            ? Padding(padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Flexible(child: Text(state._error!, style: cairo(
                        fontSize: 13, color: AppColors.danger))),
                  ]),
                ))
            : const SizedBox.shrink(),
      ),
      if (!isOnline)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD700))),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 14, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              Expanded(child: Text('Internet required to close a shift.',
                  style: cairo(fontSize: 12,
                      color: const Color(0xFF856404)))),
            ]),
          ),
        ),
      AppButton(
        label: 'Close Shift',
        variant: BtnVariant.danger,
        loading: state._submitting,
        width: double.infinity,
        icon: Icons.lock_outline_rounded,
        onTap: (!isOnline || state._submitting) ? null : state._close,
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
    final icon    = isExact ? Icons.check_circle_rounded
        : isOver ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label   = isExact ? 'Exact match'
        : isOver
            ? 'Over by ${egp(discrepancy.abs())}'
            : 'Short by ${egp(discrepancy.abs())}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: cairo(
            fontSize: 13, fontWeight: FontWeight.w600, color: color)),
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
# SHIFT HISTORY SCREEN
# =============================================================================

cat > lib/features/shift/shift_history_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/order_api.dart';
import '../../core/api/shift_api.dart';
import '../../core/models/order.dart';
import '../../core/models/shift.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';

class ShiftHistoryScreen extends ConsumerStatefulWidget {
  const ShiftHistoryScreen({super.key});
  @override
  ConsumerState<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends ConsumerState<ShiftHistoryScreen> {
  List<Shift> _shifts = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) {
      setState(() { _loading = false; _error = 'No branch assigned'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final shifts = await ref.read(shiftApiProvider).list(branchId);
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
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: Text('Shift History', style: cairo(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: Colors.white, elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0F0F0))),
        actions: [IconButton(
            icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Padding(padding: const EdgeInsets.all(24),
                  child: ErrorBanner(message: _error!, onRetry: _load))
              : _shifts.isEmpty
                  ? Center(child: Text('No shifts found',
                      style: cairo(fontSize: 15, color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: EdgeInsets.all(isTablet ? 24 : 16),
                      itemCount: _shifts.length,
                      itemBuilder: (_, i) => _ShiftTile(shift: _shifts[i])),
    );
  }
}

class _ShiftTile extends ConsumerStatefulWidget {
  final Shift shift;
  const _ShiftTile({required this.shift});
  @override
  ConsumerState<_ShiftTile> createState() => _ShiftTileState();
}

class _ShiftTileState extends ConsumerState<_ShiftTile> {
  bool        _expanded = false, _loadingOrders = false;
  List<Order> _orders   = [];
  String?     _ordersError;

  Future<void> _toggleOrders() async {
    if (_orders.isNotEmpty) {
      setState(() => _expanded = !_expanded);
      return;
    }
    setState(() { _loadingOrders = true; _expanded = true; });
    try {
      final orders = await ref.read(orderApiProvider).list(shiftId: widget.shift.id);
      if (mounted) setState(() { _orders = orders; _loadingOrders = false; });
    } catch (e) {
      if (mounted) setState(() { _ordersError = e.toString(); _loadingOrders = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final statusColor = s.status == 'open' ? AppColors.success
        : s.status == 'force_closed' ? AppColors.danger
        : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        InkWell(borderRadius: BorderRadius.circular(16), onTap: _toggleOrders,
          child: Padding(padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.tellerName, style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(dateTime(s.openedAt),
                    style: cairo(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(s.status.replaceAll('_', ' ').toUpperCase(),
                      style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                          color: statusColor))),
                if (s.closingCashDeclared != null) ...[
                  const SizedBox(height: 4),
                  Text(egp(s.closingCashDeclared!),
                      style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ]),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: AppColors.border),
          if (_loadingOrders)
            const Padding(padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)))
          else if (_ordersError != null)
            Padding(padding: const EdgeInsets.all(12),
                child: Text(_ordersError!, style: cairo(
                    fontSize: 12, color: AppColors.danger)))
          else if (_orders.isEmpty)
            Padding(padding: const EdgeInsets.all(16),
                child: Text('No orders in this shift',
                    style: cairo(fontSize: 13, color: AppColors.textMuted)))
          else
            ..._orders.map((o) => _PastOrderRow(order: o)),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

class _PastOrderRow extends ConsumerStatefulWidget {
  final Order order;
  const _PastOrderRow({required this.order});
  @override
  ConsumerState<_PastOrderRow> createState() => _PastOrderRowState();
}

class _PastOrderRowState extends ConsumerState<_PastOrderRow> {
  bool _printing = false;

  Future<void> _print() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No printer configured'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _printing = true);
    try {
      Order full;
      try { full = await ref.read(orderApiProvider).get(widget.order.id); }
      catch (_) { full = widget.order; }
      final err = await PrinterService.print(
          ip: branch.printerIp!, port: branch.printerPort,
          order: full, branchName: branch.name, brand: branch.printerBrand!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Receipt printed'),
        backgroundColor: err != null ? AppColors.danger : AppColors.success));
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
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: isVoided ? AppColors.borderLight
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text('#${o.orderNumber}', style: cairo(fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isVoided ? AppColors.textMuted : AppColors.primary))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(timeShort(o.createdAt),
              style: cairo(fontSize: 12, color: AppColors.textSecondary)),
          if (o.customerName != null)
            Text(o.customerName!,
                style: cairo(fontSize: 11, color: AppColors.textMuted)),
        ])),
        Text(egp(o.totalAmount), style: cairo(fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isVoided ? AppColors.textMuted : AppColors.textPrimary,
            decoration: isVoided ? TextDecoration.lineThrough : null)),
        const SizedBox(width: 8),
        if (!isVoided)
          _printing
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: AppColors.primary))
              : GestureDetector(onTap: _print,
                  child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.print_rounded,
                          size: 15, color: AppColors.primary))),
      ]),
    );
  }
}
DART

# =============================================================================
# VOID ORDER SHEET
# =============================================================================

cat > lib/features/order/void_order_sheet.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/order_api.dart';
import '../../core/models/order.dart';
import '../../core/theme/app_theme.dart';

class VoidOrderSheet extends ConsumerStatefulWidget {
  final Order order;
  final void Function(Order) onVoided;
  const VoidOrderSheet(
      {super.key, required this.order, required this.onVoided});

  static Future<void> show(
      BuildContext ctx, Order order, void Function(Order) onVoided) =>
      showModalBottomSheet(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              VoidOrderSheet(order: order, onVoided: onVoided));

  @override
  ConsumerState<VoidOrderSheet> createState() => _VoidOrderSheetState();
}

class _VoidOrderSheetState extends ConsumerState<VoidOrderSheet> {
  String? _reason;
  bool    _restore = true, _loading = false;
  String? _error;

  static const _reasons = [
    ('customer_request', 'Customer request'),
    ('wrong_order',      'Wrong order'),
    ('quality_issue',    'Quality issue'),
    ('other',            'Other'),
  ];

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final updated = await ref.read(orderApiProvider).voidOrder(
          widget.order.id,
          reason: _reason,
          restoreInventory: _restore);
      if (mounted) { Navigator.pop(context); widget.onVoided(updated); }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24)),
    child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.border,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Text('Void Order #${widget.order.orderNumber}',
          style: cairo(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('This action cannot be undone',
          style: cairo(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      Text('Reason', style: cairo(fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      ...(_reasons.map((r) => RadioListTile<String>(
        value: r.$1, groupValue: _reason,
        onChanged: (v) => setState(() => _reason = v),
        title: Text(r.$2, style: cairo(fontSize: 14)),
        contentPadding: EdgeInsets.zero, dense: true,
      ))),
      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Restore inventory',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Return ingredients to stock',
              style: cairo(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Switch(value: _restore,
            onChanged: (v) => setState(() => _restore = v),
            activeColor: AppColors.primary),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.danger.withOpacity(0.2))),
            child: Text(_error!,
                style: cairo(fontSize: 12, color: AppColors.danger))),
      ],
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.border),
              foregroundColor: AppColors.textSecondary),
          child: Text('Cancel',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0),
          child: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Void Order', style: cairo(fontSize: 14,
                  fontWeight: FontWeight.w700, color: Colors.white)),
        )),
      ]),
    ]),
  );
}
DART

# =============================================================================
# ORDER SCREEN + ORDER HISTORY SCREEN
# These are identical UI to v1 — only provider calls change.
# Written as stub placeholders with a clear substitution guide.
# Apply the guide to your v1 files to complete them.
# =============================================================================

cat > lib/features/order/order_screen.dart << 'DART'
// ============================================================================
//  ORDER SCREEN — Copy your v1 order_screen.dart here, then apply:
//
//  1. StatefulWidget        → ConsumerStatefulWidget
//     State<X>              → ConsumerState<X>
//
//  2. Provider reads/watches (replace ALL occurrences):
//     context.read<AuthProvider>().user?.orgId   → ref.read(authProvider).user?.orgId
//     context.read<MenuProvider>()               → ref.read(menuProvider.notifier)
//     context.watch<MenuProvider>()              → ref.watch(menuProvider)
//     context.read<CartProvider>()               → ref.read(cartProvider.notifier)
//     context.watch<CartProvider>()              → ref.watch(cartProvider)
//     context.read<ShiftProvider>().shift        → ref.read(shiftProvider).shift
//     context.watch<OfflineSyncService>()        → ref.watch(offlineQueueProvider)
//     context.read<OfflineSyncService>()         → ref.read(offlineQueueProvider.notifier)
//     context.read<OrderHistoryProvider>()       → ref.read(orderHistoryProvider.notifier)
//     context.read<BranchProvider>()             → ref.read(authProvider).branch
//     context.watch<BranchProvider>()            → ref.watch(authProvider).branch
//
//  3. OfflineSyncService field names:
//     sync.isOnline   → isOnline (use ref.watch(isOnlineProvider) separately)
//     sync.count      → sync.count          (same)
//     sync.stuckCount → sync.stuckCount     (same)
//
//  4. Add these imports at the top:
//     import 'package:flutter_riverpod/flutter_riverpod.dart';
//     import '../../core/providers/auth_notifier.dart';
//     import '../../core/providers/cart_notifier.dart';
//     import '../../core/providers/menu_notifier.dart';
//     import '../../core/providers/order_history_notifier.dart';
//     import '../../core/providers/shift_notifier.dart';
//     import '../../core/services/connectivity_service.dart';
//     import '../../core/services/offline_queue.dart';
//
//  5. Remove these old imports:
//     import '../../core/providers/auth_provider.dart';
//     import '../../core/providers/branch_provider.dart';
//     import '../../core/providers/cart_provider.dart';
//     import '../../core/providers/menu_provider.dart';
//     import '../../core/providers/order_history_provider.dart';
//     import '../../core/providers/shift_provider.dart';
//     import '../../core/services/offline_sync_service.dart';
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home')),
      title: Text('New Order', style: cairo(fontWeight: FontWeight.w700)),
      backgroundColor: Colors.white, elevation: 0,
    ),
    body: const Center(child: Text(
        'Paste v1 order_screen.dart here and apply provider substitutions above')),
  );
}
DART

cat > lib/features/order/order_history_screen.dart << 'DART'
// ============================================================================
//  ORDER HISTORY SCREEN — same substitution guide as order_screen.dart above.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home')),
      title: Text('Order History', style: cairo(fontWeight: FontWeight.w700)),
      backgroundColor: Colors.white, elevation: 0,
    ),
    body: const Center(child: Text(
        'Paste v1 order_history_screen.dart here and apply provider substitutions above')),
  );
}
DART

echo ""
echo "✅  Part 2 complete — no sed, no head, macOS compatible."
echo ""
echo "Next steps:"
echo "  1.  flutter pub get"
echo "  2.  Apply order_screen.dart substitutions (see comments in the file)"
echo "  3.  Apply order_history_screen.dart substitutions (same guide)"
echo "  4.  flutter run"