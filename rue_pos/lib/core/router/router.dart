import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/order/order_history_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/order/pending_orders_screen.dart';
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
      final auth = ref.read(authProvider);
      final authed = auth.isAuthenticated;
      final loading = auth.isLoading;
      final onLogin = state.matchedLocation == '/login';

      // Never redirect while auth is in progress —
      // prevents mid-login redirects back to /login
      if (loading) return null;

      if (!authed && !onLogin) return '/login';
      if (authed && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/open-shift', builder: (_, __) => const OpenShiftScreen()),
      GoRoute(
          path: '/close-shift', builder: (_, __) => const CloseShiftScreen()),
      GoRoute(
          path: '/shift-history',
          builder: (_, __) => const ShiftHistoryScreen()),
      GoRoute(path: '/order', builder: (_, __) => const OrderScreen()),
      GoRoute(
          path: '/order-history',
          builder: (_, __) => const OrderHistoryScreen()),
      GoRoute(
          path: '/pending-orders',
          builder: (_, __) => const PendingOrdersScreen()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (prev, next) {
      // Only notify router when loading finishes or auth state changes —
      // not on every state update (e.g. error messages, blocked name)
      final loadingChanged = prev?.isLoading != next.isLoading;
      final authChanged = prev?.isAuthenticated != next.isAuthenticated;
      if (loadingChanged || authChanged) notifyListeners();
    });
  }
  final Ref _ref;
}
