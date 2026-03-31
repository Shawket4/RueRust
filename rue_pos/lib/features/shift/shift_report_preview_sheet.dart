import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/shift_report.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Public entry point
// ─────────────────────────────────────────────────────────────────────────────

class ShiftReportPreviewSheet extends ConsumerStatefulWidget {
  final ShiftReport report;

  const ShiftReportPreviewSheet({super.key, required this.report});

  /// Show the sheet.  Returns after the user closes it.
  static Future<void> show(BuildContext context, ShiftReport report) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ShiftReportPreviewSheet(report: report),
      );

  @override
  ConsumerState<ShiftReportPreviewSheet> createState() =>
      _ShiftReportPreviewSheetState();
}

class _ShiftReportPreviewSheetState
    extends ConsumerState<ShiftReportPreviewSheet> {
  bool _printing = false;
  String? _printError;

  ShiftReport get report => widget.report;

  // ── Print ────────────────────────────────────────────────────────────────
  Future<void> _print() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) {
      _showSnack('No printer configured for this branch',
          color: AppColors.warning);
      return;
    }
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.printShiftReport(
      ip: branch.printerIp!,
      port: branch.printerPort,
      brand: branch.printerBrand!,
      report: report,
      branchName: branch.name,
    );
    if (mounted) {
      setState(() {
        _printing = false;
        _printError = err;
      });
      if (err == null) {
        _showSnack('Report printed', color: AppColors.success);
      }
    }
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmtDt(DateTime dt) {
    final l = dt.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    final mo = l.month.toString().padLeft(2, '0');
    final h = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$d/$mo/${l.year}  $h:$mi';
  }

  String _methodLabel(String m) => switch (m) {
        'cash' => 'Cash',
        'card' => 'Card',
        'digital_wallet' => 'Digital Wallet',
        'mixed' => 'Mixed',
        'talabat_online' => 'Talabat Online',
        'talabat_cash' => 'Talabat Cash',
        _ => m[0].toUpperCase() + m.substring(1).replaceAll('_', ' '),
      };

  Color _methodColor(String m) => switch (m) {
        'cash' => const Color(0xFF059669),
        'card' => const Color(0xFF7C3AED),
        'digital_wallet' => const Color(0xFF0EA5E9),
        'mixed' => AppColors.primary,
        'talabat_online' => const Color(0xFFFF6B00),
        'talabat_cash' => const Color(0xFFFF6B00),
        _ => AppColors.primary,
      };

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final r = report;
    final isOpen = r.isOpen;
    final openTs = _fmtDt(r.openedAt);
    final closeTs = r.closedAt != null ? _fmtDt(r.closedAt!) : null;

    // Cash discrepancy: system − declared (positive = short)
    final int? discrepancy =
        (r.closingCashDeclared != null && r.closingCashSystem != null)
            ? r.closingCashSystem! - r.closingCashDeclared!
            : null;

    final branch = ref.watch(authProvider).branch;
    final hasPrinter = branch?.hasPrinter ?? false;

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.sheetRadius,
      ),
      child: Column(children: [
        // ── Handle + header ────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.sheetRadius,
            border: const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
          child: Column(children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shift Report',
                          style:
                              cairo(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(r.tellerName,
                          style: cairo(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ]),
              ),
              // Status pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOpen
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  isOpen ? 'Open Shift' : 'Closed',
                  style: cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ]),
          ]),
        ),

        // ── Scrollable body ────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Shift info card ──────────────────────────────────────────
              _Card(
                  child: Column(children: [
                _SectionTitle('SHIFT DETAILS'),
                const SizedBox(height: 8),
                _Row('Opened', openTs),
                if (closeTs != null) _Row('Closed', closeTs),
                _Row('Opening Cash', egp(r.openingCash)),
                if (r.closingCashSystem != null)
                  _Row('Expected Cash', egp(r.closingCashSystem!)),
                if (r.closingCashDeclared != null)
                  _Row('Declared Cash', egp(r.closingCashDeclared!),
                      bold: true),
                if (discrepancy != null && discrepancy != 0) ...[
                  const Divider(color: AppColors.borderLight, height: 16),
                  _DiscrepancyRow(discrepancy),
                ],
              ])),
              const SizedBox(height: 12),

              // ── Payments card ────────────────────────────────────────────
              _Card(
                  child: Column(children: [
                _SectionTitle('PAYMENT BREAKDOWN'),
                const SizedBox(height: 8),
                if (r.paymentSummary.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('No payments recorded',
                          style:
                              cairo(fontSize: 13, color: AppColors.textMuted)),
                    ),
                  )
                else ...[
                  ...r.paymentSummary.map((p) {
                    final pct =
                        r.totalPayments > 0 ? p.total / r.totalPayments : 0.0;
                    final color = _methodColor(p.paymentMethod);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_methodLabel(p.paymentMethod),
                                      style: cairo(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      '${p.orderCount} order${p.orderCount == 1 ? "" : "s"}',
                                      style: cairo(
                                          fontSize: 11,
                                          color: AppColors.textMuted)),
                                ]),
                          ),
                          Text(egp(p.total),
                              style: cairo(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.toDouble(),
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ]),
                    );
                  }),
                  const Divider(color: AppColors.borderLight, height: 20),
                  _Row('Total Payments', egp(r.totalPayments),
                      bold: true, large: true),
                  if (r.totalReturns > 0)
                    _Row('Voided Orders', '− ${egp(r.totalReturns)}',
                        valueColor: AppColors.danger),
                  if (r.totalReturns > 0)
                    _Row('Net Payments', egp(r.netPayments),
                        bold: true, large: true, valueColor: AppColors.success),
                ],
              ])),
              const SizedBox(height: 12),

              // ── Cash movements card ──────────────────────────────────────
              _Card(
                  child: Column(children: [
                _SectionTitle('CASH MOVEMENTS'),
                const SizedBox(height: 8),
                if (r.cashMovements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text('No cash movements',
                          style:
                              cairo(fontSize: 13, color: AppColors.textMuted)),
                    ),
                  )
                else ...[
                  ...r.cashMovements.map((m) {
                    final isIn = m.isIn;
                    final color = isIn ? AppColors.success : AppColors.danger;
                    final sign = isIn ? '+' : '−';
                    final ts = _fmtDt(m.createdAt);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isIn ? Icons.add_rounded : Icons.remove_rounded,
                            size: 16,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.note,
                                    style: cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                Text('${m.movedByName} · $ts',
                                    style: cairo(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ]),
                        ),
                        Text(
                          '$sign ${egp(m.amount.abs())}',
                          style: cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ]),
                    );
                  }),
                  const Divider(color: AppColors.borderLight, height: 20),
                  _Row('Pay In', egp(r.cashMovementsIn),
                      valueColor: AppColors.success),
                  _Row('Pay Out', egp(r.cashMovementsOut),
                      valueColor: AppColors.danger),
                ],
              ])),
              const SizedBox(height: 12),

              // ── Printed at ───────────────────────────────────────────────
              Center(
                child: Text(
                  'Report generated ${_fmtDt(r.printedAt)}',
                  style: cairo(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),

        // ── Print button ───────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 12),
          child: _printing
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_printError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(
                                color: AppColors.danger.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 14, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_printError!,
                                  style: cairo(
                                      fontSize: 12, color: AppColors.danger)),
                            ),
                          ]),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: hasPrinter ? _print : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hasPrinter ? AppColors.primary : AppColors.border,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _printError != null
                                    ? Icons.refresh_rounded
                                    : Icons.print_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasPrinter
                                    ? (_printError != null
                                        ? 'Retry Print'
                                        : 'Print Report')
                                    : 'No Printer Configured',
                                style: cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ]),
                      ),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small layout helpers (private to this file)
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: cairo(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  final Color? valueColor;

  const _Row(this.label, this.value,
      {this.bold = false, this.large = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: cairo(
                    fontSize: large ? 14 : 13, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: cairo(
                  fontSize: large ? 15 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ]),
      );
}

class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy; // system − declared: positive = short

  const _DiscrepancyRow(this.discrepancy);

  @override
  Widget build(BuildContext context) {
    final isExact = discrepancy == 0;
    final isShort = discrepancy > 0;
    final color = isExact
        ? AppColors.success
        : isShort
            ? AppColors.danger
            : AppColors.warning;
    final icon = isExact
        ? Icons.check_circle_outline_rounded
        : isShort
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
    final label = isExact
        ? 'Exact match'
        : isShort
            ? 'Short by ${egp(discrepancy.abs())}'
            : 'Over by ${egp(discrepancy.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(label,
            style:
                cairo(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
