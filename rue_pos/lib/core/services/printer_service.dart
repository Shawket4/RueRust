// ESC/POS receipt printer over TCP port 9100.
// Works on Android, iOS, macOS, Windows, Linux.
// Web is excluded — dart:io is not available there.
// ignore: avoid_web_libraries_in_flutter
import 'dart:io';
import 'dart:typed_data';
import '../models/order.dart';
import '../utils/formatting.dart';

class PrinterService {
  static const _timeout = Duration(seconds: 5);

  // ── ESC/POS byte constants ────────────────────────────────────────────────
  static const _esc = 0x1B;
  static const _gs = 0x1D;
  static const _lf = 0x0A;
  static const _cut = [0x1D, 0x56, 0x41, 0x05]; // partial cut

  // Initialize printer
  static List<int> get _init => [_esc, 0x40];

  // Align: 0=left, 1=center, 2=right
  static List<int> _align(int a) => [_esc, 0x61, a];

  // Bold on/off
  static List<int> _bold(bool on) => [_esc, 0x45, on ? 1 : 0];

  // Double width+height on/off
  static List<int> _doubleSize(bool on) => [_gs, 0x21, on ? 0x11 : 0x00];

  // Text to bytes (Latin-1 safe, replaces non-printable chars)
  static List<int> _text(String s) {
    final out = <int>[];
    for (final c in s.runes) {
      out.add(c < 256 ? c : 0x3F); // '?'
    }
    return out;
  }

  static List<int> _line(String s) => [..._text(s), _lf];

  static List<int> _divider([int width = 42]) => _line('-' * width);

  // Two-column row: left text + right text, padded to width
  static List<int> _row(String left, String right, {int width = 42}) {
    final space = width - left.length - right.length;
    final padded = space > 0
        ? left + (' ' * space) + right
        : '${left.substring(0, width - right.length - 1)}… $right';
    return _line(padded);
  }

  // ── Build receipt bytes ───────────────────────────────────────────────────
  static Uint8List buildReceipt({
    required Order order,
    required String branchName,
  }) {
    final buf = <int>[];

    buf.addAll(_init);

    // Header
    buf.addAll(_align(1)); // center
    buf.addAll(_doubleSize(true));
    buf.addAll(_bold(true));
    buf.addAll(_line('THE RUE COFFEE'));
    buf.addAll(_doubleSize(false));
    buf.addAll(_bold(false));
    buf.addAll(_line(branchName));
    buf.addAll(_line(''));
    buf.addAll(_divider());

    // Order info
    buf.addAll(_align(0)); // left
    buf.addAll(_bold(true));
    buf.addAll(_row(
      'Order #${order.orderNumber}',
      timeShort(order.createdAt),
    ));
    buf.addAll(_bold(false));
    buf.addAll(_divider());

    // Items
    for (final item in order.items) {
      final sizePart = item.sizeLabel != null ? ' (${item.sizeLabel})' : '';
      final label = '${item.quantity}x ${item.itemName}$sizePart';
      final price = egp(item.lineTotal);
      buf.addAll(_row(label, price));

      for (final addon in item.addons) {
        final aLabel = '  + ${addon.addonName}';
        final aPrice = addon.unitPrice > 0 ? '+${egp(addon.unitPrice)}' : '';
        if (aPrice.isNotEmpty)
          buf.addAll(_row(aLabel, aPrice));
        else
          buf.addAll(_line(aLabel));
      }
    }

    buf.addAll(_divider());

    // Totals
    buf.addAll(_row('Subtotal', egp(order.subtotal)));
    if (order.discountAmount > 0) {
      buf.addAll(_row('Discount', '- ${egp(order.discountAmount)}'));
    }
    if (order.taxAmount > 0) {
      buf.addAll(_row('Tax', egp(order.taxAmount)));
    }
    buf.addAll(_bold(true));
    buf.addAll(_row('TOTAL', egp(order.totalAmount)));
    buf.addAll(_bold(false));
    buf.addAll(_divider());

    // Footer info
    final payLabel = order.paymentMethod[0].toUpperCase() +
        order.paymentMethod.substring(1).replaceAll('_', ' ');
    buf.addAll(_line('Payment : $payLabel'));
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buf.addAll(_line('Customer: ${order.customerName}'));
    }
    if (order.tellerName.isNotEmpty) {
      buf.addAll(_line('Teller  : ${order.tellerName}'));
    }
    buf.addAll(_line(''));
    buf.addAll(_align(1)); // center
    buf.addAll(_line('Thank you for visiting!'));
    buf.addAll(_line(''));
    buf.addAll(_line(''));
    buf.addAll(_line(''));

    // Cut
    buf.addAll(_cut);

    return Uint8List.fromList(buf);
  }

  // ── Send to printer ───────────────────────────────────────────────────────
  /// Returns null on success, or an error message string.
  static Future<String?> print({
    required String ip,
    required int port,
    required Order order,
    required String branchName,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: _timeout);
      final bytes = buildReceipt(order: order, branchName: branchName);
      socket.add(bytes);
      await socket.flush();
      return null; // success
    } on SocketException catch (e) {
      return 'Printer error: ${e.message}';
    } on OSError catch (e) {
      return 'Printer error: ${e.message}';
    } catch (e) {
      return 'Printer error: $e';
    } finally {
      await socket?.close();
    }
  }
}
