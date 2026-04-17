import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/shift_api.dart';
import '../../core/api/client.dart';
import '../../core/models/pending_action.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/responsive_sheet.dart';

class CashMovementSheet extends ConsumerStatefulWidget {
  final String shiftId;
  final void Function()? onSuccess;

  const CashMovementSheet({
    super.key,
    required this.shiftId,
    this.onSuccess,
  });

  // Task 3.2: Use ResponsiveSheet
  static Future<void> show(
    BuildContext context, {
    required String shiftId,
    void Function()? onSuccess,
  }) =>
      ResponsiveSheet.show(
        context: context,
        builder: (_) => CashMovementSheet(
          shiftId: shiftId,
          onSuccess: onSuccess,
        ),
      );

  @override
  ConsumerState<CashMovementSheet> createState() => _CashMovementSheetState();
}

class _CashMovementSheetState extends ConsumerState<CashMovementSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  bool   _isIn      = true;   // true = Cash In, false = Cash Out
  bool   _loading   = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = double.tryParse(_amountCtrl.text);
    if (raw == null || raw <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_noteCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Note is required');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final isOnline = ref.read(isOnlineProvider);
    final piastres = (raw * 100).round();
    final signed   = _isIn ? piastres : -piastres;

    try {
      if (isOnline) {
        await ref.read(shiftApiProvider).addCashMovement(
          widget.shiftId,
          signed,
          _noteCtrl.text.trim(),
        );
      } else {
        // Task 2.3: Offline Queueing
        await ref.read(offlineQueueProvider.notifier).enqueueCashMovement(
          PendingCashMovement(
            localId: const Uuid().v4(),
            createdAt: DateTime.now(),
            shiftId: widget.shiftId,
            amount: signed,
            note: _noteCtrl.text.trim(),
          )
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
      }
    } catch (e) {
      setState(() {
        _error   = friendlyError(e); // Task 4.2
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.sheetRadius,
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, mq.viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text('Cash Movement',
              style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (!isOnline)
            Text('Offline — will be queued and applied when connected',
                style: cairo(fontSize: 12, color: AppColors.warning)),
          const SizedBox(height: 18),

          // Direction toggle
          Row(children: [
            Expanded(child: _DirectionBtn(
              label: 'Cash In',
              icon: Icons.add_circle_outline_rounded,
              selected: _isIn,
              color: AppColors.success,
              onTap: () => setState(() => _isIn = true),
            )),
            const SizedBox(width: 10),
            Expanded(child: _DirectionBtn(
              label: 'Cash Out',
              icon: Icons.remove_circle_outline_rounded,
              selected: !_isIn,
              color: AppColors.danger,
              onTap: () => setState(() => _isIn = false),
            )),
          ]),
          const SizedBox(height: 18),

          // Amount
          Text('AMOUNT',
              style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            autofocus: true,
            style: cairo(fontSize: 28, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: 'EGP  ',
              prefixStyle: cairo(fontSize: 18, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              hintText: '0',
              hintStyle: cairo(fontSize: 28, fontWeight: FontWeight.w800,
                  color: AppColors.border),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Note
          Text('NOTE',
              style: cairo(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: cairo(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. Safe drop, float top-up…',
              hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.notes_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: AppColors.danger.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(_error!, style: cairo(fontSize: 13, color: AppColors.danger)),
              ]),
            ),
          ],
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isIn ? AppColors.success : AppColors.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_isIn
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(isOnline ? (_isIn ? 'Record Cash In' : 'Record Cash Out') : 'Queue Offline',
                          style: cairo(fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _DirectionBtn({
    required this.label, required this.icon,
    required this.selected, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? color : AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: selected ? Colors.white : color),
        const SizedBox(width: 8),
        Text(label,
            style: cairo(fontSize: 14, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary)),
      ]),
    ),
  );
}
