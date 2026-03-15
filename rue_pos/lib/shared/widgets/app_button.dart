import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

enum BtnVariant { primary, danger, outline, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final BtnVariant variant;
  final double? width;
  final IconData? icon;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.variant = BtnVariant.primary,
    this.width,
    this.icon,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (variant) {
      BtnVariant.primary => (
          AppColors.primary,
          Colors.white,
          Colors.transparent
        ),
      BtnVariant.danger => (AppColors.danger, Colors.white, Colors.transparent),
      BtnVariant.outline => (
          Colors.transparent,
          AppColors.primary,
          AppColors.primary
        ),
      BtnVariant.ghost => (
          Colors.transparent,
          AppColors.textSecondary,
          Colors.transparent
        ),
    };

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: side),
        ),
        child: InkWell(
          onTap: (loading || onTap == null) ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 17, color: fg),
                      const SizedBox(width: 7),
                    ],
                    Text(label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        )),
                  ]),
          ),
        ),
      ),
    );
  }
}
