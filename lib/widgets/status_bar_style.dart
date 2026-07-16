import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the Android/iOS status bar icons readable on top of this screen.
///
/// Screens pushed as their own routes (outside MainShell's tabs) don't
/// inherit MainShell's reactive `AnnotatedRegion` - once an opaque route
/// covers MainShell it is no longer painted, so its annotation stops
/// applying and the route falls back to the app-root baseline in
/// `PrombtApp`, which pins white icons (correct only for the always-dark
/// pre-auth screens). On a light background that made the status bar
/// (clock/battery/Wi-Fi) invisible.
///
/// Wrap the screen's `Scaffold` with this, passing the same dark flag the
/// screen already uses for its own colors. Like MainShell, this is a
/// declarative `AnnotatedRegion` (not an imperative `SystemChrome` call),
/// so Flutter re-asserts it on every relevant frame and it self-heals if
/// the OS resets system UI on resume.
class StatusBarStyle extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const StatusBarStyle({
    super.key,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark background -> light (white) status bar icons, and vice versa.
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child,
    );
  }
}
