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
                const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
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
                  isTablet: isTablet,
                )
              else
                _NoShiftView(
                  suggested: shift.preFill?.suggestedOpeningCash ?? 0,
                  isTablet: isTablet,
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

// ── Open Shift View ───────────────────────────────────────────────────────────
class _OpenShiftView extends StatelessWidget {
  final dynamic shift;
  final int orderCount;
  final int salesTotal;
  final int systemCash;
  final bool statsLoaded;
  final VoidCallback onRefresh;
  final bool isTablet;

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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
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
                        letterSpacing: 0.8)),
              ]),
            ),
            const Spacer(),
            Text('Since ${timeShort(shift.openedAt)}',
                style: cairo(fontSize: 11, color: Colors.white60)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.white54),
            ),
          ]),
          SizedBox(height: isTablet ? 26 : 20),

          // Stats
          Row(children: [
            _ShiftStat(
                label: 'Sales',
                value: egp(salesTotal),
                loading: !statsLoaded,
                isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(
                label: 'Orders',
                value: '$orderCount',
                loading: !statsLoaded,
                isTablet: isTablet),
            _VertDivider(),
            _ShiftStat(
              label: 'System Cash',
              value: egp(systemCash),
              sublabel: '${egp(shift.openingCash)} opening',
              loading: !statsLoaded,
              isTablet: isTablet,
            ),
          ]),
          SizedBox(height: isTablet ? 28 : 22),

          // Action buttons — 4 buttons now
          Row(children: [
            Expanded(
                child: _CardBtn(
              label: 'New Order',
              icon: Icons.add_shopping_cart_rounded,
              onTap: () => context.go('/order'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
              label: 'History',
              icon: Icons.receipt_long_rounded,
              onTap: () => context.go('/order-history'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
              label: 'Shifts',
              icon: Icons.history_rounded,
              onTap: () => context.go('/shift-history'),
              isTablet: isTablet,
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _CardBtn(
              label: 'Close',
              icon: Icons.lock_outline_rounded,
              onTap: () => _confirmClose(context),
              danger: true,
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
        title: Text('Close Shift?', style: cairo(fontWeight: FontWeight.w800)),
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
  final String? sublabel;
  final bool loading;
  final bool isTablet;

  const _ShiftStat({
    required this.label,
    required this.value,
    this.sublabel,
    this.loading = false,
    this.isTablet = false,
  });

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
  final bool danger;
  final bool isTablet;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 11),
          decoration: BoxDecoration(
            color: danger ? Colors.white.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: isTablet ? 18 : 16,
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.wb_sunny_outlined,
                            color: AppColors.primary, size: 22),
                      ),
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
                      onTap: () => context.go('/open-shift'),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          // Shift history always accessible even without an open shift
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

// ── Shared small widgets ──────────────────────────────────────────────────────
class _SignOutBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await context.read<AuthProvider>().logout();
          if (context.mounted) context.go('/login');
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
        ),
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
                    color: AppColors.primary)),
          ),
        ]),
      );
}
