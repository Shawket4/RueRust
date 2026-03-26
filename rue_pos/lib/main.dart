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
      final queue = ref.read(offlineQueueProvider.notifier);
      final history = ref.read(orderHistoryProvider.notifier);
      queue.onOrderSynced = history.addOrder;
      queue.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
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
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary)),
            ]),
          ),
        ),
      );
}
