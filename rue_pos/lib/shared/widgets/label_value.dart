import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool   bold;

  const LabelValue(this.label, this.value,
      {super.key, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textSecondary,
        )),
        Text(value, style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: valueColor ?? AppColors.textPrimary,
        )),
      ],
    ),
  );
}
