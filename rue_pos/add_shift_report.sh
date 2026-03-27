#!/usr/bin/env bash
# =============================================================================
#  Shift Report — Full Frontend Patch
#  Includes: ShiftReport model, ShiftApi.getReport(), PrinterService,
#            close_shift_screen.dart, shift_history_screen.dart
#  Run from your Flutter project root.
#  Usage: bash shift_report_full.sh
# =============================================================================
set -euo pipefail
echo "🖨️  Applying shift report full frontend patch..."

mkdir -p lib/core/{models,api,services}
mkdir -p lib/features/shift

# =============================================================================
# 1. ShiftReport model  (includes CashMovementItem)
# =============================================================================
cat > lib/core/models/shift_report.dart << 'DART'
class PaymentSummaryItem {
  final String paymentMethod;
  final int    total;
  final int    orderCount;

  const PaymentSummaryItem({
    required this.paymentMethod,
    required this.total,
    required this.orderCount,
  });

  factory PaymentSummaryItem.fromJson(Map<String, dynamic> j) =>
      PaymentSummaryItem(
        paymentMethod: j['payment_method'] as String,
        total:         (j['total'] as num).toInt(),
        orderCount:    (j['order_count'] as num).toInt(),
      );

  String get displayLabel => switch (paymentMethod) {
    'cash'           => 'Cash',
    'card'           => 'Card',
    'digital_wallet' => 'Digital Wallet',
    'mixed'          => 'Mixed',
    'talabat_online' => 'Talabat Online',
    'talabat_cash'   => 'Talabat Cash',
    _                => paymentMethod[0].toUpperCase() +
                        paymentMethod.substring(1).replaceAll('_', ' '),
  };
}

class CashMovementItem {
  final int      amount;
  final String   note;
  final String   movedByName;
  final DateTime createdAt;

  const CashMovementItem({
    required this.amount,
    required this.note,
    required this.movedByName,
    required this.createdAt,
  });

  bool get isIn => amount > 0;

  factory CashMovementItem.fromJson(Map<String, dynamic> j) =>
      CashMovementItem(
        amount:      (j['amount'] as num).toInt(),
        note:        j['note'] as String,
        movedByName: j['moved_by_name'] as String,
        createdAt:   DateTime.parse(j['created_at'] as String),
      );
}

class ShiftReport {
  final String    shiftId;
  final String    branchId;
  final String    tellerName;
  final String    status;
  final int       openingCash;
  final int?      closingCashDeclared;
  final int?      closingCashSystem;
  final DateTime  openedAt;
  final DateTime? closedAt;

  final List<PaymentSummaryItem> paymentSummary;
  final List<CashMovementItem>   cashMovements;
  final int      totalPayments;
  final int      totalReturns;
  final int      netPayments;
  final int      cashMovementsIn;
  final int      cashMovementsOut;
  final DateTime printedAt;

  const ShiftReport({
    required this.shiftId,
    required this.branchId,
    required this.tellerName,
    required this.status,
    required this.openingCash,
    this.closingCashDeclared,
    this.closingCashSystem,
    required this.openedAt,
    this.closedAt,
    required this.paymentSummary,
    required this.cashMovements,
    required this.totalPayments,
    required this.totalReturns,
    required this.netPayments,
    required this.cashMovementsIn,
    required this.cashMovementsOut,
    required this.printedAt,
  });

  /// closed_at if shift is closed, printed_at (now) if still open
  DateTime get reportTimestamp => closedAt ?? printedAt;
  bool get isOpen => status == 'open';

  factory ShiftReport.fromJson(Map<String, dynamic> j) {
    final shift = j['shift'] as Map<String, dynamic>;
    return ShiftReport(
      shiftId:             shift['id'] as String,
      branchId:            shift['branch_id'] as String,
      tellerName:          shift['teller_name'] as String,
      status:              shift['status'] as String,
      openingCash:         (shift['opening_cash'] as num).toInt(),
      closingCashDeclared: shift['closing_cash_declared'] != null
          ? (shift['closing_cash_declared'] as num).toInt() : null,
      closingCashSystem:   shift['closing_cash_system'] != null
          ? (shift['closing_cash_system'] as num).toInt() : null,
      openedAt:  DateTime.parse(shift['opened_at'] as String),
      closedAt:  shift['closed_at'] != null
          ? DateTime.parse(shift['closed_at'] as String) : null,
      paymentSummary: (j['payment_summary'] as List)
          .map((e) => PaymentSummaryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      cashMovements: (j['cash_movements'] as List)
          .map((e) => CashMovementItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPayments:    (j['total_payments']     as num).toInt(),
      totalReturns:     (j['total_returns']      as num).toInt(),
      netPayments:      (j['net_payments']       as num).toInt(),
      cashMovementsIn:  (j['cash_movements_in']  as num).toInt(),
      cashMovementsOut: (j['cash_movements_out'] as num).toInt(),
      printedAt: DateTime.parse(j['printed_at'] as String),
    );
  }
}
DART
echo "  ✅  lib/core/models/shift_report.dart"

# =============================================================================
# 2. ShiftApi — add getReport() (idempotent)
# =============================================================================
python3 - << 'PY'
import pathlib

path = pathlib.Path('lib/core/api/shift_api.dart')
if not path.exists():
    print('  ⚠️   lib/core/api/shift_api.dart not found — skipping getReport()')
    exit()

content = path.read_text()

if 'getReport' in content:
    print('  ✅  lib/core/api/shift_api.dart — getReport() already present')
    exit()

# Add import
if "shift_report.dart" not in content:
    content = content.replace(
        "import '../models/shift.dart';",
        "import '../models/shift.dart';\nimport '../models/shift_report.dart';"
    )

method = """
  Future<ShiftReport> getReport(String shiftId) async {
    final res = await _c.dio.get('/shifts/$shiftId/report');
    return ShiftReport.fromJson(res.data as Map<String, dynamic>);
  }
"""

last_brace = content.rfind('}')
content = content[:last_brace] + method + content[last_brace:]
path.write_text(content)
print('  ✅  lib/core/api/shift_api.dart — added getReport()')
PY

# =============================================================================
# 3. printer_service.dart — full rewrite with printShiftReport + cash movements
# =============================================================================
cat > lib/core/services/printer_service.dart << 'DART'
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
import '../models/branch.dart';
import '../models/order.dart';
import '../models/shift_report.dart';
import '../utils/formatting.dart';

class PrinterService {
  static const _printerWidth = 576;
  static const _timeout      = Duration(seconds: 5);

  // ── Order receipt ──────────────────────────────────────────────────────────

  static Future<String?> print({
    required String       ip,
    required int          port,
    required PrinterBrand brand,
    required Order        order,
    required String       branchName,
  }) async {
    final cleanIp  = ip.split('/').first;
    final pdfBytes = await _buildReceiptPdf(order: order, branchName: branchName);
    return switch (brand) {
      PrinterBrand.star  => _printStar(ip: cleanIp, pdfBytes: pdfBytes),
      PrinterBrand.epson => _printEpson(ip: cleanIp, port: port, pdfBytes: pdfBytes),
    };
  }

  // ── Shift report ───────────────────────────────────────────────────────────

  static Future<String?> printShiftReport({
    required String       ip,
    required int          port,
    required PrinterBrand brand,
    required ShiftReport  report,
    required String       branchName,
  }) async {
    final cleanIp  = ip.split('/').first;
    final pdfBytes = await _buildShiftReportPdf(report: report, branchName: branchName);
    return switch (brand) {
      PrinterBrand.star  => _printStar(ip: cleanIp, pdfBytes: pdfBytes),
      PrinterBrand.epson => _printEpson(ip: cleanIp, port: port, pdfBytes: pdfBytes),
    };
  }

  // ── Transport ──────────────────────────────────────────────────────────────

  static Future<String?> _printStar({
    required String    ip,
    required Uint8List pdfBytes,
  }) async {
    try {
      final device    = StarDevice(ip, StarInterfaceType.lan);
      final connected = await StarXpand.instance.connect(device, monitor: false);
      if (!connected) return 'Could not connect to Star printer';
      final ok = await StarXpand.instance.printPdf(pdfBytes, width: _printerWidth);
      return ok ? null : 'Star print failed';
    } catch (e) {
      return 'Star printer error: $e';
    } finally {
      await StarXpand.instance.disconnect();
    }
  }

  static Future<String?> _printEpson({
    required String    ip,
    required int       port,
    required Uint8List pdfBytes,
  }) async {
    Socket? socket;
    try {
      final page     = await Printing.raster(pdfBytes, dpi: 203).first;
      final png      = await page.toPng();
      final imgBytes = await _pngToEscPos(png, page.width, page.height);
      socket = await Socket.connect(ip, port, timeout: _timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.add(imgBytes);
      await socket.flush().timeout(_timeout);
      return null;
    } on TimeoutException {
      return 'Epson printer timeout';
    } on SocketException catch (e) {
      return 'Epson printer error: ${e.message}';
    } catch (e) {
      return 'Epson printer error: $e';
    } finally {
      await socket?.close();
    }
  }

  // ── ESC/POS rasteriser ─────────────────────────────────────────────────────

  static Future<Uint8List> _pngToEscPos(Uint8List png, int w, int h) async {
    final codec   = await ui.instantiateImageCodec(png);
    final frame   = await codec.getNextFrame();
    final imgData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (imgData == null) throw Exception('Failed to decode image');
    final pixels = imgData.buffer.asUint8List();
    final buf    = <int>[];
    buf.addAll([0x1B, 0x40]);
    final wB = (w + 7) ~/ 8;
    buf.addAll([
      0x1D, 0x76, 0x30, 0x00,
      wB & 0xFF, (wB >> 8) & 0xFF,
      h  & 0xFF, (h  >> 8) & 0xFF,
    ]);
    for (int y = 0; y < h; y++) {
      for (int xB = 0; xB < wB; xB++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = xB * 8 + bit;
          if (x < w) {
            final idx = (y * w + x) * 4;
            final r  = pixels[idx];
            final g  = pixels[idx + 1];
            final b  = pixels[idx + 2];
            final a  = pixels[idx + 3];
            final rW = ((r * a) + (255 * (255 - a))) ~/ 255;
            final gW = ((g * a) + (255 * (255 - a))) ~/ 255;
            final bW = ((b * a) + (255 * (255 - a))) ~/ 255;
            if ((0.299 * rW + 0.587 * gW + 0.114 * bW).round() < 128) {
              byte |= (0x80 >> bit);
            }
          }
        }
        buf.add(byte);
      }
    }
    buf.addAll([0x1B, 0x64, 0x05, 0x1D, 0x56, 0x41, 0x05]);
    return Uint8List.fromList(buf);
  }

  // ── Order receipt PDF ──────────────────────────────────────────────────────

  static Future<Uint8List> _buildReceiptPdf({
    required Order  order,
    required String branchName,
  }) async {
    final pdf   = pw.Document();
    final font  = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/Cairo-Regular.ttf')).buffer.asByteData());
    final fontB = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/Cairo-SemiBold.ttf')).buffer.asByteData());
    final logo  = pw.MemoryImage(
        (await rootBundle.load('assets/TheRue.png')).buffer.asUint8List());

    const cw = 40;
    pw.TextStyle ts(pw.Font f, {double sz = 8}) => pw.TextStyle(font: f, fontSize: sz);
    pw.Widget div() => pw.Divider(thickness: 0.3, color: PdfColors.grey600, height: 4);
    String pad(String l, String r) {
      final sp = cw - l.length - r.length;
      return sp <= 0 ? '$l $r' : l + ' ' * sp + r;
    }

    final dt  = order.createdAt.toLocal();
    final dts = '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year}  ${timeShort(order.createdAt)}';

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm, double.infinity,
          marginTop: 2 * PdfPageFormat.mm, marginBottom: 2 * PdfPageFormat.mm,
          marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Image(logo, width: 56)),
        pw.Center(child: pw.Text(branchName, style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 2),
        div(),
        pw.Text(pad('Order #${order.orderNumber}', dts), style: ts(fontB, sz: 8)),
        div(),
        ...order.items.expand((item) {
          final sz = item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
          return [
            pw.Text(pad('${item.quantity}x ${item.itemName}$sz', egp(item.lineTotal)),
                style: ts(fontB, sz: 8)),
            ...item.addons.map((a) {
              final ap = a.unitPrice > 0 ? '+${egp(a.unitPrice)}' : '';
              final al = '  + ${a.addonName}';
              return pw.Text(ap.isNotEmpty ? pad(al, ap) : al, style: ts(font, sz: 7.5));
            }),
          ];
        }),
        div(),
        pw.Text(pad('Subtotal', egp(order.subtotal)), style: ts(font, sz: 8)),
        if (order.discountAmount > 0)
          pw.Text(pad('Discount', '- ${egp(order.discountAmount)}'), style: ts(font, sz: 8)),
        if (order.taxAmount > 0)
          pw.Text(pad('Tax', egp(order.taxAmount)), style: ts(font, sz: 8)),
        pw.Text(pad('TOTAL', egp(order.totalAmount)), style: ts(fontB, sz: 10)),
        div(),
        pw.Text(
            pad('Payment',
                order.paymentMethod[0].toUpperCase() +
                order.paymentMethod.substring(1).replaceAll('_', ' ')),
            style: ts(font, sz: 7.5)),
        if (order.customerName != null && order.customerName!.isNotEmpty)
          pw.Text(pad('Customer', order.customerName!), style: ts(font, sz: 7.5)),
        if (order.tellerName.isNotEmpty)
          pw.Text(pad('Teller', order.tellerName), style: ts(font, sz: 7.5)),
        pw.SizedBox(height: 3),
        pw.Center(child: pw.Text('Thank you for visiting!', style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 2),
        div(),
      ]),
    ));
    return pdf.save();
  }

  // ── Shift report PDF ───────────────────────────────────────────────────────

  static Future<Uint8List> _buildShiftReportPdf({
    required ShiftReport report,
    required String      branchName,
  }) async {
    final pdf   = pw.Document();
    final font  = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/Cairo-Regular.ttf')).buffer.asByteData());
    final fontB = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/Cairo-SemiBold.ttf')).buffer.asByteData());
    final logo  = pw.MemoryImage(
        (await rootBundle.load('assets/TheRue.png')).buffer.asUint8List());

    const cw = 40;
    pw.TextStyle ts(pw.Font f, {double sz = 8}) => pw.TextStyle(font: f, fontSize: sz);
    pw.Widget div()     => pw.Divider(thickness: 0.3,  color: PdfColors.grey600, height: 4);
    pw.Widget thinDiv() => pw.Divider(thickness: 0.15, color: PdfColors.grey400, height: 3);

    String pad(String l, String r) {
      final sp = cw - l.length - r.length;
      return sp <= 0 ? '$l $r' : l + ' ' * sp + r;
    }

    // Timestamps
    String fmtDt(DateTime dt) {
      final l = dt.toLocal();
      return '${l.year}/${l.month.toString().padLeft(2,'0')}/${l.day.toString().padLeft(2,'0')}'
             ' ${timeShort(dt)}';
    }

    final reportTs = fmtDt(report.reportTimestamp);
    final openTs   = fmtDt(report.openedAt);
    final closeTs  = report.closedAt != null ? fmtDt(report.closedAt!) : null;
    final openDt   = report.openedAt.toLocal();
    final bizDate  = '${openDt.year}/${openDt.month.toString().padLeft(2,'0')}/${openDt.day.toString().padLeft(2,'0')}';

    final shortage = (report.closingCashDeclared != null && report.closingCashSystem != null)
        ? report.closingCashDeclared! - report.closingCashSystem!
        : null;

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm, double.infinity,
          marginTop: 3 * PdfPageFormat.mm, marginBottom: 3 * PdfPageFormat.mm,
          marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

        // ── Header ────────────────────────────────────────────────────────────
        pw.Center(child: pw.Image(logo, width: 56)),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text(branchName,        style: ts(fontB, sz: 8))),
        pw.SizedBox(height: 1),
        pw.Center(child: pw.Text('Till Close Report', style: ts(fontB, sz: 9))),
        pw.Center(child: pw.Text('Business Date: $bizDate', style: ts(font, sz: 7.5))),
        pw.Center(child: pw.Text('Printed at: $reportTs',   style: ts(font, sz: 7.5))),
        div(),

        // ── Shift info ────────────────────────────────────────────────────────
        pw.SizedBox(height: 3),
        pw.Center(child: pw.Text('User: ${report.tellerName}', style: ts(font, sz: 8))),
        pw.Center(child: pw.Text('Opened At: $openTs',         style: ts(font, sz: 7.5))),
        if (closeTs != null)
          pw.Center(child: pw.Text('Closed At: $closeTs', style: ts(font, sz: 7.5)))
        else
          pw.Center(child: pw.Text('Status: Open (Interim Report)', style: ts(font, sz: 7.5))),
        div(),

        // ── Payments breakdown ────────────────────────────────────────────────
        pw.Center(child: pw.Text('Payments', style: ts(fontB, sz: 8))),
        pw.SizedBox(height: 3),
        ...report.paymentSummary.map((p) =>
            pw.Text(pad('${p.displayLabel}:', egp(p.total)), style: ts(font, sz: 8))),
        pw.SizedBox(height: 2),
        thinDiv(),
        pw.Text(pad('Total Payments:', egp(report.totalPayments)), style: ts(fontB, sz: 8)),
        pw.Text(pad('Total Returns:',  egp(report.totalReturns)),  style: ts(font,  sz: 8)),
        pw.Text(pad('Net Payments:',   egp(report.netPayments)),   style: ts(fontB, sz: 8)),
        div(),

        // ── Drawer operations ─────────────────────────────────────────────────
        pw.Center(child: pw.Text('Drawer Operations', style: ts(fontB, sz: 8))),
        pw.SizedBox(height: 3),
        pw.Text(pad('Total Pay In:',  egp(report.cashMovementsIn)),  style: ts(font, sz: 8)),
        pw.Text(pad('Total Pay Out:', egp(report.cashMovementsOut)), style: ts(font, sz: 8)),

        // Individual movements
        if (report.cashMovements.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          thinDiv(),
          ...report.cashMovements.map((m) {
            final sign   = m.isIn ? '+' : '-';
            final amount = '$sign${egp(m.amount.abs())}';
            // Truncate note to fit on one line
            final note   = m.note.length > 16 ? '${m.note.substring(0, 16)}…' : m.note;
            final label  = '  ${timeShort(m.createdAt)} $note';
            return pw.Text(pad(label, amount), style: ts(font, sz: 7));
          }),
        ],
        div(),

        // ── Cash reconciliation ───────────────────────────────────────────────
        pw.Text(pad('Opening Amount:', egp(report.openingCash)), style: ts(font, sz: 8)),
        if (report.closingCashDeclared != null) ...[
          pw.Text(pad('Closing Amount:', egp(report.closingCashDeclared!)), style: ts(font, sz: 8)),
          if (report.closingCashSystem != null)
            pw.Text(pad('Expected Cash:', egp(report.closingCashSystem!)), style: ts(font, sz: 8)),
          if (shortage != null)
            pw.Text(
                pad('Cash Shortage:',
                    shortage == 0
                        ? egp(0)
                        : '${shortage < 0 ? "-" : "+"}${egp(shortage.abs())}'),
                style: ts(shortage == 0 ? font : fontB, sz: 8)),
        ] else
          pw.Text('(Shift not yet closed)', style: ts(font, sz: 7.5)),
        div(),

        // ── Footer ────────────────────────────────────────────────────────────
        pw.SizedBox(height: 3),
        pw.Center(child: pw.Text('End Of Report', style: ts(fontB, sz: 8))),
        pw.SizedBox(height: 2),
        div(),
      ]),
    ));
    return pdf.save();
  }
}
DART
echo "  ✅  lib/core/services/printer_service.dart"

# =============================================================================
# 4. close_shift_screen.dart — add print button in AppBar
# =============================================================================
cat > lib/features/shift/close_shift_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/shift_api.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';
import '../../shared/widgets/label_value.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});
  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Map<String, TextEditingController> _invCtrs  = {};
  final Map<String, bool>                  _zeroWarn = {};

  bool    _loadingInv = true;
  bool    _submitting = false;
  bool    _printing   = false;
  String? _error;
  int     _declaredCash = 0;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_updateDeclared);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(shiftProvider.notifier).loadSystemCash();
      await _loadInventory();
    });
  }

  @override
  void dispose() {
    _cashCtrl
      ..removeListener(_updateDeclared)
      ..dispose();
    _noteCtrl.dispose();
    for (final c in _invCtrs.values) c.dispose();
    super.dispose();
  }

  void _updateDeclared() {
    final raw = double.tryParse(_cashCtrl.text);
    setState(() => _declaredCash = raw != null ? (raw * 100).round() : 0);
  }

  Future<void> _loadInventory() async {
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) { setState(() => _loadingInv = false); return; }
    await ref.read(shiftProvider.notifier).loadInventory(branchId);
    if (!mounted) return;
    final items = ref.read(shiftProvider).inventory;
    setState(() {
      _loadingInv = false;
      for (final i in items) {
        _invCtrs[i.id] =
            TextEditingController(text: i.currentStock.toStringAsFixed(2))
              ..addListener(() {
                final v   = double.tryParse(_invCtrs[i.id]?.text ?? '');
                final was = _zeroWarn[i.id] ?? false;
                final is0 = v == 0.0;
                if (was != is0) setState(() => _zeroWarn[i.id] = is0);
              });
      }
    });
  }

  Future<void> _printReport() async {
    final shift  = ref.read(shiftProvider).shift;
    final branch = ref.read(authProvider).branch;
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No open shift'), backgroundColor: AppColors.warning));
      return;
    }
    if (branch == null || !branch.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No printer configured for this branch'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _printing = true);
    try {
      final report = await ref.read(shiftApiProvider).getReport(shift.id);
      final err    = await PrinterService.printShiftReport(
        ip:         branch.printerIp!,
        port:       branch.printerPort,
        brand:      branch.printerBrand!,
        report:     report,
        branchName: branch.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text(err ?? 'Report printed'),
            backgroundColor: err != null ? AppColors.danger : AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text('Failed: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashCtrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }

    final inv       = ref.read(shiftProvider).inventory;
    final zeroItems = inv
        .where((i) {
          final v = double.tryParse(_invCtrs[i.id]?.text ?? '');
          return v == null || v == 0.0;
        })
        .map((i) => i.name)
        .toList();

    if (zeroItems.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:   Text('Zero Stock Warning', style: cairo(fontWeight: FontWeight.w800)),
          content: Text(
              'The following items have 0 stock:\n\n${zeroItems.join(", ")}'
              '\n\nAre you sure you want to submit?',
              style: cairo(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Go Back', style: cairo(color: AppColors.primary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Submit Anyway',
                    style: cairo(color: AppColors.danger, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() { _submitting = true; _error = null; });

    final counts = _invCtrs.entries
        .map((e) => {
              'inventory_item_id': e.key,
              'actual_stock':      double.tryParse(e.value.text) ?? 0.0,
            })
        .toList();

    final branchId = ref.read(authProvider).user!.branchId!;
    final ok       = await ref.read(shiftProvider.notifier).closeShift(
          branchId:        branchId,
          closingCash:     (raw * 100).round(),
          note:            _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          inventoryCounts: counts,
        );

    if (!mounted) return;

    if (ok) {
      final canNowLogout = await ref.read(authProvider.notifier).canLogout();
      if (!mounted) return;
      if (canNowLogout) {
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.go('/login');
      } else {
        context.go('/home');
      }
    } else {
      setState(() {
        _error      = ref.read(shiftProvider).error ?? 'Failed to close shift';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift    = ref.watch(shiftProvider).shift;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title:            const Text('Close Shift'),
        backgroundColor:  Colors.white,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
        actions: [
          if (shift != null)
            _printing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)))
                : IconButton(
                    icon:      const Icon(Icons.print_rounded),
                    tooltip:   'Print shift report',
                    onPressed: _printReport),
        ],
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : isTablet ? _buildTablet(shift) : _buildPhone(shift),
    );
  }

  Widget _buildPhone(dynamic shift) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SummaryCard(shift: shift),
              const SizedBox(height: 16),
              _CashCard(state: this),
              const SizedBox(height: 16),
              _InventoryCard(state: this),
              const SizedBox(height: 16),
              _SubmitSection(state: this),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      );

  Widget _buildTablet(dynamic shift) => Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [
                _SummaryCard(shift: shift),
                const SizedBox(height: 16),
                _CashCard(state: this),
              ])),
              const SizedBox(width: 20),
              Expanded(child: _InventoryCard(state: this)),
            ]),
          ),
        ),
        Container(
          color:   AppColors.bg,
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
          child:   _SubmitSection(state: this),
        ),
      ]);
}

// ── Section cards ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color    iconBg, iconColor;
  final String   title;
  const _SectionHeader({required this.icon, required this.iconBg,
      required this.iconColor, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(AppRadius.xs)),
            child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 12),
        Text(title, style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
      ]);
}

class _SummaryCard extends StatelessWidget {
  final dynamic shift;
  const _SummaryCard({required this.shift});
  @override
  Widget build(BuildContext context) => CardContainer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader(icon: Icons.summarize_outlined,
              iconBg: Color(0xFFEEF2FF), iconColor: AppColors.primary,
              title: 'Shift Summary'),
          const SizedBox(height: 18),
          LabelValue('Teller',       shift.tellerName),
          LabelValue('Opening Cash', egp(shift.openingCash)),
          LabelValue('Opened At',    dateTime(shift.openedAt)),
        ]),
      );
}

class _CashCard extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _CashCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemCash  = ref.watch(shiftProvider.select((s) => s.systemCash));
    final cashLoading = ref.watch(shiftProvider.select((s) => s.systemCashLoading));
    final discrepancy = state._declaredCash - systemCash;
    final showDiscrep = !cashLoading && state._cashCtrl.text.isNotEmpty;

    return CardContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.payments_outlined,
            iconBg: Color(0xFFECFDF5), iconColor: AppColors.success,
            title: 'Cash Count'),
        const SizedBox(height: 18),
        Container(
          padding:    const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('System Cash', style: cairo(fontSize: 12,
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text('Opening + cash orders + movements',
                  style: cairo(fontSize: 11, color: AppColors.textMuted)),
            ])),
            cashLoading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Text(egp(systemCash),
                    style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 18),
        Text('ACTUAL CASH IN DRAWER',
            style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextField(
          controller: state._cashCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
          style: cairo(fontSize: 30, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText:  'EGP  ',
            prefixStyle: cairo(fontSize: 20, color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
            hintText:  '0',
            hintStyle: cairo(fontSize: 30, fontWeight: FontWeight.w800,
                color: AppColors.border),
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeOut,
          child: showDiscrep
              ? Padding(padding: const EdgeInsets.only(top: 14),
                  child: _DiscrepancyRow(
                      discrepancy: discrepancy, systemCash: systemCash))
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: state._noteCtrl,
          decoration: InputDecoration(
            hintText:   'Cash note (optional)',
            hintStyle:  cairo(fontSize: 14, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.notes_rounded,
                size: 16, color: AppColors.textMuted),
          ),
        ),
      ]),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _InventoryCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(shiftProvider.select((s) => s.inventory));
    return CardContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.inventory_2_outlined,
            iconBg: Color(0xFFFFFBEB), iconColor: AppColors.warning,
            title: 'Inventory Count'),
        const SizedBox(height: 18),
        if (state._loadingInv)
          const Center(child: Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary)))
        else if (inventory.isEmpty)
          Text('No inventory items',
              style: cairo(fontSize: 13, color: AppColors.textMuted))
        else
          ...inventory.map((item) {
            final warn = state._zeroWarn[item.id] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: cairo(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('System: ${item.currentStock} ${item.unit}',
                      style: cairo(fontSize: 12, color: AppColors.textSecondary)),
                  if (warn)
                    Padding(padding: const EdgeInsets.only(top: 3),
                      child: Text('⚠ Value is 0 — confirm this is correct',
                          style: cairo(fontSize: 11, color: AppColors.warning))),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 130, child: TextField(
                  controller:   state._invCtrs[item.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign:    TextAlign.center,
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w600,
                      color: warn ? AppColors.warning : AppColors.textPrimary),
                  decoration: InputDecoration(
                    suffixText:     item.unit,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide:   BorderSide(
                            color: warn ? AppColors.warning : AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide:   const BorderSide(
                            color: AppColors.primary, width: 2)),
                  ),
                )),
              ]),
            );
          }),
      ]),
    );
  }
}

class _SubmitSection extends ConsumerWidget {
  final _CloseShiftScreenState state;
  const _SubmitSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    return Column(children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeOut,
        child: state._error != null
            ? Padding(padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color:        AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.danger.withOpacity(0.18))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Flexible(child: Text(state._error!,
                        style: cairo(fontSize: 13, color: AppColors.danger))),
                  ]),
                ))
            : const SizedBox.shrink(),
      ),
      if (!isOnline)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color:        const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border:       Border.all(color: const Color(0xFFFFD700))),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              Expanded(child: Text('Internet required to close a shift.',
                  style: cairo(fontSize: 12, color: const Color(0xFF856404)))),
            ]),
          ),
        ),
      AppButton(
        label:   'Close Shift',
        variant: BtnVariant.danger,
        loading: state._submitting,
        width:   double.infinity,
        icon:    Icons.lock_outline_rounded,
        onTap:   (!isOnline || state._submitting) ? null : state._close,
      ),
    ]);
  }
}

class _DiscrepancyRow extends StatelessWidget {
  final int discrepancy, systemCash;
  const _DiscrepancyRow({required this.discrepancy, required this.systemCash});

  @override
  Widget build(BuildContext context) {
    final isExact = discrepancy == 0;
    final isOver  = discrepancy > 0;
    final color   = isExact ? AppColors.success
        : isOver ? AppColors.warning : AppColors.danger;
    final icon  = isExact ? Icons.check_circle_outline_rounded
        : isOver ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final label = isExact ? 'Exact match'
        : isOver ? 'Over by ${egp(discrepancy.abs())}'
                 : 'Short by ${egp(discrepancy.abs())}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color:        color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border:       Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(label, style: cairo(fontSize: 13,
            fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        if (!isExact)
          Text('System: ${egp(systemCash)}',
              style: cairo(fontSize: 11, color: color.withOpacity(0.75))),
      ]),
    );
  }
}
DART
echo "  ✅  lib/features/shift/close_shift_screen.dart"

# =============================================================================
# 5. shift_history_screen.dart — add print report button per shift tile
# =============================================================================
cat > lib/features/shift/shift_history_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/order_api.dart';
import '../../core/api/shift_api.dart';
import '../../core/models/order.dart';
import '../../core/models/shift.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/error_banner.dart';

class ShiftHistoryScreen extends ConsumerStatefulWidget {
  const ShiftHistoryScreen({super.key});
  @override
  ConsumerState<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends ConsumerState<ShiftHistoryScreen> {
  List<Shift> _shifts  = [];
  bool        _loading = true;
  String?     _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) {
      setState(() { _loading = false; _error = 'No branch assigned'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final shifts = await ref.read(shiftApiProvider).list(branchId);
      if (mounted) setState(() { _shifts = shifts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon:      const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: Text('Shift History',
            style: cairo(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor:  Colors.white,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0F0F0))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Padding(padding: const EdgeInsets.all(24),
                  child: ErrorBanner(message: _error!, onRetry: _load))
              : _shifts.isEmpty
                  ? Center(child: Text('No shifts found',
                      style: cairo(fontSize: 15, color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding:     EdgeInsets.all(isTablet ? 24 : 16),
                      itemCount:   _shifts.length,
                      itemBuilder: (_, i) => _ShiftTile(shift: _shifts[i])),
    );
  }
}

class _ShiftTile extends ConsumerStatefulWidget {
  final Shift shift;
  const _ShiftTile({required this.shift});
  @override
  ConsumerState<_ShiftTile> createState() => _ShiftTileState();
}

class _ShiftTileState extends ConsumerState<_ShiftTile> {
  bool        _expanded      = false;
  bool        _loadingOrders = false;
  bool        _printing      = false;
  List<Order> _orders        = [];
  String?     _ordersError;

  Future<void> _toggleOrders() async {
    if (_orders.isNotEmpty) {
      setState(() => _expanded = !_expanded);
      return;
    }
    setState(() { _loadingOrders = true; _expanded = true; });
    try {
      final orders = await ref.read(orderApiProvider).list(shiftId: widget.shift.id);
      if (mounted) setState(() { _orders = orders; _loadingOrders = false; });
    } catch (e) {
      if (mounted) setState(() { _ordersError = e.toString(); _loadingOrders = false; });
    }
  }

  Future<void> _printReport() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No printer configured'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _printing = true);
    try {
      final report = await ref.read(shiftApiProvider).getReport(widget.shift.id);
      final err    = await PrinterService.printShiftReport(
        ip:         branch.printerIp!,
        port:       branch.printerPort,
        brand:      branch.printerBrand!,
        report:     report,
        branchName: branch.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text(err ?? 'Report printed'),
            backgroundColor: err != null ? AppColors.danger : AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text('Failed: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s           = widget.shift;
    final statusColor = s.status == 'open'
        ? AppColors.success
        : s.status == 'force_closed'
            ? AppColors.danger
            : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Header row ─────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:        _toggleOrders,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(children: [
              Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.tellerName,
                    style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(dateTime(s.openedAt),
                    style: cairo(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color:        statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(s.status.replaceAll('_', ' ').toUpperCase(),
                        style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                            color: statusColor))),
                if (s.closingCashDeclared != null) ...[
                  const SizedBox(height: 4),
                  Text(egp(s.closingCashDeclared!),
                      style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ]),
              const SizedBox(width: 4),

              // ── Print report button ───────────────────────────────────────
              _printing
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)))
                  : IconButton(
                      icon:      const Icon(Icons.receipt_long_rounded),
                      iconSize:  18,
                      color:     AppColors.textSecondary,
                      tooltip:   'Print shift report',
                      onPressed: _printReport,
                      padding:   const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),

              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size:  18,
                  color: AppColors.textMuted),
            ]),
          ),
        ),

        // ── Orders list (expanded) ──────────────────────────────────────────
        if (_expanded) ...[
          const Divider(height: 1, color: AppColors.border),
          if (_loadingOrders)
            const Padding(padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)))
          else if (_ordersError != null)
            Padding(padding: const EdgeInsets.all(12),
                child: Text(_ordersError!,
                    style: cairo(fontSize: 12, color: AppColors.danger)))
          else if (_orders.isEmpty)
            Padding(padding: const EdgeInsets.all(16),
                child: Text('No orders in this shift',
                    style: cairo(fontSize: 13, color: AppColors.textMuted)))
          else
            ..._orders.map((o) => _PastOrderRow(order: o)),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

class _PastOrderRow extends ConsumerStatefulWidget {
  final Order order;
  const _PastOrderRow({required this.order});
  @override
  ConsumerState<_PastOrderRow> createState() => _PastOrderRowState();
}

class _PastOrderRowState extends ConsumerState<_PastOrderRow> {
  bool _printing = false;

  Future<void> _print() async {
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No printer configured'),
          backgroundColor: AppColors.warning));
      return;
    }
    setState(() => _printing = true);
    try {
      Order full;
      try {
        full = await ref.read(orderApiProvider).get(widget.order.id);
      } catch (_) {
        full = widget.order;
      }
      final err = await PrinterService.print(
          ip:         branch.printerIp!,
          port:       branch.printerPort,
          order:      full,
          branchName: branch.name,
          brand:      branch.printerBrand!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text(err ?? 'Receipt printed'),
            backgroundColor: err != null ? AppColors.danger : AppColors.success));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o        = widget.order;
    final isVoided = o.status == 'voided';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
                color: isVoided
                    ? AppColors.borderLight
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text('#${o.orderNumber}',
                style: cairo(fontSize: 11, fontWeight: FontWeight.w700,
                    color: isVoided ? AppColors.textMuted : AppColors.primary))),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(timeShort(o.createdAt),
              style: cairo(fontSize: 12, color: AppColors.textSecondary)),
          if (o.customerName != null)
            Text(o.customerName!,
                style: cairo(fontSize: 11, color: AppColors.textMuted)),
        ])),
        Text(egp(o.totalAmount),
            style: cairo(fontSize: 13, fontWeight: FontWeight.w700,
                color:      isVoided ? AppColors.textMuted : AppColors.textPrimary,
                decoration: isVoided ? TextDecoration.lineThrough : null)),
        const SizedBox(width: 8),
        if (!isVoided)
          _printing
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : GestureDetector(
                  onTap: _print,
                  child: Container(
                      width:  32,
                      height: 32,
                      decoration: BoxDecoration(
                          color:        AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.print_rounded,
                          size: 15, color: AppColors.primary))),
      ]),
    );
  }
}
DART
echo "  ✅  lib/features/shift/shift_history_screen.dart"

echo ""
echo "✅  All done! Files written:"
echo "    lib/core/models/shift_report.dart"
echo "    lib/core/api/shift_api.dart        (getReport() added)"
echo "    lib/core/services/printer_service.dart"
echo "    lib/features/shift/close_shift_screen.dart"
echo "    lib/features/shift/shift_history_screen.dart"
echo ""
echo "📋  Backend (copy manually):"
echo "    shifts_handlers.rs → src/shifts/handlers.rs"
echo "    shifts_routes.rs   → src/shifts/routes.rs"
echo "    Then: cargo build --release"