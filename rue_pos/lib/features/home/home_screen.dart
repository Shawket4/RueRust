import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  int _orderCount = 0;
  int _salesTotal = 0;
  int _systemCash = 0;
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
          _orderCount = orders.where((o) => o.status != 'voided').length;
          _salesTotal = orders
              .where((o) => o.status != 'voided')
              .fold(0, (s, o) => s + o.totalAmount);
          _systemCash = system;
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final shift = context.watch<ShiftProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo top-left
                  Image.asset('assets/TheRue.png', height: 48),
                  const Spacer(),
                  // Teller name + sign out
                  Text(
                    user.name,
                    style: cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SignOutBtn(),
                ],
              ),
              const SizedBox(height: 28),

              // ── Greeting ─────────────────────────────────────
              Text(
                _greet(user.name.split(' ').first),
                style: cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.role.replaceAll('_', ' ').toUpperCase(),
                style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 28),

              // ── Main content ──────────────────────────────────
              if (shift.loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (shift.error != null)
                _ErrorBanner(message: shift.error!, onRetry: _load)
              else if (shift.hasOpen)
                _OpenShiftView(
                  shift: shift.shift!,
                  orderCount: _orderCount,
                  salesTotal: _salesTotal,
                  systemCash: _systemCash,
                  statsLoaded: _statsLoaded,
                  onRefresh: _loadStats,
                )
              else
                _NoShiftView(
                  suggested: shift.preFill?.suggestedOpeningCash ?? 0,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _greet(String first) {
    final h = DateTime.now().hour;
    final word = h < 12
        ? 'Morning'
        : h < 17
            ? 'Afternoon'
            : 'Evening';
    return 'Good $word, $first';
  }
}

// ─────────────────────────────────────────────────────────────
//  OPEN SHIFT VIEW
// ─────────────────────────────────────────────────────────────
class _OpenShiftView extends StatelessWidget {
  final dynamic shift;
  final int orderCount;
  final int salesTotal;
  final int systemCash;
  final bool statsLoaded;
  final VoidCallback onRefresh;

  const _OpenShiftView({
    required this.shift,
    required this.orderCount,
    required this.salesTotal,
    required this.systemCash,
    required this.statsLoaded,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero shift card ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status + time
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('SHIFT OPEN',
                          style: cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          )),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Since ${timeShort(shift.openedAt)}',
                  style: cairo(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRefresh,
                  child: const Icon(Icons.refresh_rounded,
                      size: 15, color: Colors.white54),
                ),
              ]),
              const SizedBox(height: 20),

              // Stats row
              Row(children: [
                _ShiftStat(
                  label: 'Sales',
                  value: statsLoaded ? egp(salesTotal) : '—',
                  loading: !statsLoaded,
                ),
                _VertDivider(),
                _ShiftStat(
                  label: 'Orders',
                  value: statsLoaded ? '$orderCount' : '—',
                  loading: !statsLoaded,
                ),
                _VertDivider(),
                _ShiftStat(
                  label: 'System Cash',
                  value: statsLoaded ? egp(systemCash) : '—',
                  loading: !statsLoaded,
                  sublabel: egp(shift.openingCash) + ' open',
                ),
              ]),
              const SizedBox(height: 22),

              // Action buttons
              Row(children: [
                Expanded(
                    child: _CardBtn(
                  label: 'New Order',
                  icon: Icons.add_shopping_cart_rounded,
                  onTap: () => context.go('/order'),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _CardBtn(
                  label: 'History',
                  icon: Icons.receipt_long_rounded,
                  onTap: () => context.go('/order-history'),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _CardBtn(
                  label: 'Close',
                  icon: Icons.lock_outline_rounded,
                  onTap: () => _confirmClose(context),
                  danger: true,
                )),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmClose(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Close Shift?',
            style: cairo(fontWeight: FontWeight.w700)),
        content: Text(
          'You\'ll count cash and inventory on the next screen.',
          style:
              cairo(fontSize: 14, color: AppColors.textSecondary),
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
            child: Text('Continue',
                style: cairo(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ShiftStat extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;
  final String? sublabel;

  const _ShiftStat({
    required this.label,
    required this.value,
    this.loading = false,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: cairo(
                  fontSize: 11,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 4),
            loading
                ? Container(
                    width: 50,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(value,
                    style: cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    )),
            if (sublabel != null) ...[
              const SizedBox(height: 2),
              Text(sublabel!,
                  style: cairo(
                    fontSize: 10,
                    color: Colors.white38,
                  )),
            ],
          ],
        ),
      );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 44,
        color: Colors.white.withOpacity(0.15),
        margin: const EdgeInsets.symmetric(horizontal: 16),
      );
}

class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: danger ? Colors.white.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15, color: danger ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: danger ? Colors.white : AppColors.primary,
                  )),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  NO SHIFT VIEW
// ─────────────────────────────────────────────────────────────
class _NoShiftView extends StatelessWidget {
  final int suggested;
  const _NoShiftView({required this.suggested});

  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No Open Shift',
                      style: cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                  if (suggested > 0)
                    Text(
                      'Last closing: ${egp(suggested)}',
                      style: cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            AppButton(
              label: 'Open Shift',
              width: double.infinity,
              icon: Icons.play_arrow_rounded,
              onTap: () => context.go('/open-shift'),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────
class _SignOutBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await context.read<AuthProvider>().logout();
          if (context.mounted) context.go('/login');
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.logout_rounded,
              size: 15, color: AppColors.textSecondary),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: cairo(
                      fontSize: 13, color: AppColors.danger))),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry',
                style: cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ]),
      );
}
