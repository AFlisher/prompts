import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared button style presets — the primary filled and secondary outlined
/// conventions that were previously hand-rolled slightly differently at
/// every call site (different radii, paddings, border widths).
class AppButtonStyles {
  static ButtonStyle primary({
    EdgeInsetsGeometry? padding,
    double elevation = 0,
    Color? shadowColor,
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
    Color? backgroundColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppTheme.accentPurple,
      foregroundColor: Colors.white,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      elevation: elevation,
      shadowColor: shadowColor,
    );
  }

  static ButtonStyle secondaryOutlined({EdgeInsetsGeometry? padding}) {
    return OutlinedButton.styleFrom(
      side: const BorderSide(color: AppTheme.accentPurple, width: 1.5),
      foregroundColor: AppTheme.accentPurple,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    );
  }
}
