import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads and shows AdMob rewarded ads using the production ad unit ID.
class AdService {
  static String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/5224354917' // Test
          : 'ca-app-pub-6702560936975523/1997493396'; // Production
    }

    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }

    throw UnsupportedError('Rewarded ads are not supported on this platform.');
  }

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Preloads a rewarded ad so it's ready to show without a delay later.
  Future<void> preload() async {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
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