import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's dark/light mode choice so it survives app restarts.
///
/// [isDarkMode] is populated synchronously (via [load]) before `runApp` is
/// called, so the first frame MainShell ever builds already reflects the
/// saved preference - no dark-to-light (or vice versa) flash on startup.
///
/// This is also the single place that owns the Android/iOS status bar icon
/// brightness: the app has no screen-level AppBar (every screen uses its own
/// custom header) and never sets a light/dark `ThemeMode` on MaterialApp
/// (it's hardcoded to `ThemeMode.dark`, with each screen tracking light/dark
/// manually), so nothing was ever telling the OS to switch icon color -
/// they defaulted to light (white) icons everywhere, invisible against the
/// warm light-mode background. Every mutation of [isDarkMode] already
/// funnels through [load] or [setIsDarkMode], so applying the matching
/// status bar style here covers the whole app with no per-screen code.
class ThemePreferenceService {
  static const String _key = 'isDarkMode';

  /// Defaults to dark mode for a fresh install, before [load] has run.
  static bool isDarkMode = true;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode = prefs.getBool(_key) ?? true;
    } catch (e) {
      debugPrint('[ThemePreferenceService] Error loading theme preference: $e');
    }
    _applyStatusBarStyle();
  }

  static Future<void> setIsDarkMode(bool value) async {
    isDarkMode = value;
    _applyStatusBarStyle();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      debugPrint('[ThemePreferenceService] Error saving theme preference: $e');
    }
  }

  /// Dark mode's near-black background needs light (white) icons; light
  /// mode's warm #FFFAF3 background needs dark (black) icons instead - the
  /// inverse of what every screen was silently getting by default.
  static void _applyStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }
}
