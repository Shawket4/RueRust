import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback? onRetry;
  const ErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.danger.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: cairo(fontSize: 13, color: AppColors.danger))),
      if (onRetry != null)
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: cairo(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
    ]),
  );
}
