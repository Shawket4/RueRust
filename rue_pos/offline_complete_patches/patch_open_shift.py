#!/usr/bin/env python3
"""
Patches open_shift_screen.dart:
  Shows disabled state + message when offline (opening shift requires internet).
"""
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

changed = []

imp = "import '../../core/services/offline_sync_service.dart';"
if imp not in src:
    src = src.replace(
        "import 'package:google_fonts/google_fonts.dart';",
        "import 'package:google_fonts/google_fonts.dart';\n" + imp,
    )
    changed.append('import')

# Wrap the AppButton in a Builder that checks connectivity
old_btn = '''                  AppButton(
                    label: 'Open Shift',
                    loading: _loading,
                    width: double.infinity,
                    icon: Icons.play_arrow_rounded,
                    onTap: _open,
                  ),'''

new_btn = '''                  Builder(builder: (bCtx) {
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
                                'Internet required to open a shift.',
                                style: cairo(fontSize: 12,
                                    color: const Color(0xFF856404)),
                              )),
                            ]),
                          ),
                        ),
                      AppButton(
                        label: 'Open Shift',
                        loading: _loading,
                        width: double.infinity,
                        icon: Icons.play_arrow_rounded,
                        onTap: offline ? null : _open,
                      ),
                    ]);
                  }),'''

if old_btn in src:
    src = src.replace(old_btn, new_btn)
    changed.append('open-offline-guard')

with open(path, 'w') as f:
    f.write(src)
print(f"  patched: {', '.join(changed) if changed else 'nothing matched'}")

