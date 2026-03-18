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

