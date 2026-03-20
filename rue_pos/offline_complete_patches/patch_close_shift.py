#!/usr/bin/env python3
"""
Patches close_shift_screen.dart:
  Disables the Close Shift button with a message when offline.
"""
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

changed = []

imp = "import '../../core/services/offline_sync_service.dart';"
if imp not in src:
    src = src.replace(
        "import '../../shared/widgets/label_value.dart';",
        "import '../../shared/widgets/label_value.dart';\n" + imp,
    )
    changed.append('import')

old_btn = '''          AppButton(
            label: 'Close Shift',
            variant: BtnVariant.danger,
            loading: state._submitting,
            width: double.infinity,
            icon: Icons.lock_outline_rounded,
            onTap: state._close,
          ),'''

new_btn = '''          Builder(builder: (bCtx) {
            final offline = !bCtx.watch<OfflineSyncService>().isOnline;
            return Column(children: [
              if (offline)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFD700)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 14, color: Color(0xFF856404)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Internet required to close a shift.',
                        style: cairo(fontSize: 12,
                            color: const Color(0xFF856404)),
                      )),
                    ]),
                  ),
                ),
              AppButton(
                label: 'Close Shift',
                variant: BtnVariant.danger,
                loading: state._submitting,
                width: double.infinity,
                icon: Icons.lock_outline_rounded,
                onTap: offline ? null : state._close,
              ),
            ]);
          }),'''

if old_btn in src:
    src = src.replace(old_btn, new_btn)
    changed.append('close-offline-guard')

with open(path, 'w') as f:
    f.write(src)
print(f"  patched: {', '.join(changed) if changed else 'nothing matched'}")

