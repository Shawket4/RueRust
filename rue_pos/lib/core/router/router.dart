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
