import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/credit_manager.dart';
import '../theme/app_theme.dart';

/// The "Watch an Ad for a Free Credit" button, reactive to [CreditManager]'s
/// ad-watching state. Shared between the not-enough-credits sheet
/// (upload_screen.dart) and the paywall screen (Roadmap Items 3.1/3.2).
class WatchAdButton extends StatelessWidget {
  final CreditManager creditManager;
  final VoidCallback? onRewarded;

  const WatchAdButton({
    super.key,
    required this.creditManager,
    this.onRewarded,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: creditManager,
      builder: (context, _) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: creditManager.isWatchingAd
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    final rewarded = await creditManager.watchAdForCredit();
                    if (!context.mounted) return;
                    if (rewarded) {
                      onRewarded?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Credit earned!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No ad is available right now. Please try again later.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            icon: creditManager.isWatchingAd
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentPurple),
                  )
                : const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accentPurple, size: 20),
            label: Text(
              creditManager.isWatchingAd ? 'Loading Ad...' : 'Watch an Ad for a Free Credit',
              style: const TextStyle(color: AppTheme.accentPurple, fontWeight: FontWeight.w900, fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.accentPurple, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        );
      },
    );
  }
}
