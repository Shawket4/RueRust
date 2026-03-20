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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = context.read<AuthProvider>().user?.branchId;
    if (branchId == null) {
      setState(() {
        _loading = false;
        _error = 'No branch assigned';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shifts = await shiftApi.list(branchId);
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
            style: cairo(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorBanner(message: _error!, onRetry: _load),
                )
              : _shifts.isEmpty
                  ? Center(
                      child: Text('No shifts found',
                          style: cairo(
                              fontSize: 15, color: AppColors.textSecondary)))
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
    if (_orders.isNotEmpty) {
      setState(() => _expanded = !_expanded);
      return;
    }
    setState(() {
      _loadingOrders = true;
      _expanded = true;
    });
    try {
      final orders = await orderApi.list(shiftId: widget.shift.id);
      if (mounted) {
        setState(() {
          _orders = orders;
          _loadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = e.toString();
          _loadingOrders = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final isOpen = s.status == 'open';

    final statusColor = isOpen
        ? AppColors.success
        : s.status == 'force_closed'
            ? AppColors.danger
            : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
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
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tellerName,
                        style: cairo(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateTime(s.openedAt),
                        style:
                            cairo(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.status.replaceAll('_', ' ').toUpperCase(),
                    style: cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
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
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.textMuted,
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
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            )
          else if (_ordersError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_ordersError!,
                  style: cairo(fontSize: 12, color: AppColors.danger)),
            )
          else if (_orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No orders in this shift',
                  style: cairo(fontSize: 13, color: AppColors.textMuted)),
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
        ip: bp.printerIp!,
        port: bp.printerPort,
        order: full,
        branchName: bp.branchName,
        brand: bp.printerBrand!,
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
    final o = widget.order;
    final isVoided = o.status == 'voided';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isVoided
                ? AppColors.borderLight
                : AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text('#${o.orderNumber}',
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isVoided ? AppColors.textMuted : AppColors.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(timeShort(o.createdAt),
                style: cairo(fontSize: 12, color: AppColors.textSecondary)),
            if (o.customerName != null)
              Text(o.customerName!,
                  style: cairo(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        Text(
          egp(o.totalAmount),
          style: cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isVoided ? AppColors.textMuted : AppColors.textPrimary,
            decoration: isVoided ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(width: 8),
        if (!isVoided)
          _printing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : GestureDetector(
                  onTap: _print,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.print_rounded,
                        size: 15, color: AppColors.primary),
                  ),
                ),
      ]),
    );
  }
}
