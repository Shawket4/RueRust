// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
import '../models/branch.dart';
import '../models/order.dart';
import '../utils/formatting.dart';

class PrinterService {
  static const _printerWidth = 576;
  static const _timeout = Duration(seconds: 5);

  // ── Public entry point ────────────────────────────────────────────────────
  static Future<String?> print({
    required String ip,
    required int port,
    required PrinterBrand brand,
    required Order order,
    required String branchName,
  }) async {
    final cleanIp = ip.split('/').first;
    switch (brand) {
      case PrinterBrand.star:
        return _printStar(
          ip: cleanIp,
          order: order,
          branchName: branchName,
        );
      case PrinterBrand.epson:
        return _printEpson(
          ip: cleanIp,
          port: port,
          order: order,
          branchName: branchName,
        );
    }
  }

  // ── Star (via StarXpand SDK) ───────────────────────────────────────────────
  static Future<String?> _printStar({
    required String ip,
    required Order order,
    required String branchName,
  }) async {
    try {
      final device = StarDevice(ip, StarInterfaceType.lan);
      final connected =
          await StarXpand.instance.connect(device, monitor: false);
      if (!connected) return 'Could not connect to Star printer';

      final pdfBytes = await _buildReceiptPdf(
        order: order,
        branchName: branchName,
      );
      final success = await StarXpand.instance.printPdf(
        pdfBytes,
        width: _printerWidth,
      );
      return success ? null : 'Star print failed';
    } catch (e) {
      return 'Star printer error: $e';
    } finally {
      await StarXpand.instance.disconnect();
    }
  }

  // ── Epson (raw ESC/POS over TCP) ──────────────────────────────────────────
  static Future<String?> _printEpson({
    required String ip,
    required int port,
    required Order order,
    required String branchName,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: _timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      final bytes = _buildEscPosReceipt(order: order, branchName: branchName);
      socket.add(bytes);
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

  // ── ESC/POS receipt builder (Epson) ───────────────────────────────────────
  static Uint8List _buildEscPosReceipt({
    required Order order,
    required String branchName,
  }) {
    const esc = 0x1B;
    const gs = 0x1D;
    const lf = 0x0A;
    const col = 42;

    List<int> text(String s) => s.runes.map((c) => c < 256 ? c : 0x3F).toList();
    List<int> line(String s) => [...text(s), lf];
    List<int> align(int a) => [esc, 0x61, a];
    List<int> bold(bool on) => [esc, 0x45, on ? 1 : 0];
    List<int> dblSize(bool on) => [gs, 0x21, on ? 0x11 : 0x00];
    List<int> divider() => line('-' * col);

    String padRow(String left, String right) {
      final space = col - left.length - right.length;
      return space > 0 ? left + ' ' * space + right : '$left $right';
    }

    final buf = <int>[];
    buf.addAll([esc, 0x40]); // init

    // Header
    buf.addAll(align(1));
    buf.addAll(dblSize(true));
    buf.addAll(bold(true));
    buf.addAll(line('THE RUE COFFEE'));
    buf.addAll(dblSize(false));
    buf.addAll(bold(false));
    buf.addAll(line(branchName));
    buf.addAll(line(''));
    buf.addAll(divider());

    // Order info
    buf.addAll(align(0));
    buf.addAll(bold(true));
    buf.addAll(line(padRow(
      'Order #${order.orderNumber}',
      timeShort(order.createdAt),
    )));
    buf.addAll(bold(false));
    buf.addAll(divider());

    // Items
    for (final item in order.items) {
      final sizePart = item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
      final label = '${item.quantity}x ${item.itemName}$sizePart';
      buf.addAll(line(padRow(label, egp(item.lineTotal))));
      for (final addon in item.addons) {
        final aLabel = '  + ${addon.addonName}';
        final aPrice = addon.unitPrice > 0 ? '+${egp(addon.unitPrice)}' : '';
        buf.addAll(line(aPrice.isNotEmpty ? padRow(aLabel, aPrice) : aLabel));
      }
    }

    buf.addAll(divider());

    // Totals
    buf.addAll(line(padRow('Subtotal', egp(order.subtotal))));
    if (order.discountAmount > 0) {
      buf.addAll(line(padRow('Discount', '- ${egp(order.discountAmount)}')));
    }
    if (order.taxAmount > 0) {
      buf.addAll(line(padRow('Tax', egp(order.taxAmount))));
    }
    buf.addAll(bold(true));
    buf.addAll(line(padRow('TOTAL', egp(order.totalAmount))));
    buf.addAll(bold(false));
    buf.addAll(divider());

    // Footer
    final payLabel = order.paymentMethod[0].toUpperCase() +
        order.paymentMethod.substring(1).replaceAll('_', ' ');
    buf.addAll(line('Payment : $payLabel'));
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buf.addAll(line('Customer: ${order.customerName}'));
    }
    if (order.tellerName.isNotEmpty) {
      buf.addAll(line('Teller  : ${order.tellerName}'));
    }
    buf.addAll(line(''));
    buf.addAll(align(1));
    buf.addAll(line('Thank you for visiting!'));
    buf.addAll(line(''));
    buf.addAll(line(''));
    buf.addAll(line(''));

    // Cut
    buf.addAll([gs, 0x56, 0x41, 0x05]);

    return Uint8List.fromList(buf);
  }

  // ── PDF receipt builder (Star) ────────────────────────────────────────────
  static Future<Uint8List> _buildReceiptPdf({
    required Order order,
    required String branchName,
  }) async {
    final pdf = pw.Document();

    final font = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
          .buffer
          .asByteData(),
    );
    final fontBold = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/Cairo-Bold.ttf'))
          .buffer
          .asByteData(),
    );

    final logoData = await rootBundle.load('assets/TheRue.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    const charWidth = 40;

    pw.TextStyle ts(pw.Font f, {double size = 9}) =>
        pw.TextStyle(font: f, fontSize: size);

    pw.Widget divider() => pw.Divider(thickness: 0.5, color: PdfColors.black);

    String padRow(String left, String right) {
      final space = charWidth - left.length - right.length;
      return space > 0 ? left + ' ' * space + right : '$left $right';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          72 * PdfPageFormat.mm,
          double.infinity,
          marginTop: 6 * PdfPageFormat.mm,
          marginBottom: 8 * PdfPageFormat.mm,
          marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Logo
            pw.Center(child: pw.Image(logoImage, width: 100)),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(branchName, style: ts(font, size: 9))),
            pw.SizedBox(height: 6),
            divider(),
            pw.SizedBox(height: 4),

            // Order info
            pw.Text(
              padRow(
                'Order #${order.orderNumber}',
                timeShort(order.createdAt),
              ),
              style: ts(fontBold, size: 10),
            ),
            pw.SizedBox(height: 4),
            divider(),
            pw.SizedBox(height: 4),

            // Items
            ...order.items.expand((item) {
              final sizePart =
                  item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
              final label = '${item.quantity}x ${item.itemName}$sizePart';
              return [
                pw.Text(
                  padRow(label, egp(item.lineTotal)),
                  style: ts(fontBold, size: 9),
                ),
                ...item.addons.map((addon) {
                  final aLabel = '  + ${addon.addonName}';
                  final aPrice =
                      addon.unitPrice > 0 ? '+${egp(addon.unitPrice)}' : '';
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Text(
                      aPrice.isNotEmpty ? padRow(aLabel, aPrice) : aLabel,
                      style: ts(font, size: 8),
                    ),
                  );
                }),
                pw.SizedBox(height: 3),
              ];
            }),

            divider(),
            pw.SizedBox(height: 4),

            // Totals
            pw.Text(
              padRow('Subtotal', egp(order.subtotal)),
              style: ts(font, size: 9),
            ),
            if (order.discountAmount > 0)
              pw.Text(
                padRow('Discount', '- ${egp(order.discountAmount)}'),
                style: ts(font, size: 9),
              ),
            if (order.taxAmount > 0)
              pw.Text(
                padRow('Tax', egp(order.taxAmount)),
                style: ts(font, size: 9),
              ),
            pw.SizedBox(height: 3),
            pw.Text(
              padRow('TOTAL', egp(order.totalAmount)),
              style: ts(fontBold, size: 13),
            ),
            pw.SizedBox(height: 4),
            divider(),
            pw.SizedBox(height: 4),

            // Footer
            pw.Text(
              padRow(
                'Payment',
                order.paymentMethod[0].toUpperCase() +
                    order.paymentMethod.substring(1).replaceAll('_', ' '),
              ),
              style: ts(font, size: 9),
            ),
            if (order.customerName != null && order.customerName!.isNotEmpty)
              pw.Text(
                padRow('Customer', order.customerName!),
                style: ts(font, size: 9),
              ),
            if (order.tellerName.isNotEmpty)
              pw.Text(
                padRow('Teller', order.tellerName),
                style: ts(font, size: 9),
              ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Thank you for visiting!',
                style: ts(fontBold, size: 9),
              ),
            ),
            pw.SizedBox(height: 6),
            divider(),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
