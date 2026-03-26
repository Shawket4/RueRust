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
    return switch (brand) {
      PrinterBrand.star => _printStar(ip: cleanIp, pdfBytes: pdfBytes),
      PrinterBrand.epson =>
        _printEpson(ip: cleanIp, port: port, pdfBytes: pdfBytes),
    };
  }

  static Future<String?> _printStar(
      {required String ip, required Uint8List pdfBytes}) async {
    try {
      final device = StarDevice(ip, StarInterfaceType.lan);
      final connected =
          await StarXpand.instance.connect(device, monitor: false);
      if (!connected) return 'Could not connect to Star printer';
      final ok =
          await StarXpand.instance.printPdf(pdfBytes, width: _printerWidth);
      return ok ? null : 'Star print failed';
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
      final page = await Printing.raster(pdfBytes, dpi: 203).first;
      final png = await page.toPng();
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

  static Future<Uint8List> _pngToEscPos(Uint8List png, int w, int h) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final imgData =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (imgData == null) throw Exception('Failed to decode image');
    final pixels = imgData.buffer.asUint8List();
    final buf = <int>[];
    buf.addAll([0x1B, 0x40]);
    final wB = (w + 7) ~/ 8;
    buf.addAll([
      0x1D,
      0x76,
      0x30,
      0x00,
      wB & 0xFF,
      (wB >> 8) & 0xFF,
      h & 0xFF,
      (h >> 8) & 0xFF
    ]);
    for (int y = 0; y < h; y++) {
      for (int xB = 0; xB < wB; xB++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = xB * 8 + bit;
          if (x < w) {
            final idx = (y * w + x) * 4;
            final r = pixels[idx];
            final g = pixels[idx + 1];
            final b = pixels[idx + 2];
            final a = pixels[idx + 3];
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

  static Future<Uint8List> _buildReceiptPdf({
    required Order order,
    required String branchName,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
            .buffer
            .asByteData());
    final fontB = pw.Font.ttf(
        (await rootBundle.load('assets/fonts/Cairo-SemiBold.ttf'))
            .buffer
            .asByteData());
    final logo = pw.MemoryImage(
        (await rootBundle.load('assets/TheRue.png')).buffer.asUint8List());
    const cw = 40;
    pw.TextStyle ts(pw.Font f, {double sz = 8}) =>
        pw.TextStyle(font: f, fontSize: sz);
    pw.Widget div() =>
        pw.Divider(thickness: 0.3, color: PdfColors.grey600, height: 4);
    String pad(String l, String r) {
      final sp = cw - l.length - r.length;
      return sp <= 0 ? '$l $r' : l + ' ' * sp + r;
    }

    final dt = order.createdAt.toLocal();
    final dts =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${timeShort(order.createdAt)}';

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(72 * PdfPageFormat.mm, double.infinity,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
          marginLeft: 2 * PdfPageFormat.mm,
          marginRight: 2 * PdfPageFormat.mm),
      build: (ctx) => pw
          .Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Image(logo, width: 56)),
        pw.Center(child: pw.Text(branchName, style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 2),
        div(),
        pw.Text(pad('Order #${order.orderNumber}', dts),
            style: ts(fontB, sz: 8)),
        div(),
        ...order.items.expand((item) {
          final sz = item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
          return [
            pw.Text(
                pad('${item.quantity}x ${item.itemName}$sz',
                    egp(item.lineTotal)),
                style: ts(fontB, sz: 8)),
            ...item.addons.map((a) {
              final ap = a.unitPrice > 0 ? '+${egp(a.unitPrice)}' : '';
              final al = '  + ${a.addonName}';
              return pw.Text(ap.isNotEmpty ? pad(al, ap) : al,
                  style: ts(font, sz: 7.5));
            }),
          ];
        }),
        div(),
        pw.Text(pad('Subtotal', egp(order.subtotal)), style: ts(font, sz: 8)),
        if (order.discountAmount > 0)
          pw.Text(pad('Discount', '- ${egp(order.discountAmount)}'),
              style: ts(font, sz: 8)),
        if (order.taxAmount > 0)
          pw.Text(pad('Tax', egp(order.taxAmount)), style: ts(font, sz: 8)),
        pw.Text(pad('TOTAL', egp(order.totalAmount)), style: ts(fontB, sz: 10)),
        div(),
        pw.Text(
            pad(
                'Payment',
                order.paymentMethod[0].toUpperCase() +
                    order.paymentMethod.substring(1).replaceAll('_', ' ')),
            style: ts(font, sz: 7.5)),
        if (order.customerName != null && order.customerName!.isNotEmpty)
          pw.Text(pad('Customer', order.customerName!),
              style: ts(font, sz: 7.5)),
        if (order.tellerName.isNotEmpty)
          pw.Text(pad('Teller', order.tellerName), style: ts(font, sz: 7.5)),
        pw.SizedBox(height: 3),
        pw.Center(
            child:
                pw.Text('Thank you for visiting!', style: ts(font, sz: 7.5))),
        pw.SizedBox(height: 2),
        div(),
      ]),
    ));
    return pdf.save();
  }
}
