import 'package:flutter/material.dart';

class ResponsiveSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    // Reverted back to standard bottom sheets for all devices.
    // The Align and ConstrainedBox prevent the sheet from stretching 
    // edge-to-edge on large tablet screens.
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: builder(ctx),
        ),
      ),
    );
  }
}