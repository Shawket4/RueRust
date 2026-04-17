import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PaymentMethod {
  cash('cash', 'Cash', Icons.payments_outlined, AppColors.success, true),
  card('card', 'Card', Icons.credit_card_rounded, Color(0xFF7C3AED), false),
  digitalWallet('digital_wallet', 'Digital Wallet', Icons.account_balance_wallet_rounded, Color(0xFF0EA5E9), false),
  mixed('mixed', 'Mixed', Icons.pie_chart_rounded, AppColors.primary, false),
  talabatOnline('talabat_online', 'Talabat Online', Icons.delivery_dining_rounded, Color(0xFFFF6B00), false),
  talabatCash('talabat_cash', 'Talabat Cash', Icons.delivery_dining_rounded, Color(0xFFFF6B00), true);

  final String wireFormat;
  final String label;
  final IconData icon;
  final Color color;
  final bool isCash;

  const PaymentMethod(this.wireFormat, this.label, this.icon, this.color, this.isCash);

  static PaymentMethod fromWire(String val) =>
      values.firstWhere((e) => e.wireFormat == val, orElse: () => PaymentMethod.cash);
}
