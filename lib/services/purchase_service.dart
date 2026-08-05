import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'auth_service.dart';
import 'idempotency_service.dart';
import 'network_client.dart';

/// What happened to one purchase, from the app's point of view.
enum PurchaseOutcome {
  /// Credits were added by the server on this call.
  credited,

  /// The server had already credited this purchase. Not an error - it is what
  /// a retry or a restore of an existing purchase looks like.
  alreadyCredited,

  /// The user backed out of the store sheet.
  cancelled,

  /// Verification could not be completed, but the purchase is intact and
  /// should be retried. The purchase is deliberately NOT finished on the
  /// device, so the platform will re-deliver it.
  retryable,

  /// The platform or the server rejected this definitively.
  failed,
}

class PurchaseResult {
  final PurchaseOutcome outcome;
  final int creditsGranted;
  final int? balance;
  final String? message;

  const PurchaseResult(
    this.outcome, {
    this.creditsGranted = 0,
    this.balance,
    this.message,
  });

  bool get isSuccess =>
      outcome == PurchaseOutcome.credited || outcome == PurchaseOutcome.alreadyCredited;
}

/// Sprint 2 / B-3 — real store purchases, verified server-side.
///
/// ─── What this replaced ─────────────────────────────────────────────────────
///
/// A widget that drew a convincing imitation of Apple's and Google's own
/// purchase sheets, and a `CreditManager.addCredits()` that incremented a
/// number in device memory. No money moved, no server was contacted, and the
/// "purchased" credits vanished on the next wallet fetch. Both are deleted.
///
/// ─── The rule this class exists to enforce ──────────────────────────────────
///
/// **`completePurchase` is called only after the backend has credited the
/// account.** That ordering is the entire safety argument. Finishing a purchase
/// on the device consumes it: the platform stops re-delivering it, and if the
/// server had not yet granted the credits, the user has paid for nothing with
/// no way to recover it. So a verification failure deliberately leaves the
/// purchase unfinished, and the platform re-delivers it on the next app start -
/// which is what makes a dropped connection mid-purchase a non-event.
///
/// The one exception is a definitively rejected purchase (`failed`): re-delivery
/// of something the platform itself says is invalid would loop forever.
class PurchaseService {
  PurchaseService({
    InAppPurchase? iap,
    AuthService? authService,
  })  : _iap = iap ?? InAppPurchase.instance,
        _authService = authService ?? AuthService();

  final InAppPurchase _iap;
  final AuthService _authService;

  late final AuthorizedHttpClient _client = AuthorizedHttpClient(_authService);

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// 'google' on Android, 'apple' on iOS — the values the backend accepts.
  static String get platformName => Platform.isIOS ? 'apple' : 'google';

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Resolves when the purchase started by [buy] reaches a terminal state.
  Completer<PurchaseResult>? _pending;

  /// Whether the device can transact at all (no store on an emulator image
  /// without Play Services, for example).
  Future<bool> isStoreAvailable() => _iap.isAvailable();

  /// Loads store metadata for [productIds].
  ///
  /// Anything the store does not know about comes back in `notFoundIDs` and is
  /// simply absent from the result. That is the expected state before the SKUs
  /// are created in the consoles, and the paywall shows only what the store
  /// actually sells rather than advertising something unbuyable.
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    if (productIds.isEmpty) return const [];

    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('[PurchaseService] queryProductDetails failed: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[PurchaseService] store does not know: ${response.notFoundIDs}');
    }
    return response.productDetails;
  }

  /// Begins listening for purchase updates. Must be running before [buy].
  ///
  /// Also picks up purchases the platform re-delivers from a previous session -
  /// the ones left unfinished because verification failed - so a purchase
  /// interrupted by a crash or a dead connection is credited on next launch
  /// with no user action.
  void start() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('[PurchaseService] purchase stream error: $e'),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Buys [product] and resolves once it has been verified, rejected, or
  /// cancelled.
  ///
  /// `ConsumableProductParams` because credit packs are consumables: the same
  /// pack must be buyable repeatedly.
  Future<PurchaseResult> buy(ProductDetails product) async {
    start();

    if (_pending != null && !_pending!.isCompleted) {
      return const PurchaseResult(
        PurchaseOutcome.failed,
        message: 'A purchase is already in progress.',
      );
    }

    final completer = Completer<PurchaseResult>();
    _pending = completer;

    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

      if (!started) {
        _pending = null;
        return const PurchaseResult(
          PurchaseOutcome.failed,
          message: 'The store could not start this purchase.',
        );
      }
    } catch (e) {
      _pending = null;
      debugPrint('[PurchaseService] buyConsumable threw: $e');
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: friendlyNetworkErrorMessage(e),
      );
    }

    return completer.future;
  }

  /// Asks the platform to re-deliver everything this account owns. Results
  /// arrive on the purchase stream and are verified like any other purchase.
  Future<void> restore() async {
    start();
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // Sequential on purpose. Each iteration hits the backend, and firing a
      // restore's whole batch concurrently would stampede both our own rate
      // limiter and Google's quota-limited verification API.
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        // Nothing to do. Not money yet; the platform will send another update.
        return;

      case PurchaseStatus.canceled:
        await _finish(purchase);
        _resolve(const PurchaseResult(PurchaseOutcome.cancelled));
        return;

      case PurchaseStatus.error:
        // The platform itself rejected this. Finishing it stops an
        // unresolvable purchase being re-delivered on every launch forever.
        await _finish(purchase);
        _resolve(PurchaseResult(
          PurchaseOutcome.failed,
          message: purchase.error?.message ?? 'The purchase could not be completed.',
        ));
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final result = await _verifyWithBackend(purchase);

        // THE ORDERING RULE. Only a credited purchase may be finished.
        if (result.isSuccess) {
          await _finish(purchase);
        } else if (result.outcome == PurchaseOutcome.failed) {
          // Definitively invalid - finishing prevents an endless redelivery
          // loop for something that can never be credited.
          await _finish(purchase);
        }
        // `retryable` deliberately leaves the purchase unfinished so the
        // platform re-delivers it and we try again.

        _resolve(result);
        return;
    }
  }

  Future<void> _finish(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('[PurchaseService] completePurchase failed: $e');
    }
  }

  void _resolve(PurchaseResult result) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
    _pending = null;
  }

  /// POST /api/purchases/verify — the only thing that can create credits.
  ///
  /// Carries an Idempotency-Key derived from the purchase's own identifier, so
  /// a retry after a lost response does not re-run verification against
  /// Google's quota-limited API. The server is idempotent on the purchase token
  /// regardless; this is the cheaper outer guard.
  Future<PurchaseResult> _verifyWithBackend(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      return const PurchaseResult(
        PurchaseOutcome.failed,
        message: 'This purchase is missing its receipt.',
      );
    }

    final operationId = IdempotencyService.operationIdFrom([
      'POST /api/purchases/verify',
      purchase.productID,
      token,
    ]);

    try {
      final key = await IdempotencyService.keyFor(operationId);

      final response = await _client.send(
        idempotencyKey: key,
        (headers) => backendClient.post(
          Uri.parse('$_backendUrl/api/purchases/verify'),
          headers: headers,
          body: json.encode({
            'platform': platformName,
            'productId': purchase.productID,
            'purchaseToken': token,
          }),
        ),
        timeout: NetworkTimeouts.api,
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        await IdempotencyService.clear(operationId);

        final granted = body['granted'] == true;
        return PurchaseResult(
          granted ? PurchaseOutcome.credited : PurchaseOutcome.alreadyCredited,
          creditsGranted: (body['credits'] as num?)?.toInt() ?? 0,
          balance: (body['balance'] as num?)?.toInt(),
        );
      }

      // 503 is ours: verification unavailable, or a payment still clearing.
      // The purchase stays unfinished and is retried later.
      if (response.statusCode == 503) {
        return PurchaseResult(
          PurchaseOutcome.retryable,
          message: _messageFrom(response.body) ??
              'We could not confirm your purchase yet. It is safe - we will retry automatically.',
        );
      }

      // 422 and 400 are definitive. Clear the key: this operation will never
      // succeed, and leaving it would pin a dead key for 24 hours.
      await IdempotencyService.clear(operationId);
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: _messageFrom(response.body) ?? 'This purchase could not be verified.',
      );
    } on Object catch (e) {
      // A transport failure says nothing about the purchase's validity, so it
      // must be retryable - and the key is deliberately NOT cleared, so the
      // retry reuses it.
      debugPrint('[PurchaseService] verification transport failure: $e');
      return PurchaseResult(
        PurchaseOutcome.retryable,
        message: friendlyNetworkErrorMessage(e),
      );
    }
  }

  static String? _messageFrom(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // A non-JSON body (a proxy error page) must not crash the purchase flow.
    }
    return null;
  }
}
