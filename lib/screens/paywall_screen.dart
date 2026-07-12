import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_button_styles.dart';
import '../main.dart';
import '../models/credit_pack.dart';
import '../services/api_service.dart';
import '../widgets/simulated_store_pay.dart';
import '../widgets/watch_ad_button.dart';

class PaywallScreen extends StatefulWidget {
  final bool isDarkMode;

  /// Overrides the credit-pack data source. Only intended for widget tests,
  /// which have no real backend to fetch from.
  final Future<List<CreditPack>> Function()? fetchPacksOverride;

  const PaywallScreen({super.key, required this.isDarkMode, this.fetchPacksOverride});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final ApiService _apiService = ApiService();

  List<CreditPack> _packs = [];
  bool _isLoadingPacks = true;
  String? _packsError;

  String? _selectedPackId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPacks();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _packsError = 'Failed to load credit packs.';
        _isLoadingPacks = false;
      });
    }
  }

  void _handlePurchase(BuildContext context) async {
    final selectedPack = _packs.firstWhere((p) => p.id == _selectedPackId);
    final creditsToAdded = selectedPack.credits;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
    });

    // Show simulated iOS App Store or Google Play Store billing sheet
    final purchased = await showSimulatedStorePaySheet(
      context: context,
      packTitle: selectedPack.name,
      price: selectedPack.priceDisplay,
      credits: creditsToAdded,
      isDarkMode: widget.isDarkMode,
      platform: Theme.of(context).platform,
    );

    if (!mounted) return;

    if (!purchased) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final creditManager = CreditProvider.of(context);
    await creditManager.addCredits(creditsToAdded);

    setState(() {
      _isLoading = false;
    });

    HapticFeedback.vibrate();

    // Show a success dialog
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
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Purchase Successful!',
              style: TextStyle(
                color: widget.isDarkMode ? AppTheme.white : AppTheme.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Added $creditsToAdded credits to your balance successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mediumGray,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close Purchase Screen
              },
              style: AppButtonStyles.primary(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Start Creating', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? AppTheme.black : AppTheme.white;
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;
    final creditManager = CreditProvider.of(context);

    return Scaffold(
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
                          HapticFeedback.lightImpact();
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
                              price: pack.priceDisplay,
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

                // Action button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: ElevatedButton(
                      onPressed: (_isLoading || _selectedPackId == null) ? null : () => _handlePurchase(context),
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
                          () => _showNotYetAvailable(context, 'Terms of Service'),
                        ),
                        _buildFooterLink(
                          'Privacy Policy',
                          textColor,
                          () => _showNotYetAvailable(context, 'Privacy Policy'),
                        ),
                        _buildFooterLink(
                          'Restore Purchases',
                          textColor,
                          () => _showNotYetAvailable(context, 'Restore Purchases', reason: 'real purchases are not live yet'),
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
        HapticFeedback.lightImpact();
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
                    style: TextStyle(
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
        HapticFeedback.lightImpact();
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
  void _showNotYetAvailable(BuildContext context, String label, {String? reason}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason != null ? '$label is not available yet - $reason.' : '$label is not available yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
