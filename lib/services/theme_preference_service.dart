import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's dark/light mode choice so it survives app restarts.
///
/// [isDarkMode] is populated synchronously (via [load]) before `runApp` is
/// called, so the first frame MainShell ever builds already reflects the
/// saved preference - no dark-to-light (or vice versa) flash on startup.
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
  }

  static Future<void> setIsDarkMode(bool value) async {
    isDarkMode = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      debugPrint('[ThemePreferenceService] Error saving theme preference: $e');
    }
  }
}
