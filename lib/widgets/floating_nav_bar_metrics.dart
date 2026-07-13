/// Single source of truth for the floating glass bottom nav bar's sizing,
/// shared between the bar itself and anything that needs to reserve space
/// so its content never ends up hidden behind it.
class FloatingNavBarMetrics {
  static const double expandedHeight = 72.0;
  static const double collapsedHeight = 56.0;
  static const double floatingMargin = 8.0;

  /// Extra trailing padding a screen's own scrollable should add after its
  /// last item, so that item can scroll fully clear of the bar's (expanded,
  /// worst-case) footprint. Deliberately excludes the device's safe-area
  /// inset - each screen's own SafeArea already reserves that separately -
  /// so this can be added on top of a scrollable's existing bottom padding
  /// without double-counting it. Appending this as scroll-canvas padding
  /// (rather than inflating the ambient MediaQuery/SafeArea inset) keeps it
  /// scroll-dependent: real content still extends and blurs behind the bar
  /// while scrolling, and this gap only appears once truly scrolled past the
  /// last item - a static MediaQuery-driven inset would instead shrink the
  /// whole viewport permanently, leaving a constant flat area behind the
  /// glass bar that looks like a solid rectangle again.
  static const double scrollClearance = expandedHeight + floatingMargin;
}
