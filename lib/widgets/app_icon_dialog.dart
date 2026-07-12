import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "icon badge + message + primary action" dialog shape already used by
/// Paywall's purchase-success dialog and Forgot Password's confirmation.
/// Pass [secondaryLabel] to also render a text-button cancel action
/// alongside the primary one (e.g. a Cancel/Confirm pair).
Future<void> showAppIconDialog(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String message,
  required bool isDarkMode,
  required String primaryLabel,
  required VoidCallback onPrimaryPressed,
  Color? primaryColor,
  String? secondaryLabel,
  VoidCallback? onSecondaryPressed,
  bool barrierDismissible = true,
}) {
  final textColor = isDarkMode ? AppTheme.white : AppTheme.black;

  return showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDarkMode ? AppTheme.darkCard : AppTheme.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mediumGray, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (secondaryLabel != null)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSecondaryPressed?.call();
                    },
                    child: Text(secondaryLabel, style: const TextStyle(color: AppTheme.mediumGray)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onPrimaryPressed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor ?? AppTheme.accentPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onPrimaryPressed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor ?? AppTheme.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
