import 'package:flutter/widgets.dart';

/// Single source of truth for the floating glass bottom nav bar's sizing,
/// shared between the bar itself and anything that needs to reserve space
/// so its content never ends up hidden behind it.
class FloatingNavBarMetrics {
  static const double expandedHeight = 72.0;
  static const double collapsedHeight = 56.0;
  static const double floatingMargin = 8.0;

  /// Total space to reserve below scrollable content so its last item can
  /// always scroll fully clear of the bar: the device's own bottom
  /// safe-area inset, plus the bar's (expanded, worst-case) height, plus
  /// its floating margin off the screen edge.
  static double bottomClearance(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + expandedHeight + floatingMargin;
  }
}
