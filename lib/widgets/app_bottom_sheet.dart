import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The rounded-top-with-drag-handle bottom sheet chrome already used (with
/// small inconsistencies) by most of the app's non-store-mimicking sheets.
/// [contentBuilder] only needs to supply the sheet's actual content — this
/// wrapper supplies the background, corner radius, and drag handle.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required bool isDarkMode,
  required WidgetBuilder contentBuilder,
  bool showDragHandle = true,
  EdgeInsetsGeometry? padding,
  bool isScrollControlled = false,
}) {
  final bg = isDarkMode ? AppTheme.darkCard : AppTheme.white;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: padding ??
          EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
          ],
          contentBuilder(ctx),
        ],
      ),
    ),
  );
}
