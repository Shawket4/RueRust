import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final String              pin;
  final int                 maxLength;
  final void Function(String) onDigit;
  final VoidCallback        onBackspace;

  const PinPad({
    super.key,
    required this.pin,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
  });

  static const _rows = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['', '0','⌫'],
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(maxLength, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < pin.length ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: i < pin.length ? AppColors.primary : AppColors.border,
              width: 2,
            ),
          ),
        )),
      ),
      const SizedBox(height: 28),
      ..._rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 72, height: 68);
            return _Key(label: k,
                onTap: () => k == '⌫' ? onBackspace() : onDigit(k));
          }).toList(),
        ),
      )),
    ],
  );
}

class _Key extends StatelessWidget {
  final String      label;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 68, height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4, offset: const Offset(0, 2),
        )],
      ),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.inter(
        fontSize: label == '⌫' ? 18 : 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      )),
    ),
  );
}
