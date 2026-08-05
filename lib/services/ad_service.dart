import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Loads and shows AdMob rewarded ads.
///
/// Sprint 2 / B-4: the unit id now comes from [AdConfig], which refuses to
/// return a Google test unit in a release build. When it returns null this
/// service becomes inert - [preload] and [showRewardedAd] no-op - rather than
/// falling back to a test ad. See AdConfig for why disabling beats
/// substituting.
class AdService {
  /// Null on an unsupported platform or when ads must be disabled.
  static String? get _rewardedAdUnitId {
    final AdPlatform platform;
    if (Platform.isAndroid) {
      platform = AdPlatform.android;
    } else if (Platform.isIOS) {
      platform = AdPlatform.ios;
    } else {
      return null;
    }
    return AdConfig.rewardedAdUnitId(platform: platform);
  }

  /// Whether rewarded ads can run at all in this build. The paywall and the
  /// watch-ad button use this to hide a control that cannot work.
  static bool get isAvailable => _rewardedAdUnitId != null;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Preloads a rewarded ad so it's ready to show without a delay later.
  Future<void> preload() async {
    final unitId = _rewardedAdUnitId;
    if (unitId == null) {
      // Logged once per attempt rather than silently: an unconfigured release
      // build losing its ad-reward path should be visible to whoever ships it.
      debugPrint('[AdService] rewarded ads disabled - no production unit configured');
      return;
    }
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;

    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Failed to load rewarded ad: $error');
          _rewardedAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Shows a rewarded ad, loading one first if none is preloaded.
  /// Calls [onUserEarnedReward] only if the user actually watched the ad to
  /// completion. Returns false if no ad could be loaded/shown at all.
  Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
  }) async {
    if (_rewardedAdUnitId == null) return false;

    if (_rewardedAd == null) {
      await preload();
    }

    final ad = _rewardedAd;
    if (ad == null) return false;

    _rewardedAd = null; // An ad instance can only be shown once.

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete(true);

        // Preload the next ad.
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Failed to show rewarded ad: $error');
        ad.dispose();

        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward();
      },
    );

    return completer.future;
  }
}