import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's dark/light mode choice so it survives app restarts.
///
/// [isDarkMode] is populated synchronously (via [load]) before `runApp` is
/// called, so the first frame MainShell ever builds already reflects the
/// saved preference - no dark-to-light (or vice versa) flash on startup.
///
/// Deliberately does NOT also imperatively set the Android/iOS status bar
/// style here (an earlier version tried `SystemChrome.setSystemUIOverlayStyle`
/// from [load], before `runApp`/the first frame exists) - that call was
/// found to be unreliable on cold start (confirmed on-device: worked once
/// the app was running and the user toggled mid-session, silently failed on
/// a fresh launch already saved in Light Mode). Status bar styling is owned
/// declaratively instead, via `AnnotatedRegion<SystemUiOverlayStyle>` in
/// [MainShell] (reactive to [isDarkMode] on every toggle) and `PrombtApp`
/// (a dark-icon baseline for the pre-auth screens) - Flutter re-asserts an
/// AnnotatedRegion's value on every relevant frame, which is immune to the
/// startup-timing race and self-heals if the OS resets system UI on resume.
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
