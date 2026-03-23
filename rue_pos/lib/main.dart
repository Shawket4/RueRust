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
  print("object");
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
    print("object");
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OfflineSyncService>.value(
            value: offlineSyncService),
        ChangeNotifierProvider<BranchProvider>.value(value: branchProvider),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) {
            final auth = AuthProvider(branchProvider);
            auth.init().then((_) {
              debugPrint('Auth init done');
              debugPrint('User: ${auth.user?.name}');
              debugPrint('BranchId: ${auth.user?.branchId}');
              debugPrint('Branch: ${branchProvider.branch?.name}');
              debugPrint('PrinterBrand: ${branchProvider.printerBrand}');
              debugPrint('HasPrinter: ${branchProvider.hasPrinter}');
            });
            return auth;
          },
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
