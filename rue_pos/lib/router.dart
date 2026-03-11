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
