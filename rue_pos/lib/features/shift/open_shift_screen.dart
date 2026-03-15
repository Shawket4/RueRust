import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';

class OpenShiftScreen extends StatefulWidget {
  const OpenShiftScreen({super.key});
  @override State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _ctrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<ShiftProvider>().preFill?.suggestedOpeningCash ?? 0;
      if (s > 0) _ctrl.text = (s / 100).toStringAsFixed(0);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _open() async {
    final raw = double.tryParse(_ctrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid cash amount');
      return;
    }
    final branchId = context.read<AuthProvider>().user?.branchId;
    if (branchId == null) {
      setState(() => _error = 'No branch assigned to your account');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await context.read<ShiftProvider>()
        .openShift(branchId, (raw * 100).round());
    if (mounted) {
      if (ok) {
        context.go('/home');
      } else {
        setState(() {
          _error   = context.read<ShiftProvider>().error ?? 'Failed to open shift';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go('/home'),
      ),
      title: const Text('Open Shift'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CardContainer(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Opening Cash', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary, letterSpacing: 0.4,
                )),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: GoogleFonts.inter(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'EGP ',
                    prefixStyle: GoogleFonts.inter(
                        fontSize: 20, color: AppColors.textSecondary),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Open Shift',
                  loading: _loading,
                  width: double.infinity,
                  icon: Icons.play_arrow_rounded,
                  onTap: _open,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
