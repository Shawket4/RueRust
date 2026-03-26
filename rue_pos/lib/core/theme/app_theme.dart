import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary       = Color(0xFF1a56db);
  static const secondary     = Color(0xFF3b28cc);
  static const success       = Color(0xFF059669);
  static const danger        = Color(0xFFDC2626);
  static const warning       = Color(0xFFD97706);
  static const bg            = Color(0xFFF2F3F7);
  static const surface       = Colors.white;
  static const border        = Color(0xFFE5E7EB);
  static const borderLight   = Color(0xFFF3F4F6);
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);
}

TextStyle cairo({
  double fontSize       = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color           = AppColors.textPrimary,
  double? height,
  double letterSpacing  = 0,
  TextDecoration? decoration,
}) => GoogleFonts.cairo(
  fontSize: fontSize, fontWeight: fontWeight, color: color,
  height: height, letterSpacing: letterSpacing, decoration: decoration,
);

class AppTheme {
  static ThemeData get light {
    final base = GoogleFonts.cairoTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.cairo(
            fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger)),
        hintStyle: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 15),
      ),
    );
  }
}
