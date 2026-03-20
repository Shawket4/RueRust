import 'package:intl/intl.dart';

/// Piastres → "EGP 12.50" or "EGP 12"
String egp(int piastres) {
  final v = piastres / 100;
  return 'EGP ${v == v.truncateToDouble() ? v.toInt() : v.toStringAsFixed(2)}';
}

String egpD(double p) => egp(p.round());
String timeShort(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());
String dateShort(DateTime dt) => DateFormat('MMM d').format(dt.toLocal());
String dateTime(DateTime dt)  => DateFormat('MMM d, hh:mm a').format(dt.toLocal());

/// Title-cases each word.  "oat MILK" → "Oat Milk"
String normaliseName(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');
