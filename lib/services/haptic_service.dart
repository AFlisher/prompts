import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized wrapper around Flutter's [HapticFeedback] API.
///
/// Every haptic call in the app must go through here instead of calling
/// [HapticFeedback] directly - that's what lets [enabled] gate every haptic
/// in the app from a single Settings toggle, and what makes the whole
/// surface fail silently on devices/platforms that don't support haptics
/// (rather than crashing a tap handler over something purely cosmetic).
///
/// [enabled] is populated synchronously (via [load]) before `runApp` is
/// called, mirroring [ThemePreferenceService] - so it's readable
/// synchronously from any tap handler without needing to await anything.
class HapticService {
  static const String _key = 'hapticFeedbackEnabled';

  /// Defaults to on for a fresh install, before [load] has run.
  static bool enabled = true;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_key) ?? true;
    } catch (e) {
      debugPrint('[HapticService] Error loading haptic preference: $e');
    }
  }

  /// Updates the in-memory flag immediately (so subsequent taps this session
  /// reflect the change with no restart needed) and persists it.
  static Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      debugPrint('[HapticService] Error saving haptic preference: $e');
    }
  }

  /// Selecting a category/style, tapping a chip, or a toggle/checkbox field.
  static Future<void> selection() => _fire(HapticFeedback.selectionClick);

  /// Favorite/unfavorite, copy, save, share - small successful actions.
  static Future<void> light() => _fire(HapticFeedback.lightImpact);

  /// Primary confirm actions - press Generate, pull-to-refresh completed,
  /// success dialogs, login/register success.
  static Future<void> medium() => _fire(HapticFeedback.mediumImpact);

  /// Destructive actions and the single "generation finished" moment.
  static Future<void> heavy() => _fire(HapticFeedback.heavyImpact);

  static Future<void> vibrate() => _fire(HapticFeedback.vibrate);

  /// Respects [enabled] and never lets a platform-channel failure (haptics
  /// unsupported on this device, simulator, etc.) propagate into a caller's
  /// tap handler - haptics are cosmetic and must never break an interaction.
  static Future<void> _fire(Future<void> Function() call) async {
    if (!enabled) return;
    try {
      await call();
    } catch (e) {
      debugPrint('[HapticService] Haptic call failed: $e');
    }
  }
}
