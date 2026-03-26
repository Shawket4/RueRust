import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final String               pin;
  final int                  maxLength;
  final void Function(String) onDigit;
  final VoidCallback         onBackspace;

  const PinPad({super.key, required this.pin, required this.maxLength,
      required this.onDigit, required this.onBackspace});

  static const _rows = [
    ['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    final keySize = MediaQuery.of(context).size.width >= 768 ? 80.0 : 68.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < pin.length ? AppColors.primary : Colors.transparent,
              border: Border.all(
                  color: i < pin.length ? AppColors.primary : AppColors.border,
                  width: 2),
            ),
          ))),
      const SizedBox(height: 28),
      ..._rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              if (k.isEmpty) return SizedBox(width: keySize, height: keySize);
              return _Key(label: k, size: keySize,
                  onTap: () => k == '⌫' ? onBackspace() : onDigit(k));
            }).toList()),
      )),
    ]);
  }
}

class _Key extends StatefulWidget {
  final String label; final double size; final VoidCallback onTap;
  const _Key({required this.label, required this.size, required this.onTap});
  @override State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  @override void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => _ctrl.forward(),
    onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: ()  => _ctrl.reverse(),
    child: ScaleTransition(scale: _scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 4, offset: const Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(widget.label, style: cairo(
            fontSize: widget.label == '⌫' ? 18 : 22,
            fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
    ),
  );
}
