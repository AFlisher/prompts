// Sprint 2 / B-4 — AdMob unit resolution.
//
// The single rule worth a test file: a Google test ad unit can never be used
// in a release build. Before this sprint an iOS release served Google's public
// sample unit, so every rewarded ad earned nothing while still granting the
// user a credit.
//
// `isRelease` is a parameter precisely so this can be asserted from a debug
// test run - otherwise the one branch that matters would be the only one never
// exercised.

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/services/ad_config.dart';

void main() {
  group('debug builds', () {
    test('use Google test units on both platforms', () {
      final android = AdConfig.rewardedAdUnitId(
        platform: AdPlatform.android,
        isRelease: false,
      );
      final ios = AdConfig.rewardedAdUnitId(
        platform: AdPlatform.ios,
        isRelease: false,
      );

      expect(AdConfig.isGoogleTestUnit(android), isTrue);
      expect(AdConfig.isGoogleTestUnit(ios), isTrue);
    });

    test('never return null - ads always work in development', () {
      expect(
        AdConfig.rewardedAdUnitId(platform: AdPlatform.android, isRelease: false),
        isNotNull,
      );
      expect(
        AdConfig.rewardedAdUnitId(platform: AdPlatform.ios, isRelease: false),
        isNotNull,
      );
    });
  });

  group('release builds', () {
    test('Android uses a real production unit, not a test one', () {
      final unit = AdConfig.rewardedAdUnitId(
        platform: AdPlatform.android,
        isRelease: true,
      );

      expect(unit, isNotNull);
      expect(AdConfig.isGoogleTestUnit(unit), isFalse,
          reason: 'a release build must never serve a Google sample ad unit');
    });

    test('iOS is DISABLED rather than falling back to a test unit', () {
      // No ADMOB_IOS_REWARDED_UNIT_ID is defined in this repository, because
      // the real id does not exist here. The correct behaviour is to disable
      // ads, not to substitute the sample unit - which is exactly the defect
      // this sprint fixed.
      final unit = AdConfig.rewardedAdUnitId(
        platform: AdPlatform.ios,
        isRelease: true,
      );

      expect(unit, isNull);
    });

    test('the iOS disabled reason names the variable that would fix it', () {
      final reason = AdConfig.disabledReason(
        platform: AdPlatform.ios,
        isRelease: true,
      );

      expect(reason, isNotNull);
      expect(reason, contains('ADMOB_IOS_REWARDED_UNIT_ID'));
    });

    test('Android reports no disabled reason', () {
      expect(
        AdConfig.disabledReason(platform: AdPlatform.android, isRelease: true),
        isNull,
      );
    });
  });

  group('the test-unit guard', () {
    test('recognises Google sample units by publisher id', () {
      // Matching the publisher rather than a fixed list means a sample unit
      // this code has never seen is still caught.
      expect(AdConfig.isGoogleTestUnit('ca-app-pub-3940256099942544/5224354917'), isTrue);
      expect(AdConfig.isGoogleTestUnit('ca-app-pub-3940256099942544/1712485313'), isTrue);
      expect(AdConfig.isGoogleTestUnit('ca-app-pub-3940256099942544/0000000000'), isTrue);
    });

    test('does not flag a real publisher', () {
      expect(AdConfig.isGoogleTestUnit('ca-app-pub-6702560936975523/1997493396'), isFalse);
    });

    test('handles null and empty safely', () {
      expect(AdConfig.isGoogleTestUnit(null), isFalse);
      expect(AdConfig.isGoogleTestUnit(''), isFalse);
    });
  });

  group('no test unit escapes into release, whatever the platform', () {
    test('every release-mode unit is either null or non-test', () {
      for (final platform in AdPlatform.values) {
        final unit = AdConfig.rewardedAdUnitId(platform: platform, isRelease: true);
        if (unit != null) {
          expect(AdConfig.isGoogleTestUnit(unit), isFalse,
              reason: '$platform leaked a Google test unit into a release build');
        }
      }
    });
  });
}
