import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

/// Shows a highly realistic simulated App Store (iOS) or Google Play Store (Android)
/// purchase confirmation sheet depending on the platform.
Future<bool> showSimulatedStorePaySheet({
  required BuildContext context,
  required String packTitle,
  required String price,
  required int credits,
  required bool isDarkMode,
  required TargetPlatform platform,
}) async {
  final isIOS = platform == TargetPlatform.iOS;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: isIOS ? 0.7 : 0.5),
    builder: (context) {
      if (isIOS) {
        return _IOSAppStoreSheet(
          packTitle: packTitle,
          price: price,
          credits: credits,
        );
      } else {
        return _AndroidPlayStoreSheet(
          packTitle: packTitle,
          price: price,
          credits: credits,
          isDarkMode: isDarkMode,
        );
      }
    },
  );

  return result ?? false;
}

// ─── APPLE APP STORE SHEET (iOS) ─────────────────────────────────────────────
class _IOSAppStoreSheet extends StatefulWidget {
  final String packTitle;
  final String price;
  final int credits;

  const _IOSAppStoreSheet({
    required this.packTitle,
    required this.price,
    required this.credits,
  });

  @override
  State<_IOSAppStoreSheet> createState() => _IOSAppStoreSheetState();
}

class _IOSAppStoreSheetState extends State<_IOSAppStoreSheet> {
  int _state = 0; // 0: Idle/Prompt, 1: Scanning FaceID, 2: Success
  Timer? _faceIdTimer;

  void _triggerPayment() {
    HapticService.medium();
    setState(() {
      _state = 1; // FaceID Scanning
    });

    _faceIdTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _state = 2; // Success
        });
        // Satisyfing double haptic click for Apple Pay success
        HapticService.heavy();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticService.heavy();
        });

        // Close after success animation completes
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _faceIdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset + paddingBottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark iOS sheet color
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Apple Pay / App Store Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.apple_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 6),
                    Text(
                      'App Store',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticService.light();
                    Navigator.pop(context, false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // App Meta & Info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Branded App Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'StyliAI — AI Photo Styles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ahmed · In-App Purchase',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Double Info (Account & Price)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _buildIOSRow('ACCOUNT', 'ahmed@example.com'),
                const SizedBox(height: 12),
                _buildIOSRow('ITEM', '${widget.packTitle} (${widget.credits} Credits)'),
                const SizedBox(height: 12),
                _buildIOSRow(
                  'PRICE',
                  widget.price,
                  valueColor: Colors.white,
                  isBold: true,
                ),
              ],
            ),
          ),

          // App Store verification / button action area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildActionArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea() {
    if (_state == 0) {
      // Prompt/Confirm Action Button
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulated Side Button Double-Click Indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF), // Apple Blue button color
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: _triggerPayment,
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.contactless_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Pay with Passcode / Touch ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Double-click your power button or tap above to confirm purchase',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      );
    } else if (_state == 1) {
      // Face ID Scanning Animation
      return const Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Color(0xFF007AFF),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Processing payment...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      // Success Checkmark
      return Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759), // iOS Green
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Done',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }
}

// ─── GOOGLE PLAY STORE SHEET (Android) ───────────────────────────────────────
class _AndroidPlayStoreSheet extends StatefulWidget {
  final String packTitle;
  final String price;
  final int credits;
  final bool isDarkMode;

  const _AndroidPlayStoreSheet({
    required this.packTitle,
    required this.price,
    required this.credits,
    required this.isDarkMode,
  });

  @override
  State<_AndroidPlayStoreSheet> createState() => _AndroidPlayStoreSheetState();
}

class _AndroidPlayStoreSheetState extends State<_AndroidPlayStoreSheet> {
  bool _isProcessing = false;
  bool _isDone = false;

  void _confirmAndroidPayment() async {
    HapticService.medium();
    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isDone = true;
      });
      HapticService.vibrate();

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final sheetBg = widget.isDarkMode ? const Color(0xFF202124) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subColor = widget.isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset + paddingBottom),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Play Store Logo and Title
          Row(
            children: [
              CachedNetworkImage(
                imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Google_Play_Store_software_icon_2022.svg/512px-Google_Play_Store_software_icon_2022.svg.png',
                width: 24,
                height: 24,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 24,
                    height: 24,
                    color: Colors.grey[200],
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.shop_two_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 8),
              Text(
                'Google Play Billing',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: subColor,
                iconSize: 20,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Divider
          Divider(color: widget.isDarkMode ? Colors.white10 : Colors.black12, height: 1),
          const SizedBox(height: 20),

          // Item Info & Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.packTitle} (${widget.credits} Credits)',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'StyliAI (AI Photo Styles)',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.price,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '+ tax if applicable',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Option info row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Visa •••• 5678 (Google Pay)',
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.keyboard_arrow_right_rounded, color: subColor),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Action Button / Loading check status
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isDone
                ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Payment verified successfully!',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmAndroidPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00875F), // Google Play Green
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                          : const Text(
                              '1-Tap Buy',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
