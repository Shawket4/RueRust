import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/payment_method.dart';

export '../../../core/models/payment_method.dart';

// ── Payment method colour ────────────────────────────────────────────────────
Color methodColor(String m) => PaymentMethod.fromWire(m).color;
String methodLabel(String m) => PaymentMethod.fromWire(m).label;
bool isCashMethod(String m) => PaymentMethod.fromWire(m).isCash;

// ── Addon-type accent colours ────────────────────────────────────────────────
Color addonTypeColor(String addonType) => switch (addonType) {
      'milk_type' => AppColors.primary,          // Changed from yellow to primary blue
      'coffee_type' => const Color(0xFF795548),  // brown
      'extra' => AppColors.primary,              // blue
      'syrup' => const Color(0xFF9C27B0),        // purple
      'topping' => const Color(0xFFE91E63),      // pink
      'drizzle' => const Color(0xFF00BCD4),      // teal
      _ => AppColors.primary,
    };

String addonTypeLabel(String addonType) => addonType
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');
