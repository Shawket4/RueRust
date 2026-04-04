import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double radius;
  final bool elevated;

  const CardContainer({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = AppRadius.md,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: elevated ? AppShadows.md : AppShadows.card,
        ),
        child: child,
      );
}
