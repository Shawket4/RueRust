// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:starxpand_sdk_wrapper/starxpand_sdk_wrapper.dart';
import '../models/branch.dart';
import '../models/order.dart';
import '../utils/formatting.dart';

class PrinterService {
  static const _printerWidth = 576;
  static const _timeout = Duration(seconds: 5);

  static Future<String?> print({
    required String ip,
    required int port,
    required PrinterBrand brand,
    required Order order,
    required String branchName,
  }) async {
    final cleanIp = ip.split('/').first;
    final pdfBytes =
        await _buildReceiptPdf(order: order, branchName: branchName);
    switch (brand) {
      case PrinterBrand.star:
        return _printStar(ip: cleanIp, pdfBytes: pdfBytes);
      case PrinterBrand.epson:
        return _printEpson(ip: cleanIp, port: port, pdfBytes: pdfBytes);
    }
  }

  static Future<String?> _printStar({
    required String ip,
    required Uint8List pdfBytes,
  }) async {
    try {
      final device = StarDevice(ip, StarInterfaceType.lan);
      final connected =
          await StarXpand.instance.connect(device, monitor: false);
      if (!connected) return 'Could not connect to Star printer';
      final success =
          await StarXpand.instance.printPdf(pdfBytes, width: _printerWidth);
      return success ? null : 'Star print failed';
    } catch (e) {
      return 'Star printer error: $e';
    } finally {
      await StarXpand.instance.disconnect();
    }
  }

  static Future<String?> _printEpson({
    required String ip,
    required int port,
    required Uint8List pdfBytes,
  }) async {
    Socket? socket;
    try {
      final pages = Printing.raster(pdfBytes, dpi: 203);
      final page = await pages.first;
      final png = await page.toPng();
      final imgBytes = await _pngToEscPosRaster(png, page.width, page.height);
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

  static Future<Uint8List> _pngToEscPosRaster(
    Uint8List png,
    int widthPx,
    int heightPx,
  ) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final imgData =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (imgData == null) throw Exception('Failed to decode image');

    final pixels = imgData.buffer.asUint8List();
    final buf = <int>[];

    buf.addAll([0x1B, 0x40]);

    final widthBytes = (widthPx + 7) ~/ 8;
    final xL = widthBytes & 0xFF;
    final xH = (widthBytes >> 8) & 0xFF;
    final yL = heightPx & 0xFF;
    final yH = (heightPx >> 8) & 0xFF;

    buf.addAll([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);

    for (int y = 0; y < heightPx; y++) {
      for (int xByte = 0; xByte < widthBytes; xByte++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x < widthPx) {
            final idx = (y * widthPx + x) * 4;
            final r = pixels[idx];
            final g = pixels[idx + 1];
            final b = pixels[idx + 2];
            final a = pixels[idx + 3];
            final rW = ((r * a) + (255 * (255 - a))) ~/ 255;
            final gW = ((g * a) + (255 * (255 - a))) ~/ 255;
            final bW = ((b * a) + (255 * (255 - a))) ~/ 255;
            final lum = (0.299 * rW + 0.587 * gW + 0.114 * bW).round();
            if (lum < 128) byte |= (0x80 >> bit);
          }
        }
        buf.add(byte);
      }
    }

    buf.addAll([0x1B, 0x64, 0x05]);
    buf.addAll([0x1D, 0x56, 0x41, 0x05]);

    return Uint8List.fromList(buf);
  }

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
    final fontSemiBold = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/Cairo-SemiBold.ttf'))
          .buffer
          .asByteData(),
    );

    final logoData = await rootBundle.load('assets/TheRue.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    const charWidth = 40;

    pw.TextStyle ts(pw.Font f, {double size = 8.0}) =>
        pw.TextStyle(font: f, fontSize: size);

    pw.Widget divider() => pw.Divider(
          thickness: 0.3,
          color: PdfColors.grey600,
          height: 4,
        );

    String padRow(String left, String right) {
      final space = charWidth - left.length - right.length;
      if (space <= 0) return '$left $right';
      return left + ' ' * space + right;
    }

    final dt = order.createdAt.toLocal();
    final dateTimeStr = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${timeShort(order.createdAt)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          72 * PdfPageFormat.mm,
          double.infinity,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
          marginLeft: 2 * PdfPageFormat.mm,
          marginRight: 2 * PdfPageFormat.mm,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Logo
            pw.Center(child: pw.Image(logoImage, width: 56)),

            // Branch
            pw.Center(child: pw.Text(branchName, style: ts(font, size: 7.5))),
            pw.SizedBox(height: 2),
            divider(),

            // Order number + date/time
            pw.Text(
              padRow('Order #${order.orderNumber}', dateTimeStr),
              style: ts(fontSemiBold, size: 8),
            ),
            divider(),

            // Items
            ...order.items.expand((item) {
              final sizePart =
                  item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
              final label = '${item.quantity}x ${item.itemName}$sizePart';
              return [
                pw.Text(
                  padRow(label, egp(item.lineTotal)),
                  style: ts(fontSemiBold, size: 8),
                ),
                ...item.addons.map((addon) {
                  final aLabel = '  + ${addon.addonName}';
                  final aPrice =
                      addon.unitPrice > 0 ? '+${egp(addon.unitPrice)}' : '';
                  return pw.Text(
                    aPrice.isNotEmpty ? padRow(aLabel, aPrice) : aLabel,
                    style: ts(font, size: 7.5),
                  );
                }),
              ];
            }),

            divider(),

            // Totals
            pw.Text(padRow('Subtotal', egp(order.subtotal)),
                style: ts(font, size: 8)),
            if (order.discountAmount > 0)
              pw.Text(padRow('Discount', '- ${egp(order.discountAmount)}'),
                  style: ts(font, size: 8)),
            if (order.taxAmount > 0)
              pw.Text(padRow('Tax', egp(order.taxAmount)),
                  style: ts(font, size: 8)),
            pw.Text(
              padRow('TOTAL', egp(order.totalAmount)),
              style: ts(fontSemiBold, size: 10),
            ),
            divider(),

            // Footer
            pw.Text(
              padRow(
                'Payment',
                order.paymentMethod[0].toUpperCase() +
                    order.paymentMethod.substring(1).replaceAll('_', ' '),
              ),
              style: ts(font, size: 7.5),
            ),
            if (order.customerName != null && order.customerName!.isNotEmpty)
              pw.Text(padRow('Customer', order.customerName!),
                  style: ts(font, size: 7.5)),
            if (order.tellerName.isNotEmpty)
              pw.Text(padRow('Teller', order.tellerName),
                  style: ts(font, size: 7.5)),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text('Thank you for visiting!',
                  style: ts(font, size: 7.5)),
            ),
            pw.SizedBox(height: 2),
            divider(),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
