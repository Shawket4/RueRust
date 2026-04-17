import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum SyncBannerVariant { offline, syncing, stuck }

class SyncStatusBanner extends StatelessWidget {
  final SyncBannerVariant variant;
  final String text;

  const SyncStatusBanner({super.key, required this.variant, required this.text});

  @override
  Widget build(BuildContext context) {
    final (color, textColor, icon, animate) = switch (variant) {
      SyncBannerVariant.offline => (const Color(0xFFFFF3CD), const Color(0xFF856404), Icons.wifi_off_rounded, false),
      SyncBannerVariant.syncing => (const Color(0xFFCFE2FF), const Color(0xFF084298), Icons.sync_rounded, true),
      SyncBannerVariant.stuck   => (const Color(0xFFFFF3CD), AppColors.warning, Icons.warning_amber_rounded, false),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(children: [
        animate
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
            : Icon(icon, size: 16, color: textColor),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: cairo(fontSize: 12, fontWeight: FontWeight.w600, color: textColor))),
      ]),
    );
  }
}
