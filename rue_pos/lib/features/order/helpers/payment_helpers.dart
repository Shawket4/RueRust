import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── Payment method colour ────────────────────────────────────────────────────
Color methodColor(String m) => switch (m) {
      'cash' => AppColors.success,
      'card' => const Color(0xFF7C3AED),
      'talabat_online' => const Color(0xFFFF6B00),
      'talabat_cash' => const Color(0xFFFF6B00),
      _ => AppColors.primary,
    };

String methodLabel(String m) => switch (m) {
      'cash' => 'Cash',
      'card' => 'Card',
      'talabat_online' => 'Talabat Online',
      'talabat_cash' => 'Talabat Cash',
      'digital_wallet' => 'Digital Wallet',
      'mixed' => 'Mixed',
      _ => m[0].toUpperCase() + m.substring(1).replaceAll('_', ' '),
    };

bool isCashMethod(String m) => m == 'cash' || m == 'talabat_cash';

// ── Payment method model ─────────────────────────────────────────────────────
class PaymentMethod {
  final String value, label;
  final IconData icon;
  final Color color;
  const PaymentMethod(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
}

const kPaymentMethods = [
  PaymentMethod(
      value: 'cash',
      label: 'Cash',
      icon: Icons.payments_outlined,
      color: AppColors.primary),
  PaymentMethod(
      value: 'card',
      label: 'Card',
      icon: Icons.credit_card_rounded,
      color: AppColors.primary),
  PaymentMethod(
      value: 'talabat_online',
      label: 'Talabat Online',
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFFFF6B00)),
  PaymentMethod(
      value: 'talabat_cash',
      label: 'Talabat Cash',
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFFFF6B00)),
];

// ── Addon-type accent colours ────────────────────────────────────────────────
/// Returns a unique accent colour per addon_type so each type card is visually
/// distinct. Falls back to primary for unknown types.
Color addonTypeColor(String addonType) => switch (addonType) {
      'milk_type' => const Color(0xFFF5A623),  // warm amber / cream
      'coffee_type' => const Color(0xFF795548), // brown
      'extra' => AppColors.primary,             // blue
      'syrup' => const Color(0xFF9C27B0),       // purple
      'topping' => const Color(0xFFE91E63),     // pink
      'drizzle' => const Color(0xFF00BCD4),     // teal
      _ => AppColors.primary,
    };

/// Human-readable label for an addon_type string.
String addonTypeLabel(String addonType) => addonType
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');
