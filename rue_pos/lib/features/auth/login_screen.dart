import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pin_pad.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
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
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
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
    final err =
        await ref.read(authProvider.notifier).login(name: name, pin: _pin);
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
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
    final expiry = ref.watch(authProvider.select((s) => s.sessionExpiry));
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isTablet
          ? _TabletLayout(form: _buildForm(expiry))
          : _buildForm(expiry),
    );
  }

  Widget _buildForm(SessionExpiry expiry) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Logo ────────────────────────────────────────────────────────
            Image.asset('assets/TheRue.png', height: 48),
            const SizedBox(height: 8),
            Text(
              'Point of Sale',
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1.6),
            ),
            const SizedBox(height: 32),

            // ── Session banners ──────────────────────────────────────────────
            if (expiry == SessionExpiry.expired)
              _InfoBanner(
                  icon: Icons.lock_clock_outlined,
                  text: 'Your session expired — please sign in again.',
                  color: AppColors.warning),

            if (expiry == SessionExpiry.blockedByOtherShift && _error != null)
              _InfoBanner(
                  icon: Icons.block_rounded,
                  text: _error!,
                  color: AppColors.danger,
                  bold: true),

            // ── Divider ──────────────────────────────────────────────────────
            Row(children: [
              const Expanded(child: Divider(color: AppColors.borderLight)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('Sign in',
                    style: cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.6)),
              ),
              const Expanded(child: Divider(color: AppColors.borderLight)),
            ]),
            const SizedBox(height: 24),

            // ── Name field ───────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0), child: child),
              child: TextField(
                controller: _nameCtrl,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _error = null),
                style: cairo(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── PIN pad ──────────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0), child: child),
              child: PinPad(
                  pin: _pin,
                  maxLength: _max,
                  onDigit: _digit,
                  onBackspace: _back),
            ),

            // ── Error ────────────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: (_error != null &&
                      expiry != SessionExpiry.blockedByOtherShift)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                              color: AppColors.danger.withOpacity(0.18)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 15, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(_error!,
                                  style: cairo(
                                      fontSize: 13, color: AppColors.danger))),
                        ]),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            if (_loading) ...[
              const SizedBox(height: 28),
              const CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Info Banner ────────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: cairo(
                      fontSize: 13,
                      color: color,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      height: 1.4))),
        ]),
      );
}

// ── Tablet split layout ────────────────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  final Widget form;
  const _TabletLayout({required this.form});

  @override
  Widget build(BuildContext context) => Row(children: [
        // Left panel — brand
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
                padding: const EdgeInsets.all(52),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/TheRue.png',
                        height: 56,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn),
                    const SizedBox(height: 40),
                    Text('Welcome\nback.',
                        style: cairo(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Text('Sign in to start your shift\nand manage orders.',
                        style: cairo(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.72),
                            height: 1.65)),
                    const SizedBox(height: 48),
                    // Decorative dots
                    Row(children: [
                      _Dot(AppColors.surface.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      _Dot(AppColors.surface.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      _Dot(AppColors.surface.withOpacity(0.15)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right panel — form
        Expanded(
          flex: 4,
          child: Container(color: Colors.white, child: form),
        ),
      ]);
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
