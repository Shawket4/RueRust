import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CardContainer extends StatelessWidget {
  final Widget              child;
  final EdgeInsetsGeometry? padding;
  final Color?              color;
  final double              radius;

  const CardContainer({
    super.key, required this.child,
    this.padding, this.color, this.radius = 16,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}
