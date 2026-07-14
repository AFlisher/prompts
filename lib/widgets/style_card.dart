import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/style_model.dart';
import '../utils/image_helper.dart';

/// The single style-browsing card used across Home, All Styles, Arabic
/// Styles, and Favorites. A shared image aspect ratio and a fixed-height
/// title slot keep every card identically proportioned regardless of title
/// length or which screen renders it.
class StyleCard extends StatefulWidget {
  /// Width : height ratio applied to the image area everywhere.
  static const double imageAspectRatio = 135 / 200;

  /// Fixed height reserved for the title, sized for exactly two lines at
  /// [AppTheme]'s titleMedium size - so a one-line title never produces a
  /// shorter card than a two-line one.
  static const double titleHeight = 40;

  final StyleModel style;
  final bool isDarkMode;
  final VoidCallback onTap;

  /// The card's rendered width (logical pixels), already known by every
  /// caller from their own fixed-width or grid layout. Passed in explicitly
  /// so the image can be decoded at roughly its displayed size without a
  /// LayoutBuilder - measuring via LayoutBuilder forces this widget's whole
  /// image Stack to be built during the layout phase instead of the normal
  /// build phase, which was the real cause of a residual scroll-jank cost
  /// (previously misattributed to image decode, confirmed via profiling to
  /// be a LAYOUT-phase cost instead).
  final double cardWidth;

  /// When provided, renders a heart button in place of the Trending/Premium
  /// badges (Favorites screen's "remove" affordance takes their spot).
  final VoidCallback? onUnfavorite;

  const StyleCard({
    super.key,
    required this.style,
    required this.isDarkMode,
    required this.onTap,
    required this.cardWidth,
    this.onUnfavorite,
  });

  @override
  State<StyleCard> createState() => _StyleCardState();
}

class _StyleCardState extends State<StyleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;
    final showPromoBadges = widget.onUnfavorite == null;

    // Decode the image at roughly its displayed size (in device pixels)
    // rather than its native resolution - cover images are typically much
    // larger than this thumbnail box, and decoding every one at full size is
    // a common cause of scroll jank when many cards build at once. cardWidth
    // is already known by the caller, so this only needs a normal build-time
    // MediaQuery read - no LayoutBuilder (whose layout-phase rebuild cost
    // was the real, profiler-confirmed source of a residual scroll-jank
    // regression) is needed to find it.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.cardWidth * dpr).round();
    final cacheHeight =
        (widget.cardWidth / StyleCard.imageAspectRatio * dpr).round();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: StyleCard.imageAspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  // A plain black drop shadow reads fine in light mode but
                  // is invisible against the dark theme's near-black page
                  // background - flip to a soft white glow there instead,
                  // the same theme-aware trick used elsewhere in the app.
                  boxShadow: [
                    BoxShadow(
                      color: widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: buildStyleImage(
                          style.displayImage,
                          fit: BoxFit.cover,
                          memCacheWidth: cacheWidth,
                          memCacheHeight: cacheHeight,
                        ),
                      ),
                      if (showPromoBadges && style.isTrending)
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: _CardBadge(
                            label: 'Trending',
                            color: Color(0xFFFF5E5E),
                            textColor: Colors.white,
                          ),
                        ),
                      if (showPromoBadges && style.isPro)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: _CardBadge(
                            label: 'Premium',
                            color: Color(0xFFFFD700),
                            textColor: Colors.black,
                          ),
                        ),
                      if (widget.onUnfavorite != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _UnfavoriteButton(onTap: widget.onUnfavorite!),
                        ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: _CreditBadge(creditCost: style.creditCost),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: StyleCard.titleHeight,
              child: Text(
                style.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _CardBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CreditBadge extends StatelessWidget {
  final int creditCost;

  const _CreditBadge({required this.creditCost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
          const SizedBox(width: 4),
          Text(
            '$creditCost ${creditCost == 1 ? 'Credit' : 'Credits'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnfavoriteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UnfavoriteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.favorite_rounded,
          color: AppTheme.accentPink,
          size: 18,
        ),
      ),
    );
  }
}
