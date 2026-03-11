import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../utils/formatting.dart';
import '../../widgets/rue_button.dart';

class OpenShiftScreen extends StatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preFill = context.read<ShiftProvider>().preFill;
      if (preFill != null) {
        _controller.text = (preFill.suggestedOpeningCash / 100).toStringAsFixed(0);
      }
    });
  }

  Future<void> _open() async {
    final raw = double.tryParse(_controller.text);
    if (raw == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final piastres = (raw * 100).round();
    setState(() { _loading = true; _error = null; });

    final user = context.read<AuthProvider>().user!;

    final branchId = user.branchId;
    if (branchId == null) {
      setState(() { _error = 'No branch assigned to your account'; _loading = false; });
      return;
    }

    await context.read<ShiftProvider>().openShift(branchId, piastres);
    if (mounted) {
      final err = context.read<ShiftProvider>().error;
      if (err != null) {
        setState(() { _error = err; _loading = false; });
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Open Shift',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
      ),
      body: Center(
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Opening Cash',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827)),
                decoration: InputDecoration(
                  prefixText: 'EGP ',
                  prefixStyle: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF1a56db), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFFDC2626))),
              ],
              const SizedBox(height: 24),
              RueButton(
                label: 'Open Shift',
                loading: _loading,
                onTap: _open,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
