import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, SharedPreferences-backed state for the post-generation feedback
/// prompt: whether the user still wants to be asked at all ([askEnabled],
/// toggled from Settings > Feedback), and how many successful generations
/// have happened so far (for the smart-trigger cadence below).
///
/// Mirrors [HapticService]'s static-class-with-SharedPreferences shape:
/// [load] is called once in `main()` before `runApp`, so both fields are
/// synchronously readable afterwards without awaiting anything.
class FeedbackPromptService {
  static const String _askEnabledKey = 'feedbackPromptAskEnabled';
  static const String _generationCountKey = 'feedbackPromptGenerationCount';

  /// Defaults to on for a fresh install, before [load] has run.
  static bool askEnabled = true;
  static int generationCount = 0;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      askEnabled = prefs.getBool(_askEnabledKey) ?? true;
      generationCount = prefs.getInt(_generationCountKey) ?? 0;
    } catch (e) {
      debugPrint('[FeedbackPromptService] Error loading feedback prompt preferences: $e');
    }
  }

  /// Updates the in-memory flag immediately and persists it. Re-enabling
  /// resumes prompting on the same cadence - [generationCount] is never
  /// reset by this.
  static Future<void> setAskEnabled(bool value) async {
    askEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askEnabledKey, value);
    } catch (e) {
      debugPrint('[FeedbackPromptService] Error saving ask-enabled preference: $e');
    }
  }

  /// Smart-trigger cadence: never after generation #1 or #2, yes on #3, then
  /// every 10th generation after that (#13, #23, #33, ...). Exposed
  /// separately from [recordGenerationAndShouldPrompt] so the cadence math
  /// is unit-testable without touching SharedPreferences.
  @visibleForTesting
  static bool shouldPromptForGenerationNumber(int count) {
    if (count < 3) return false;
    if (count == 3) return true;
    return (count - 3) % 10 == 0;
  }

  /// Call once per successful generation. Increments and persists the
  /// local counter regardless of [askEnabled], so the cadence stays correct
  /// if the user re-enables prompting later - then reports whether this
  /// particular generation should actually show the sheet.
  static Future<bool> recordGenerationAndShouldPrompt() async {
    generationCount += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_generationCountKey, generationCount);
    } catch (e) {
      debugPrint('[FeedbackPromptService] Error saving generation count: $e');
    }
    return askEnabled && shouldPromptForGenerationNumber(generationCount);
  }
}
