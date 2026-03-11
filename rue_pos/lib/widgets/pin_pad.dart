import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinPad extends StatelessWidget {
  final String pin;
  final int maxLength;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  const PinPad({
    super.key,
    required this.pin,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (i) {
            final filled = i < pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? const Color(0xFF1a56db)
                    : const Color(0xFFE5E7EB),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        // Numpad grid
        _buildGrid(),
      ],
    );
  }

  Widget _buildGrid() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 80);
            return _PinKey(
              label: key,
              onTap: () {
                if (key == '⌫') {
                  onBackspace();
                } else {
                  onDigit(key);
                }
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _PinKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PinKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: label == '⌫' ? 20 : 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}
