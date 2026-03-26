import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LabelValue extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool   bold;
  const LabelValue(this.label, this.value,
      {super.key, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: cairo(fontSize: 13, color: AppColors.textSecondary)),
      Text(value,  style: cairo(fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: valueColor ?? AppColors.textPrimary)),
    ]),
  );
}
