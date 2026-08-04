import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SEC-13.4 - best-effort, purely local detection of a rooted device or an
/// emulator, surfaced to the user as a one-time courtesy notice and nothing
/// else.
///
/// ⚠️  THIS SIGNAL IS ATTACKER-CONTROLLED. IT MUST NEVER BE USED FOR A
///     SECURITY DECISION.  ⚠️
///
/// The check runs inside this app's own process, on the user's own device, so
/// anyone able to root that device is also able to make these calls return
/// whatever they like: Magisk DenyList and Zygisk hide root from the calling
/// process outright, and Frida can flip the result in seconds. A `true` here
/// is a weak hint. A `false` is *no information at all* - it does not mean
/// "verified safe", it means "nothing was detected by a check the attacker
/// controls".
///
/// Concretely, nothing in this class may ever:
///   * gate login, image generation, rewarded ads, the wallet, or credits;
///   * be attached to a request header or sent to the backend in any form;
///   * participate in an authentication or authorization branch.
///
/// Server-trusted device integrity is a different control with a fundamentally
/// different mechanism - Play Integrity (SEC-0.1/0.2), whose verdict is signed
/// by Google and verified server-side, where the attacker cannot reach it.
/// When that lands it owns every enforcement decision. This service stays what
/// it is today: a warning for honest users on rooted devices, whose stored
/// credentials genuinely are at greater risk of theft by other apps.
///
/// Follows the static-class + SharedPreferences shape of [HapticService] and
/// [FeedbackPromptService], with one difference: [check] is deliberately *not*
/// awaited in `main()`. It runs after the first frame so it can never extend
/// cold start.
class DeviceIntegrityService {
  static const String _noticeShownKey = 'deviceIntegrityNoticeShown';

  /// Defaults to "nothing detected", which is also the permanent state on
  /// every platform this does not run on. See the class doc: false is not a
  /// safety guarantee.
  ///
  /// Root is the only signal collected, deliberately. Emulator detection was
  /// considered and dropped for two independent reasons:
  ///
  ///  1. Its false-positive profile is materially worse - Chromebooks,
  ///     Waydroid and Windows Subsystem for Android all read as emulators, as
  ///     does the team's own QA fleet - and telling a user they are running an
  ///     emulator carries no safety information they do not already have.
  ///  2. `SafeDevice.isRealDevice` swallows platform exceptions internally and
  ///     returns false on failure, so `!isRealDevice` reports "emulator" for a
  ///     probe that merely broke. A field that conflates "emulator" with
  ///     "the check failed" is worse than no field, especially if some later
  ///     consumer (SEC-18.1 risk scoring) treats it as a real observation.
  ///
  /// `isJailBroken` does not have that inversion problem: it also fails to
  /// false, but false is the safe direction - a broken probe produces no
  /// warning rather than a wrong one.
  static bool isRooted = false;

  static bool _noticeShown = false;

  /// Whether to show the one-time notice.
  static bool get shouldShowNotice => isRooted && !_noticeShown;

  /// Runs the detection. Safe to call more than once; safe to call anywhere.
  ///
  /// Never throws: every failure path leaves the defaults in place and logs.
  /// This is a courtesy notice, so a plugin error must never be louder or more
  /// disruptive than the feature it describes.
  static Future<void> check() async {
    // Web has no such concept and no plugin implementation, and `dart:io` is
    // unavailable there. iOS is deliberately out of scope for SEC-13.4. Any
    // other platform leaves the defaults untouched.
    //
    // Uses `defaultTargetPlatform` rather than `Platform.isAndroid` so this is
    // exercisable under `flutter test` (via debugDefaultTargetPlatformOverride)
    // and needs no `dart:io` import.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _noticeShown = prefs.getBool(_noticeShownKey) ?? false;
    } catch (e) {
      debugPrint('[DeviceIntegrityService] Error reading notice state: $e');
    }

    try {
      isRooted = await SafeDevice.isJailBroken;
    } catch (e) {
      debugPrint('[DeviceIntegrityService] Root check unavailable: $e');
    }
  }

  /// Records that the notice has been shown, so it is shown once per install
  /// rather than on every cold start.
  static Future<void> markNoticeShown() async {
    _noticeShown = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_noticeShownKey, true);
    } catch (e) {
      debugPrint('[DeviceIntegrityService] Error saving notice state: $e');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    isRooted = false;
    _noticeShown = false;
  }
}
