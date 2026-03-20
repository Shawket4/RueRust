#!/usr/bin/env python3
"""
Patches home_screen.dart:
  - Shows cached banner when shift loaded from cache
  - Disables Open/Close shift buttons with message when offline
"""
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

changed = []

# Add OfflineSyncService import
imp = "import '../../core/services/offline_sync_service.dart';"
if imp not in src:
    src = src.replace(
        "import '../../shared/widgets/card_container.dart';",
        "import '../../shared/widgets/card_container.dart';\n" + imp,
    )
    changed.append('import')

# Add fromCache banner to _OpenShiftView — show "Offline mode" strip
# Insert after the _OpenShiftView build() return Column, right after the first boxShadow block
old_status_row = '''          // Status row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('SHIFT OPEN','''

new_status_row = '''          // Offline cache banner
          Builder(builder: (ctx) {
            final sync = ctx.watch<OfflineSyncService>();
            if (!sync.isOnline) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded, size: 13, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Offline — showing cached data. New orders will sync when connected.',
                    style: cairo(fontSize: 11, color: Colors.white70),
                  )),
                ]),
              );
            }
            return const SizedBox.shrink();
          }),
          // Status row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('SHIFT OPEN','''

if old_status_row in src:
    src = src.replace(old_status_row, new_status_row)
    changed.append('offline-banner')

# Disable Close Shift button when offline — wrap _confirmClose call
old_close_btn = '''            Expanded(
                child: _CardBtn(
              label: 'Close',
              icon: Icons.lock_outline_rounded,
              onTap: () => _confirmClose(context),
              danger: true,
              isTablet: isTablet,
            )),'''

new_close_btn = '''            Builder(builder: (bCtx) {
              final offline = !bCtx.watch<OfflineSyncService>().isOnline;
              return Expanded(
                child: _CardBtn(
                  label: 'Close',
                  icon: Icons.lock_outline_rounded,
                  onTap: offline
                      ? () => ScaffoldMessenger.of(bCtx).showSnackBar(
                          const SnackBar(
                            content: Text('Internet required to close shift'),
                            backgroundColor: Color(0xFF856404),
                          ))
                      : () => _confirmClose(bCtx),
                  danger: true,
                  isTablet: isTablet,
                ),
              );
            }),'''

if old_close_btn in src:
    src = src.replace(old_close_btn, new_close_btn)
    changed.append('close-offline-guard')

with open(path, 'w') as f:
    f.write(src)

print(f"  patched: {', '.join(changed) if changed else 'nothing matched'}")

