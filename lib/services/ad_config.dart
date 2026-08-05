import 'package:flutter/foundation.dart';

/// Which platform's ad configuration to resolve. Passed explicitly rather than
/// read from `Platform` so this is testable without a device.
enum AdPlatform { android, ios }

/// Sprint 2 / B-4 — AdMob unit resolution, with one hard rule:
/// **a Google test ad unit can never be used in a release build.**
///
/// ─── What was wrong ─────────────────────────────────────────────────────────
///
/// Android correctly switched on `kDebugMode`. iOS returned Google's public
/// sample rewarded unit (`ca-app-pub-3940256099942544/1712485313`)
/// unconditionally - including in release - and `ios/Runner/Info.plist` still
/// carries Google's sample App ID. An iOS release build therefore served test
/// ads: no revenue, while users still earned credits for watching them. Every
/// reward was pure cost.
///
/// ─── Why this refuses rather than substitutes ───────────────────────────────
///
/// The obvious fix is to put the real iOS ids here. They do not exist in this
/// repository and cannot be derived - they are created in an AdMob account -
/// and inventing them would produce a build that looks configured and silently
/// fails to serve. So when a release build has no production unit for its
/// platform, [rewardedAdUnitId] returns null and [AdService] disables ads
/// entirely: no ad loads, no reward is granted, and no test ad is ever shown.
/// Losing the ad-reward path on an unconfigured iOS build is strictly better
/// than paying out credits for advertising that earns nothing.
///
/// ─── Supplying the ids ──────────────────────────────────────────────────────
///
/// Compile-time, via `--dart-define`, so the value is baked into the binary
/// rather than read from a bundled asset an attacker can edit:
///
/// ```
/// flutter build ipa --release \
///   --dart-define=ADMOB_IOS_REWARDED_UNIT_ID=ca-app-pub-XXXX/YYYY
/// ```
///
/// Android's production unit is already known and committed, so Android needs
/// no define; the same variable exists for it so the value can be rotated
/// without a code change.
abstract class AdConfig {
  /// Every Google-published sample ad unit shares this publisher id. Matching
  /// on the publisher rather than on a list of unit ids means a test unit this
  /// file has never heard of is still caught.
  static const String googleTestPublisherId = 'ca-app-pub-3940256099942544';

  /// Google's sample rewarded units, used only in debug builds.
  static const String _androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

  /// The real Android rewarded unit. Already live and already in this
  /// repository's history, so this is not a fabricated value.
  static const String _androidProdRewardedDefault = 'ca-app-pub-6702560936975523/1997493396';

  static const String _androidProdRewarded = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_UNIT_ID',
    defaultValue: _androidProdRewardedDefault,
  );

  /// Empty by default, deliberately. There is no real iOS unit to default to.
  static const String _iosProdRewarded = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_UNIT_ID',
    defaultValue: '',
  );

  /// True if [unitId] belongs to Google's sample publisher.
  static bool isGoogleTestUnit(String? unitId) =>
      unitId != null && unitId.startsWith(googleTestPublisherId);

  /// The rewarded unit to use, or **null** when ads must be disabled.
  ///
  /// [isRelease] is a parameter rather than a direct `kReleaseMode` read so the
  /// release behaviour can be asserted by a test running in debug - otherwise
  /// the single most important branch here would be the one never exercised.
  static String? rewardedAdUnitId({
    required AdPlatform platform,
    bool isRelease = kReleaseMode,
  }) {
    if (!isRelease) {
      // Debug and profile builds always use test units. Serving a real ad to a
      // developer is how an AdMob account gets suspended for invalid traffic.
      return platform == AdPlatform.android ? _androidTestRewarded : _iosTestRewarded;
    }

    final production =
        platform == AdPlatform.android ? _androidProdRewarded : _iosProdRewarded;

    if (production.isEmpty) return null;

    // The rule, enforced rather than trusted. A production value that is
    // actually a test unit - a bad --dart-define, a copy-paste - disables ads
    // instead of shipping test ads to real users.
    if (isGoogleTestUnit(production)) return null;

    return production;
  }

  /// Why ads are off, for logs and for the release checklist. Null when they
  /// are on.
  static String? disabledReason({
    required AdPlatform platform,
    bool isRelease = kReleaseMode,
  }) {
    if (rewardedAdUnitId(platform: platform, isRelease: isRelease) != null) {
      return null;
    }
    final name = platform == AdPlatform.android ? 'ANDROID' : 'IOS';
    return 'No production AdMob rewarded unit for $name. '
        'Set --dart-define=ADMOB_${name}_REWARDED_UNIT_ID to enable rewarded ads.';
  }
}
