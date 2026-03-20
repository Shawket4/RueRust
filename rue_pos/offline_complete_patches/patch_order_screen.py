#!/usr/bin/env python3
"""
Patches lib/features/order/order_screen.dart:
  1. Adds imports for OfflineSyncService and PendingOrder
  2. Adds offline/sync banner to _TopBar
  3. Wires offline queue into CheckoutSheet._place()
"""
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

changed = []

# ── 1. Imports ─────────────────────────────────────────────────────────────────
for imp in [
    "import '../../core/services/offline_sync_service.dart';",
    "import '../../core/models/pending_order.dart';",
]:
    if imp not in src:
        src = src.replace(
            "import '../../shared/widgets/label_value.dart';",
            "import '../../shared/widgets/label_value.dart';\n" + imp,
        )
        changed.append('imports')

# ── 2. Offline banner in _TopBar.build() ───────────────────────────────────────
# Inject connectivity watch + banner wrapping BEFORE the Container return
OLD_TOPBAR = """  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),"""

NEW_TOPBAR = """  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final sync = context.watch<OfflineSyncService>();

    final Widget bar = Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),"""

if OLD_TOPBAR in src:
    src = src.replace(OLD_TOPBAR, NEW_TOPBAR)
    changed.append('topbar-start')

# Close the _TopBar build() by finding its closing brace just before _CategoryRail
# Replace the final "return Container(" result with the banner wrapper
OLD_TOPBAR_CLOSE = """      ]),
    );
  }
}

// ── Category Rail"""

NEW_TOPBAR_CLOSE = """      ]),
    );

    if (!sync.isOnline || sync.count > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar,
          if (!sync.isOnline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, size: 13,
                    color: Color(0xFF856404)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline \u2014 cached menu. Orders saved & synced when online.',
                    style: cairo(fontSize: 11, color: const Color(0xFF856404)),
                  ),
                ),
              ]),
            ),
          if (sync.isOnline && sync.count > 0)
            Container(
              width: double.infinity,
              color: const Color(0xFFCFE2FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Color(0xFF084298)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Syncing ${sync.count} offline order${sync.count == 1 ? "" : "s"}\u2026',
                  style: cairo(fontSize: 11, color: const Color(0xFF084298)),
                ),
              ]),
            ),
        ],
      );
    }
    return bar;
  }
}

// \u2500\u2500 Category Rail"""

if OLD_TOPBAR_CLOSE in src:
    src = src.replace(OLD_TOPBAR_CLOSE, NEW_TOPBAR_CLOSE)
    changed.append('topbar-banner')

# ── 3. Replace _place() ────────────────────────────────────────────────────────
OLD_PLACE = """  Future<void> _place() async {
    final cart  = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) { setState(() => _error = 'No open shift'); return; }
    final customer = _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim();
    setState(() { _loading = true; _error = null; });
    try {
      final order = await orderApi.create(
        branchId:      shift.branchId,
        shiftId:       shift.id,
        paymentMethod: cart.payment,
        items:         cart.items.toList(),
        customerName:  customer,
        discountType:  cart.discountTypeStr,
        discountValue: cart.discountValue,
      );
      context.read<OrderHistoryProvider>().addOrder(order);
      final total = cart.total;
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        // Show receipt sheet, which handles print
        ReceiptSheet.show(context, order: order, total: total);
      }
    } catch (e) {
      if (e is DioException)
        debugPrint('ORDER ${e.response?.statusCode}: ${e.response?.data}');
      setState(() { _error = 'Failed to place order \u2014 please retry'; _loading = false; });
    }
  }"""

NEW_PLACE = """  Future<void> _place() async {
    final cart  = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) { setState(() => _error = 'No open shift'); return; }
    final customer = _customerCtrl.text.trim().isEmpty
        ? null : _customerCtrl.text.trim();
    setState(() { _loading = true; _error = null; });
    try {
      final order = await orderApi.create(
        branchId:      shift.branchId,
        shiftId:       shift.id,
        paymentMethod: cart.payment,
        items:         cart.items.toList(),
        customerName:  customer,
        discountType:  cart.discountTypeStr,
        discountValue: cart.discountValue,
      );
      context.read<OrderHistoryProvider>().addOrder(order);
      final total = cart.total;
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context, order: order, total: total);
      }
    } on DioException catch (e) {
      // Network error \u2014 save to offline queue
      final isOffline = e.response == null ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      if (isOffline) {
        final localId =
            '\${DateTime.now().millisecondsSinceEpoch}_\${shift.id.substring(0, 8)}';
        await offlineSyncService.savePending(PendingOrder(
          localId:       localId,
          branchId:      shift.branchId,
          shiftId:       shift.id,
          paymentMethod: cart.payment,
          items:         cart.items.toList(),
          customerName:  customer,
          discountType:  cart.discountTypeStr,
          discountValue: cart.discountValue,
          createdAt:     DateTime.now(),
        ));
        cart.clear();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No connection \u2014 order saved. Will sync automatically when online.'),
            backgroundColor: Color(0xFF856404),
            duration: Duration(seconds: 4),
          ));
        }
      } else {
        debugPrint('ORDER \${e.response?.statusCode}: \${e.response?.data}');
        setState(() {
          _error   = 'Server error \u2014 please retry';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Failed to place order \u2014 please retry'; _loading = false; });
    }
  }"""

if OLD_PLACE in src:
    src = src.replace(OLD_PLACE, NEW_PLACE)
    changed.append('place-method')
else:
    print("  WARN: _place() exact text not matched")
    print("        Manual wiring needed — see patch_order_screen.py")

with open(path, 'w') as f:
    f.write(src)

print(f"  patched: {', '.join(changed) if changed else 'nothing matched'}")
print(f"  saved: {path}")

