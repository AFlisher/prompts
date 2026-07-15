import 'package:flutter/foundation.dart';
import '../services/ad_service.dart';
import '../services/wallet_service.dart';

class CreditManager extends ChangeNotifier {
  // Not a cached or real value - just the starting point before the first
  // fetchWallet() resolves. Callers that display credits before
  // [isInitialized] is true should show a loading placeholder instead of
  // this number, since it isn't the user's actual balance yet.
  int _balance = 0;
  int _generatedImages = 0;
  int _adsProgress = 0;
  bool _dailyLimitReached = false;

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isWatchingAd = false;
  String? _error;

  final WalletService _walletService = WalletService();
  final AdService _adService = AdService();

  // Public Getters
  int get credits => _balance; // Maps legacy local credits to backend balance
  int get balance => _balance;
  int get generatedImages => _generatedImages;
  int get adsProgress => _adsProgress;
  bool get dailyLimitReached => _dailyLimitReached;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isWatchingAd => _isWatchingAd;
  String? get error => _error;

  /// Fetch initial wallet configuration from backend API
  Future<void> init() async {
    if (_isInitialized) return;
    await fetchWallet();
    _isInitialized = true;
    _adService.preload();
  }

  /// Refreshes wallet status from backend
  Future<void> fetchWallet() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final wallet = await _walletService.getWallet();
      _balance = wallet.balance;
      _generatedImages = wallet.generatedImages;
      _adsProgress = wallet.adsProgress;
      _dailyLimitReached = wallet.dailyLimitReached;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("[CreditManager] Error fetching wallet info: $e");
      _error = 'Failed to load wallet stats: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Shows a rewarded ad and, if the user watches it to completion, reports
  /// it to the backend. Returns true if a credit/progress was actually
  /// granted, false if the ad wasn't watched or couldn't be shown.
  Future<bool> watchAdForCredit() async {
    if (_isWatchingAd || _dailyLimitReached) return false;

    _isWatchingAd = true;
    notifyListeners();

    try {
      final watched = await _adService.showRewardedAd(onUserEarnedReward: () {});
      if (!watched) return false;

      final result = await _walletService.rewardAd();
      if (result.balance != null) _balance = result.balance!;
      if (result.adsProgress != null) _adsProgress = result.adsProgress!;
      _dailyLimitReached = result.dailyLimitReached;
      return result.rewarded;
    } catch (e) {
      debugPrint("[CreditManager] Error watching rewarded ad: $e");
      return false;
    } finally {
      _isWatchingAd = false;
      notifyListeners();
    }
  }

  bool shouldSaveToFile = true;

  /// Legacy simulation compatibility methods:
  Future<void> addCredits(int amount) async {
    _balance += amount;
    notifyListeners();
  }

  bool useCredit() {
    if (_balance > 0) {
      _balance -= 1;
      _generatedImages += 1; // Increment local count too during simulation
      notifyListeners();
      return true;
    }
    return false;
  }
}
