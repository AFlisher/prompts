import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_button_styles.dart';
import '../main.dart';
import '../models/credit_pack.dart';
import '../services/api_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/purchase_service.dart';
import '../services/haptic_service.dart';
import '../widgets/watch_ad_button.dart';
import '../widgets/status_bar_style.dart';
import '../utils/secure_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/legal_urls.dart';

class PaywallScreen extends StatefulWidget {
  final bool isDarkMode;

  /// Overrides the credit-pack data source. Only intended for widget tests,
  /// which have no real backend to fetch from.
  final Future<List<CreditPack>> Function()? fetchPacksOverride;

  /// Sprint 2 / B-3. Overrides the store integration. Widget tests have no
  /// billing service to talk to, and a test that reached a real store would be
  /// both flaky and capable of charging somebody.
  final PurchaseService? purchaseServiceOverride;

  const PaywallScreen({
    super.key,
    required this.isDarkMode,
    this.fetchPacksOverride,
    this.purchaseServiceOverride,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final ApiService _apiService = ApiService();

  /// Sprint 2 / B-3. Overridable so widget tests can drive the purchase flow
  /// without a store, matching the fetchPacksOverride convention above.
  late final PurchaseService _purchaseService =
      widget.purchaseServiceOverride ?? PurchaseService();

  List<CreditPack> _packs = [];
  bool _isLoadingPacks = true;
  String? _packsError;

  /// Store metadata, keyed by SKU. Empty when the store is unavailable or the
  /// products have not been created yet - in which case nothing is purchasable
  /// and the UI says so instead of offering a dead button.
  final Map<String, ProductDetails> _storeProducts = {};
  bool _storeAvailable = false;

  String? _selectedPackId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Started before any purchase can begin so a purchase re-delivered from a
    // previous session - one left unfinished because verification failed - is
    // picked up and credited with no user action.
    _purchaseService.start();
    _fetchPacks();
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }

  /// The store product backing [pack], or null when it has no SKU or the store
  /// does not sell it.
  ProductDetails? _productFor(CreditPack pack) {
    if (!pack.isPurchasable) return null;
    return _storeProducts[pack.productId];
  }

  /// The price to show: the store's localised value when we have it (correct
  /// currency, regional pricing and tax for THIS buyer), falling back to the
  /// admin-entered label only when the store has no matching product.
  String _priceFor(CreditPack pack) => _productFor(pack)?.price ?? pack.priceDisplay;

  /// Whether the currently selected pack can actually be bought right now.
  ///
  /// Both halves matter: a device with no billing service, and a pack whose SKU
  /// does not exist in the store. Either way the CTA is disabled rather than
  /// failing after the user commits to it.
  bool get _canPurchase {
    if (!_storeAvailable) return false;
    final id = _selectedPackId;
    if (id == null) return false;
    final pack = _packs.where((p) => p.id == id).firstOrNull;
    return pack != null && _productFor(pack) != null;
  }

  /// Loads store metadata for the SKUs the catalogue advertises.
  ///
  /// Failure here is not fatal and is not surfaced as an error: it means
  /// nothing is purchasable, which the pack cards already communicate.
  Future<void> _loadStoreProducts(List<CreditPack> packs) async {
    final skus = packs
        .where((p) => p.isPurchasable)
        .map((p) => p.productId!)
        .toSet();

    try {
      // Availability is checked even when no pack carries a SKU. Skipping it
      // would leave _storeAvailable false and make the UI blame the device
      // ("in-app purchases are unavailable here") for what is actually an
      // unfinished catalogue - two different problems with two different
      // owners, and telling the user the wrong one is worse than saying
      // nothing.
      final available = await _purchaseService.isStoreAvailable();
      if (!mounted) return;
      setState(() => _storeAvailable = available);

      if (!available || skus.isEmpty) return;

      final products = await _purchaseService.loadProducts(skus);
      if (!mounted) return;
      setState(() {
        _storeProducts
          ..clear()
          ..addEntries(products.map((p) => MapEntry(p.id, p)));
      });
    } catch (e) {
      debugPrint('[PaywallScreen] store products unavailable: $e');
    }
  }

  Future<void> _fetchPacks() async {
    setState(() {
      _isLoadingPacks = true;
      _packsError = null;
    });
    try {
      final packs = await (widget.fetchPacksOverride?.call() ?? _apiService.getCreditPacks());
      if (!mounted) return;
      setState(() {
        _packs = packs;
        // Default-select the pack with a badge (e.g. "Best Value") if one
        // exists, otherwise the first pack.
        _selectedPackId = packs.isEmpty
            ? null
            : packs.firstWhere((p) => p.badge != null, orElse: () => packs.first).id;
        _isLoadingPacks = false;
      });
      await _loadStoreProducts(packs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _packsError = 'Failed to load credit packs.';
        _isLoadingPacks = false;
      });
    }
  }

  /// Sprint 2 / B-3. Real store purchase, credited only by the server.
  ///
  /// What used to be here: a simulated Apple/Google purchase sheet followed by
  /// `creditManager.addCredits()`, which incremented a number in device memory
  /// that the next wallet fetch overwrote. No money moved and the credits
  /// vanished. Both the sheet and addCredits() are deleted.
  void _handlePurchase(BuildContext context) async {
    final selectedPack = _packs.firstWhere((p) => p.id == _selectedPackId);
    final product = _productFor(selectedPack);

    if (product == null) {
      // Either the SKU is unset on the pack or the store does not know it.
      // Saying so is better than a button that appears to work and cannot.
      _showMessage('This pack is not available for purchase yet.');
      return;
    }

    HapticService.medium();
    setState(() => _isLoading = true);

    final result = await _purchaseService.buy(product);

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result.outcome) {
      case PurchaseOutcome.cancelled:
        return;

      case PurchaseOutcome.credited:
      case PurchaseOutcome.alreadyCredited:
        // The balance comes from the server's response - never computed here.
        final creditManager = CreditProvider.of(context);
        if (result.balance != null) {
          creditManager.applyServerBalance(result.balance!);
        } else {
          await creditManager.fetchWallet();
        }
        if (!mounted) return;
        HapticService.vibrate();
        _showPurchaseSuccess(result);
        return;

      case PurchaseOutcome.retryable:
        _showMessage(result.message ??
            'We could not confirm your purchase yet. It is safe - we will retry automatically.');
        return;

      case PurchaseOutcome.failed:
        _showMessage(result.message ?? 'This purchase could not be completed.');
        return;
    }
  }

  /// Sprint 2 / B-3. Re-presents purchases the store still holds for this
  /// account. Required by both stores and expected by anyone who reinstalls.
  void _handleRestore(BuildContext context) async {
    HapticService.light();
    setState(() => _isLoading = true);

    try {
      await _purchaseService.restore();
      if (!mounted) return;
      // Restored purchases arrive on the purchase stream and are verified
      // individually; the balance is re-read rather than guessed at.
      await CreditProvider.of(context).fetchWallet();
      if (!mounted) return;
      _showMessage('Restore complete. Any missing credits have been added.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not restore purchases. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showPurchaseSuccess(PurchaseResult result) {
    final added = result.creditsGranted;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? AppTheme.darkCard : AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              added > 0 ? 'Purchase Successful!' : 'Already Credited',
              style: TextStyle(
                color: widget.isDarkMode ? AppTheme.white : AppTheme.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              added > 0
                  ? 'Added $added credits to your balance.'
                  : 'This purchase was already added to your balance.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mediumGray, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: AppButtonStyles.primary(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Start Creating',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? AppTheme.black : AppTheme.lightBackground;
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;
    final creditManager = CreditProvider.of(context);

    return SecureScreenGuard(
      // Phase 6: billing on screen - screenshots, screen
      // recording and the recent-apps thumbnail are blocked while this
      // screen is mounted (Android; see SecureScreen for the iOS limits).
      child: StatusBarStyle(
      isDark: widget.isDarkMode,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              // Ambient Radial Gradient
              Positioned(
                top: -100,
                left: -100,
                right: -100,
                child: Container(
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accentPurple.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      radius: 0.8,
                    ),
                  ),
                ),
              ),

              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top close button
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: GestureDetector(
                          onTap: () {
                            HapticService.light();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: textColor.withValues(alpha: 0.6)),
                            ),
                            child: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.6), size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Premium Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.accentPurple, AppTheme.accentPink],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentPurple.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.token_rounded, color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 24),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, AppTheme.accentPink],
                            ).createShader(bounds),
                            child: Text(
                              'BUY CREDITS',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1 credit = 1 custom AI style photo generation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Balance Display Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: widget.isDarkMode ? AppTheme.darkCard : AppTheme.lightGray,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Current Balance: ',
                                  style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${creditManager.credits} Credits',
                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Watch-ad-for-credit card (Roadmap Item 3.2)
                          AnimatedBuilder(
                            animation: creditManager,
                            builder: (context, _) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode ? AppTheme.darkCard : AppTheme.lightGray,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accentPurple, size: 22),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Watch Ads for a Free Credit',
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    if (creditManager.dailyLimitReached)
                                      Text(
                                        "You've claimed today's free credit. Come back tomorrow!",
                                        style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
                                      )
                                    else ...[
                                      Row(
                                        children: List.generate(2, (i) {
                                          final filled = i < creditManager.adsProgress;
                                          return Expanded(
                                            child: Container(
                                              height: 8,
                                              margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                                              decoration: BoxDecoration(
                                                color: filled
                                                    ? AppTheme.accentPurple
                                                    : (widget.isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${creditManager.adsProgress}/2 ads watched today - watch 2 for 1 free credit',
                                        style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12),
                                      ),
                                      const SizedBox(height: 14),
                                      WatchAdButton(creditManager: creditManager),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Credit packs selector
                  if (_isLoadingPacks)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.accentPurple)),
                      ),
                    )
                  else if (_packsError != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                        child: Column(
                          children: [
                            Text(_packsError!, style: TextStyle(color: textColor)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchPacks,
                              style: AppButtonStyles.primary(),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: Column(
                          children: _packs.map((pack) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildPackCard(
                                packId: pack.id,
                                title: pack.name,
                                credits: pack.credits,
                                price: _priceFor(pack),
                                badge: pack.badge,
                                desc: pack.description ?? '',
                                textColor: textColor,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),

                  // Sprint 2 / B-3: says why purchasing is unavailable rather
                  // than presenting a button that cannot work. Reached when the
                  // device has no billing service, or before the SKUs exist in
                  // the store consoles - which is the state every seeded pack
                  // ships in today.
                  if (!_isLoadingPacks && _packs.isNotEmpty && !_canPurchase)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
                        child: Text(
                          _storeAvailable
                              ? 'Credit packs are not available for purchase yet. You can still earn credits by watching ads.'
                              : 'In-app purchases are unavailable on this device. You can still earn credits by watching ads.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),

                  // Action button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: ElevatedButton(
                        onPressed: (_isLoading || _selectedPackId == null || !_canPurchase)
                            ? null
                            : () => _handlePurchase(context),
                        style: AppButtonStyles.primary(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 4,
                          shadowColor: AppTheme.accentPurple.withValues(alpha: 0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : const Text(
                                'Purchase Credits Pack',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Footer links
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFooterLink(
                            'Terms of Service',
                            textColor,
                            () => _openLegal(context, LegalUrls.termsOfService, 'Terms of Service'),
                          ),
                          _buildFooterLink(
                            'Privacy Policy',
                            textColor,
                            () => _openLegal(context, LegalUrls.privacyPolicy, 'Privacy Policy'),
                          ),
                          _buildFooterLink(
                            'Restore Purchases',
                            textColor,
                            () => _handleRestore(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPackCard({
    required String packId,
    required String title,
    required int credits,
    required String price,
    required String? badge,
    required String desc,
    required Color textColor,
  }) {
    final isSelected = _selectedPackId == packId;
    final cardBg = widget.isDarkMode ? AppTheme.darkCard : AppTheme.lightGray;

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          _selectedPackId = packId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentPurple : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentPurple.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.accentPurple : AppTheme.mediumGray,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$credits Credits',
                  style: const TextStyle(
                    color: AppTheme.accentPink,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        onTap();
      },
      child: Text(
        text,
        style: TextStyle(
          color: textColor.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // No real Terms of Service / Privacy Policy pages exist yet (see
  // LEGAL_REQUIREMENTS.md - a release blocker), and real purchases aren't
  // live yet either - these links are honestly non-functional rather than
  // pointing at an invented URL.
  /// Sprint 1 / B-2. These two footer links were honestly non-functional
  /// because no hosted documents existed (LEGAL_REQUIREMENTS.md). They now
  /// exist, so the links open them. `Restore Purchases` keeps its
  /// not-yet-available message, because real purchases genuinely are not live
  /// and inventing a working-looking control for them would be the same
  /// dishonesty this method was written to avoid.
  Future<void> _openLegal(BuildContext context, String url, String label) async {
    HapticService.light();

    if (!LegalUrls.isConfigured) {
      _showNotYetAvailable(context, label, reason: 'this build has no backend URL configured');
      return;
    }

    try {
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {
      // Falls through to the message below.
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Couldn't open $label. It is available at $url"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNotYetAvailable(BuildContext context, String label, {String? reason}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason != null ? '$label is not available yet - $reason.' : '$label is not available yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
