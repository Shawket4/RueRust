import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pin_pad.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  String _pin = '';
  bool _loading = false;
  String? _error;
  static const _max = 6;

  void _digit(String d) {
    if (_loading || _pin.length >= _max) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _max) _submit();
  }

  void _back() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Please enter your name';
        _pin = '';
      });
      return;
    }
    if (_pin.length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(name: name, pin: _pin);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() {
        _error = 'Invalid name or PIN — please try again';
        _pin = '';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo ──────────────────────────────────────
                Image.asset(
                  'assets/TheRue.png',
                  height: 56,
                ),
                const SizedBox(height: 32),

                // ── Divider ───────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Sign in',
                        style: cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        )),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
                ]),
                const SizedBox(height: 28),

                // ── Name field ────────────────────────────────
                TextField(
                  controller: _nameCtrl,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _error = null),
                  style: cairo(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        size: 18, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 28),

                // ── PIN pad ───────────────────────────────────
                PinPad(
                  pin: _pin,
                  maxLength: _max,
                  onDigit: _digit,
                  onBackspace: _back,
                ),

                // ── Error ─────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.danger.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 15, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(_error!,
                              style: cairo(
                                fontSize: 13,
                                color: AppColors.danger,
                              ))),
                    ]),
                  ),
                ],

                if (_loading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
