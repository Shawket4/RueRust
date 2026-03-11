import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final Color? color;
  final double? width;

  const RueButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.outlined = false,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF1a56db);
    return SizedBox(
      width: width,
      height: 52,
      child: Material(
        color: outlined ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: outlined
                ? BoxDecoration(
                    border: Border.all(color: bg, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: outlined ? bg : Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: outlined ? bg : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
