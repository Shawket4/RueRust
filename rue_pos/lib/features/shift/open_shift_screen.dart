import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/card_container.dart';

class OpenShiftScreen extends ConsumerStatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  ConsumerState<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends ConsumerState<OpenShiftScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(shiftProvider).suggestedOpeningCash;
      if (s > 0) _ctrl.text = (s / 100).toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final raw = double.tryParse(_ctrl.text);
    if (raw == null || raw < 0) {
      setState(() => _error = 'Enter a valid cash amount');
      return;
    }
    final branchId = ref.read(authProvider).user?.branchId;
    if (branchId == null) {
      setState(() => _error = 'No branch assigned to your account');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await ref
        .read(shiftProvider.notifier)
        .openShift(branchId, (raw * 100).round());

    if (mounted) {
      if (ok) {
        context.go('/home');
      } else {
        setState(() {
          _error = ref.read(shiftProvider).error ?? 'Failed to open shift';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final isOnline = ref.watch(isOnlineProvider);
    final suggested =
        ref.watch(shiftProvider.select((s) => s.suggestedOpeningCash));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/home')),
        title: const Text('Open Shift'),
        elevation: 0,
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 500 : 480),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 32 : 20),
              child: CardContainer(
                elevated: true,
                padding: EdgeInsets.all(isTablet ? 36 : 28),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.09),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm)),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: AppColors.primary, size: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Open New Shift',
                                    style: cairo(
                                        fontSize: isTablet ? 18 : 16,
                                        fontWeight: FontWeight.w800)),
                                Text('Enter the opening cash amount',
                                    style: cairo(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ]),
                        ),
                      ]),
  
                      const SizedBox(height: 28),
  
                      if (suggested > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(
                                    color: AppColors.primary.withOpacity(0.14))),
                            child: Row(children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 15, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text('Suggested from last close: ${egp(suggested)}',
                                  style: cairo(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
  
                      Text('OPENING CASH',
                          style: cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 10),
  
                      TextField(
                        controller: _ctrl,
                        autofocus: true,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        style: cairo(
                            fontSize: isTablet ? 34 : 30,
                            fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          prefixText: 'EGP  ',
                          prefixStyle: cairo(
                              fontSize: isTablet ? 22 : 19,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                          hintText: '0',
                          hintStyle: cairo(
                              fontSize: isTablet ? 34 : 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.border),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
  
                      const Divider(color: AppColors.borderLight, height: 24),
                      const SizedBox(height: 4),
  
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _error != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(children: [
                                  const Icon(Icons.error_outline_rounded,
                                      size: 14, color: AppColors.danger),
                                  const SizedBox(width: 6),
                                  Flexible(
                                      child: Text(_error!,
                                          style: cairo(
                                              fontSize: 13,
                                              color: AppColors.danger))),
                                ]))
                            : const SizedBox.shrink(),
                      ),
  
                      // Task 2.1: Removed the !isOnline gate on the onTap for offline-open to work seamlessly.
                      AppButton(
                        label: 'Open Shift',
                        loading: _loading,
                        width: double.infinity,
                        icon: Icons.play_arrow_rounded,
                        onTap: _loading ? null : _open,
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
