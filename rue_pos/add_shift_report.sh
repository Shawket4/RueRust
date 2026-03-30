#!/usr/bin/env bash
# =============================================================================
#  Shift Report — Refined Patch
#  Fixes: proper right-aligned number columns (pw.Row instead of string pad),
#         Talabat labels in order receipt, corrected shortage sign,
#         order count per payment method, better timestamps, cash movement
#         two-line layout, consistent spacing.
#  Run from your Flutter project root.
# =============================================================================
set -euo pipefail
echo "🖨️  Applying refined shift report patch..."

mkdir -p lib/core/{models,services}

# =============================================================================
# 1. ShiftReport model  — unchanged, just republish cleanly
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
# 2. printer_service.dart — refined PDF layout
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

  // ── Public entry points ────────────────────────────────────────────────────

  static Future<String?> print({
    required String       ip,
    required int          port,
    required PrinterBrand brand,
    required Order        order,
    required String       branchName,
  }) async {
    final pdfBytes = await _buildReceiptPdf(order: order, branchName: branchName);
    return _send(ip: ip, port: port, brand: brand, pdfBytes: pdfBytes);
  }

  static Future<String?> printShiftReport({
    required String       ip,
    required int          port,
    required PrinterBrand brand,
    required ShiftReport  report,
    required String       branchName,
  }) async {
    final pdfBytes = await _buildShiftReportPdf(report: report, branchName: branchName);
    return _send(ip: ip, port: port, brand: brand, pdfBytes: pdfBytes);
  }

  // ── Transport ──────────────────────────────────────────────────────────────

  static Future<String?> _send({
    required String       ip,
    required int          port,
    required PrinterBrand brand,
    required Uint8List    pdfBytes,
  }) {
    final cleanIp = ip.split('/').first;
    return switch (brand) {
      PrinterBrand.star  => _printStar(ip: cleanIp, pdfBytes: pdfBytes),
      PrinterBrand.epson => _printEpson(ip: cleanIp, port: port, pdfBytes: pdfBytes),
    };
  }

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
            final r   = pixels[idx];
            final g   = pixels[idx + 1];
            final b   = pixels[idx + 2];
            final a   = pixels[idx + 3];
            final rW  = ((r * a) + (255 * (255 - a))) ~/ 255;
            final gW  = ((g * a) + (255 * (255 - a))) ~/ 255;
            final bW  = ((b * a) + (255 * (255 - a))) ~/ 255;
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

  // ── Shared PDF helpers ─────────────────────────────────────────────────────
  //
  //  _row()  — two-column layout using pw.Row + pw.Expanded so numbers are
  //             always flush-right regardless of Cairo glyph widths.
  //  _divider / _thinDivider — consistent separators.

  static pw.Widget _row(
    String    label,
    String    value, {
    required  pw.Font font,
    required  pw.Font fontB,
    double    sz        = 8,
    bool      bold      = false,
    bool      boldValue = false,
    PdfColor? valueColor,
    double    leftIndent = 0,
  }) {
    final labelStyle = pw.TextStyle(
      font:     bold ? fontB : font,
      fontSize: sz,
    );
    final valueStyle = pw.TextStyle(
      font:     (bold || boldValue) ? fontB : font,
      fontSize: sz,
      color:    valueColor,
    );
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: leftIndent, bottom: 1.5),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(label, style: labelStyle)),
        pw.Text(value, style: valueStyle, textAlign: pw.TextAlign.right),
      ]),
    );
  }

  static pw.Widget _divider() =>
      pw.Divider(thickness: 0.4, color: PdfColors.grey600, height: 6);

  static pw.Widget _thinDivider() =>
      pw.Divider(thickness: 0.2, color: PdfColors.grey400, height: 4);

  static String _fmtDt(DateTime dt) {
    final l = dt.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    final m = l.month.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '$d/$m/${l.year}  $hh:$mm';
  }

  /// Formats a payment method string for the order receipt footer.
  /// Handles all known Talabat variants and underscore-separated names.
  static String _fmtPayment(String raw) => switch (raw) {
    'cash'           => 'Cash',
    'card'           => 'Card',
    'digital_wallet' => 'Digital Wallet',
    'mixed'          => 'Mixed',
    'talabat_online' => 'Talabat Online',
    'talabat_cash'   => 'Talabat Cash',
    _                => raw[0].toUpperCase() +
                        raw.substring(1).replaceAll('_', ' '),
  };

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

    pw.TextStyle ts(pw.Font f, {double sz = 8, PdfColor? color}) =>
        pw.TextStyle(font: f, fontSize: sz, color: color);

    final dts = _fmtDt(order.createdAt);

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm, double.infinity,
          marginTop:    2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
          marginLeft:   2 * PdfPageFormat.mm,
          marginRight:  2 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

        // Header
        pw.Center(child: pw.Image(logo, width: 56)),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text(branchName, style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 2),
        _divider(),

        // Order number + timestamp
        _row('Order #${order.orderNumber}', dts, font: font, fontB: fontB,
            bold: true, sz: 8),
        _divider(),

        // Items
        ...order.items.expand((item) {
          final sizePart = item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
          return [
            _row('${item.quantity}x ${item.itemName}$sizePart',
                egp(item.lineTotal), font: font, fontB: fontB, bold: true, sz: 8),
            ...item.addons.map((a) {
              final aPrice = a.unitPrice > 0 ? '+${egp(a.unitPrice)}' : '';
              return aPrice.isNotEmpty
                  ? _row('  + ${a.addonName}', aPrice,
                      font: font, fontB: fontB, sz: 7.5, leftIndent: 4)
                  : pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 4, bottom: 1.5),
                      child: pw.Text('  + ${a.addonName}', style: ts(font, sz: 7.5)));
            }),
          ];
        }),
        _divider(),

        // Totals
        if (order.discountAmount > 0)
          _row('Subtotal', egp(order.subtotal), font: font, fontB: fontB, sz: 8),
        if (order.discountAmount > 0)
          _row('Discount', '- ${egp(order.discountAmount)}',
              font: font, fontB: fontB, sz: 8,
              valueColor: PdfColors.red700),
        if (order.taxAmount > 0)
          _row('Tax', egp(order.taxAmount), font: font, fontB: fontB, sz: 8),
        _row('TOTAL', egp(order.totalAmount),
            font: font, fontB: fontB, bold: true, boldValue: true, sz: 10),
        _divider(),

        // Footer metadata
        _row('Payment', _fmtPayment(order.paymentMethod),
            font: font, fontB: fontB, sz: 7.5),
        if (order.customerName != null && order.customerName!.isNotEmpty)
          _row('Customer', order.customerName!,
              font: font, fontB: fontB, sz: 7.5),
        if (order.tellerName.isNotEmpty)
          _row('Teller', order.tellerName, font: font, fontB: fontB, sz: 7.5),

        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('Thank you for visiting!', style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 2),
        _divider(),
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

    pw.TextStyle ts(pw.Font f, {double sz = 8, PdfColor? color}) =>
        pw.TextStyle(font: f, fontSize: sz, color: color);

    // Helpers that close over font/fontB
    pw.Widget row(String l, String v,
            {bool bold = false, bool boldVal = false,
             double sz = 8, PdfColor? color, double indent = 0}) =>
        _row(l, v,
            font: font, fontB: fontB,
            bold: bold, boldValue: boldVal,
            sz: sz, valueColor: color, leftIndent: indent);

    pw.Widget div()     => _divider();
    pw.Widget thinDiv() => _thinDivider();

    // Formatted timestamps
    final openDt  = report.openedAt.toLocal();
    final bizDate = '${openDt.day.toString().padLeft(2,'0')}/'
                    '${openDt.month.toString().padLeft(2,'0')}/${openDt.year}';
    final openTs  = _fmtDt(report.openedAt);
    final closeTs = report.closedAt != null ? _fmtDt(report.closedAt!) : null;

    // The timestamp shown at the top:
    //  • closed shift  → "Closed at: HH:MM" (the close time, not now)
    //  • open shift    → "Printed at: HH:MM" (now)
    final topTsLabel = report.isOpen ? 'Printed at' : 'Closed at';
    final topTsValue = report.closedAt != null
        ? _fmtDt(report.closedAt!)
        : _fmtDt(report.printedAt);

    // Cash shortage: positive = drawer short (declared < system), negative = over
    // shortage = system - declared  →  positive means you're missing money
    final shortage = (report.closingCashDeclared != null &&
                      report.closingCashSystem   != null)
        ? report.closingCashSystem! - report.closingCashDeclared!
        : null;

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm, double.infinity,
          marginTop:    3 * PdfPageFormat.mm,
          marginBottom: 3 * PdfPageFormat.mm,
          marginLeft:   3 * PdfPageFormat.mm,
          marginRight:  3 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [

        // ── Header ────────────────────────────────────────────────────────────
        pw.Center(child: pw.Image(logo, width: 56)),
        pw.SizedBox(height: 3),
        pw.Center(child: pw.Text(branchName,         style: ts(fontB, sz: 8.5))),
        pw.Center(child: pw.Text('Till Close Report', style: ts(fontB, sz: 9.5))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('Business Date: $bizDate', style: ts(font, sz: 7.5))),
        pw.Center(child: pw.Text('$topTsLabel: $topTsValue', style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 4),
        div(),

        // ── Shift info ────────────────────────────────────────────────────────
        pw.SizedBox(height: 2),
        row('Teller', report.tellerName, sz: 8),
        row('Opened', openTs, sz: 7.5),
        if (closeTs != null)
          row('Closed', closeTs, sz: 7.5)
        else
          pw.Center(child: pw.Text(
              '— Interim Report (Shift Still Open) —',
              style: ts(font, sz: 7, color: PdfColors.grey600))),
        pw.SizedBox(height: 2),
        div(),

        // ── Payments breakdown ────────────────────────────────────────────────
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('PAYMENTS', style: ts(fontB, sz: 7.5,
            color: PdfColors.grey700))),
        pw.SizedBox(height: 4),

        // Each payment method — label, order count sub-line, amount right-aligned
        ...report.paymentSummary.map((p) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(p.displayLabel,
                    style: ts(fontB, sz: 8)),
                pw.Text('${p.orderCount} order${p.orderCount == 1 ? '' : 's'}',
                    style: ts(font, sz: 7, color: PdfColors.grey600)),
              ],
            )),
            pw.Text(egp(p.total),
                style: ts(fontB, sz: 8), textAlign: pw.TextAlign.right),
          ]),
        )),

        pw.SizedBox(height: 2),
        thinDiv(),

        row('Total Payments', egp(report.totalPayments),
            bold: true, boldVal: true, sz: 8),
        if (report.totalReturns > 0)
          row('Total Returns', '- ${egp(report.totalReturns)}',
              sz: 8, color: PdfColors.red700),
        pw.SizedBox(height: 1),
        row('Net Payments', egp(report.netPayments),
            bold: true, boldVal: true, sz: 9),
        pw.SizedBox(height: 2),
        div(),

        // ── Drawer operations ─────────────────────────────────────────────────
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('DRAWER OPERATIONS', style: ts(fontB, sz: 7.5,
            color: PdfColors.grey700))),
        pw.SizedBox(height: 4),

        row('Pay In',  egp(report.cashMovementsIn),  sz: 8),
        row('Pay Out', egp(report.cashMovementsOut), sz: 8),

        if (report.cashMovements.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          thinDiv(),
          pw.SizedBox(height: 2),
          ...report.cashMovements.map((m) {
            final sign   = m.isIn ? '+' : '−';
            final amount = '$sign ${egp(m.amount.abs())}';
            final time   = () {
              final l = m.createdAt.toLocal();
              return '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
            }();
            // Two-line: note on top, time + amount on the row
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(m.note, style: ts(font, sz: 7.5)),
                  pw.Row(children: [
                    pw.Text(time,
                        style: ts(font, sz: 7, color: PdfColors.grey600)),
                    pw.Spacer(),
                    pw.Text(amount,
                        style: ts(m.isIn ? fontB : font, sz: 7.5,
                            color: m.isIn ? PdfColors.green700 : PdfColors.red700),
                        textAlign: pw.TextAlign.right),
                  ]),
                ],
              ),
            );
          }),
        ],

        pw.SizedBox(height: 2),
        div(),

        // ── Cash reconciliation ───────────────────────────────────────────────
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('CASH RECONCILIATION', style: ts(fontB, sz: 7.5,
            color: PdfColors.grey700))),
        pw.SizedBox(height: 4),

        row('Opening Cash', egp(report.openingCash), sz: 8),

        if (report.closingCashSystem != null)
          row('Expected in Drawer', egp(report.closingCashSystem!), sz: 8),

        if (report.closingCashDeclared != null)
          row('Actual in Drawer', egp(report.closingCashDeclared!),
              bold: true, sz: 8)
        else
          pw.Center(child: pw.Text('(Shift not yet closed)',
              style: ts(font, sz: 7.5, color: PdfColors.grey600))),

        if (shortage != null) ...[
          pw.SizedBox(height: 2),
          thinDiv(),
          pw.SizedBox(height: 2),
          if (shortage == 0)
            row('Difference', egp(0),
                bold: true, color: PdfColors.green700, sz: 8.5)
          else if (shortage > 0)
            row('Short by', egp(shortage),
                bold: true, color: PdfColors.red700, sz: 8.5)
          else
            row('Over by', egp(shortage.abs()),
                bold: true, color: PdfColors.orange700, sz: 8.5),
        ],

        pw.SizedBox(height: 4),
        div(),

        // ── Footer ────────────────────────────────────────────────────────────
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('— End of Report —',
            style: ts(fontB, sz: 8, color: PdfColors.grey600))),
        pw.SizedBox(height: 2),
        div(),
      ]),
    ));
    return pdf.save();
  }
}
DART
echo "  ✅  lib/core/services/printer_service.dart"

echo ""
echo "✅  Refined patch complete. Files written:"
echo "    lib/core/models/shift_report.dart"
echo "    lib/core/services/printer_service.dart"
echo ""
echo "📋  What changed vs the previous version:"
echo "    • _row() uses pw.Row + pw.Expanded — numbers flush-right regardless of font"
echo "    • All payment methods (incl. Talabat Online/Cash) formatted via _fmtPayment()"
echo "    • Each payment method shows order count on a sub-line"
echo "    • Cash movements: two-line layout (note + time/amount row)"
echo "    • Shortage sign fixed: positive = short, negative = over"
echo "    • 'Closed at' label for closed shifts, 'Printed at' for interim"
echo "    • Section headers use grey caps labels (PAYMENTS, DRAWER OPERATIONS, etc.)"
echo "    • Consistent spacing and divider weights throughout"