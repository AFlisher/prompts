import 'package:flutter/foundation.dart';
import '../services/ad_service.dart';
import '../services/wallet_service.dart';
import '../services/network_client.dart';

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
      _error = friendlyNetworkErrorMessage(e);
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

  // ─── Sprint 2 / B-3: the local credit-granting methods are GONE ───────────
  //
  // `addCredits(int)` and `useCredit()` used to live here. They mutated
  // `_balance` directly and were the client half of the simulated paywall:
  // tapping "buy" incremented a number in device memory, showed a success
  // dialog, and then had the credits silently vanish on the next
  // fetchWallet() - which overwrites `_balance` from the server. To a user
  // that is indistinguishable from being charged and robbed.
  //
  // Nothing replaces them by design. There is now exactly ONE way this field
  // can change: a value the SERVER returned. Purchases go through
  // PurchaseService -> POST /api/purchases/verify, ad rewards through
  // walletService.rewardAd(), and both land in [applyServerBalance] below.
  //
  // If you are here because you want to optimistically bump the balance for a
  // snappier UI: don't. The whole class of bug this sprint removed was a local
  // number that disagreed with the server's.

  /// Applies a balance the SERVER reported. The only writer of [_balance]
  /// besides [fetchWallet] and [clear].
  ///
  /// Takes the authoritative value rather than a delta on purpose - a delta
  /// applied twice (a retry, a rebuilt widget) silently doubles, whereas
  /// setting an absolute value the server just told us is idempotent.
  void applyServerBalance(int balance) {
    if (balance < 0) return;
    _balance = balance;
    notifyListeners();
  }

  /// Wipes this account's wallet state on sign-out. Resets [isInitialized]
  /// to false (not just the numbers) so the *next* signed-in account's
  /// [init] actually re-fetches instead of short-circuiting on the previous
  /// account's already-initialized flag - without this, the next account
  /// would keep seeing this account's balance/generatedImages until the app
  /// was fully restarted.
  void clear() {
    _balance = 0;
    _generatedImages = 0;
    _adsProgress = 0;
    _dailyLimitReached = false;
    _isInitialized = false;
    _isLoading = false;
    _isWatchingAd = false;
    _error = null;
    notifyListeners();
  }
}
