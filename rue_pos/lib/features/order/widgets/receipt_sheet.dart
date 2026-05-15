import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../core/models/order.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/label_value.dart';
import '../../../shared/widgets/responsive_sheet.dart';
import '../helpers/payment_helpers.dart';

class ReceiptSheet extends ConsumerStatefulWidget {
  final Order order;
  final int total;
  final int? changeGiven;
  const ReceiptSheet(
      {super.key, required this.order, required this.total, this.changeGiven});

  // Task 3.2: ResponsiveSheet
  static Future<void> show(BuildContext ctx,
          {required Order order, required int total, int? changeGiven}) =>
      ResponsiveSheet.show(
          context: ctx,
          builder: (_) => ReceiptSheet(
              order: order, total: total, changeGiven: changeGiven));

  @override
  ConsumerState<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<ReceiptSheet> {
  bool _printing = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _print();
    });
  }

  Future<void> _print() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) return;
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.print(
        ip: branch.printerIp!,
        port: branch.printerPort,
        brand: branch.printerBrand!,
        order: widget.order,
        branchName: branch.name,
        kickDrawer: widget.order.paymentMethod == 'cash' || widget.order.paymentMethod == 'talabat_cash');
    if (mounted) {
      setState(() {
        _printing = false;
        _printError = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          SizedBox(
              width: 110,
              height: 110,
              child: Lottie.asset('assets/lottie/success.json',
                  repeat: false, fit: BoxFit.contain)),
          const SizedBox(height: 10),
          Text('Order Placed!',
              style: cairo(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Order #${o.orderNumber}',
              style: cairo(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border)),
            child: Column(children: [
              LabelValue('Payment', methodLabel(o.paymentMethod)),
              if (o.tipAmount != null && o.tipAmount! > 0)
                LabelValue('Tip',
                    '${egp(o.tipAmount!)}${o.tipPaymentMethod != null ? " · ${methodLabel(o.tipPaymentMethod!)}" : ""}',
                    valueColor: AppColors.success),
              if (o.customerName != null && o.customerName!.isNotEmpty)
                LabelValue('Customer', o.customerName!),
              LabelValue('Total', egp(o.totalAmount), bold: true),
              LabelValue('Time', timeShort(o.createdAt)),
              if (widget.changeGiven != null && widget.changeGiven! > 0)
                LabelValue('Change Given', egp(widget.changeGiven!),
                    valueColor: AppColors.success),
            ]),
          ),
          const SizedBox(height: 16),
          _printing
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Text('Printing…',
                      style: cairo(fontSize: 13, color: AppColors.textSecondary)),
                ])
              : GestureDetector(
                  onTap: _print,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: (_printError != null
                                ? AppColors.danger
                                : AppColors.primary)
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppRadius.xs)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.print_rounded,
                          size: 15,
                          color: _printError != null
                              ? AppColors.danger
                              : AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                          _printError != null ? 'Retry Print' : 'Reprint Receipt',
                          style: cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _printError != null
                                  ? AppColors.danger
                                  : AppColors.primary)),
                    ]),
                  ),
                ),
          const SizedBox(height: 16),
          AppButton(
              label: 'New Order',
              width: double.infinity,
              height: 52,
              icon: Icons.add_rounded,
              onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}
