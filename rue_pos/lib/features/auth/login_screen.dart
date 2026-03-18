import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pin_pad.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  String _pin = '';
  bool _loading = false;
  String? _error;
  static const _max = 6;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

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
      _shakeCtrl.forward(from: 0);
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
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isTablet
          ? _TabletLayout(form: _buildForm(context))
          : _buildForm(context),
    );
  }

  /// The shared form content (used on both phone and tablet)
  Widget _buildForm(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo ─────────────────────────────────────────
              Image.asset('assets/TheRue.png', height: 52),
              const SizedBox(height: 10),
              Text(
                'Point of Sale',
                style: cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 36),

              // ── Divider label ────────────────────────────────
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Sign in',
                    style: cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
              ]),
              const SizedBox(height: 24),

              // ── Name field ───────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: TextField(
                  controller: _nameCtrl,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() => _error = null),
                  style: cairo(fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        size: 18, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── PIN pad ──────────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: PinPad(
                  pin: _pin,
                  maxLength: _max,
                  onDigit: _digit,
                  onBackspace: _back,
                ),
              ),

              // ── Error ────────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.danger.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 15, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _error!,
                                style: cairo(
                                    fontSize: 13, color: AppColors.danger),
                              ),
                            ),
                          ]),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              if (_loading) ...[
                const SizedBox(height: 28),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TABLET TWO-COLUMN LAYOUT
// ─────────────────────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  final Widget form;
  const _TabletLayout({required this.form});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/TheRue.png',
                        height: 60,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome back.',
                      style: cairo(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sign in to start your shift\nand manage orders.',
                      style: cairo(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right form panel
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: form,
          ),
        ),
      ],
    );
  }
}
