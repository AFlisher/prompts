import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/style_card.dart';
import 'upload_screen.dart';
import '../main.dart';
import '../utils/image_helper.dart';
import '../widgets/status_bar_style.dart';

class StyleDetailsScreen extends StatefulWidget {
  final StyleModel style;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  /// The [Hero] tag the tapped card used to get here, so its image flies
  /// smoothly into this screen's hero image instead of a bare route swap.
  /// Falls back to a tag derived from the style id alone when absent (e.g.
  /// if this screen is ever reached without a card tap), matching the
  /// original single-tag behavior.
  final String? heroTag;

  const StyleDetailsScreen({
    super.key,
    required this.style,
    required this.isDarkMode,
    this.onToggleDarkMode,
    this.heroTag,
  });

  @override
  State<StyleDetailsScreen> createState() => _StyleDetailsScreenState();
}

class _StyleDetailsScreenState extends State<StyleDetailsScreen> {
  late bool _isDark;
  bool _tryButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  void _toggleDark() {
    setState(() => _isDark = !_isDark);
    widget.onToggleDarkMode?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final bgColor = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.black;
    final heroTag = widget.heroTag ?? 'hero_style_img_${widget.style.id}';

    return StatusBarStyle(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
                  child: AppHeader(
                    isDarkMode: isDark,
                    onToggleDarkMode: _toggleDark,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: _HeroStyleCard(
                    style: widget.style,
                    heroTag: heroTag,
                    isFavorite: FavoritesProvider.of(context).isFavorite(widget.style.id),
                    isDarkMode: isDark,
                    marginTop: 16,
                    onBack: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    onShare: _shareStyle,
                    onFavorite: _toggleFavorite,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 12),
                  child: Text(
                    'PHOTO GUIDELINES',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 2,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 26),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.28,
                  ),
                  delegate: SliverChildListDelegate.fixed([
                    _GuidelineCard(
                      good: true,
                      title: 'Good Lighting',
                      body: 'Natural or soft\nlight',
                      icon: Icons.verified,
                    ),
                    _GuidelineCard(
                      good: true,
                      title: 'Clear Face',
                      body: 'No heavy\nabstructions',
                      icon: Icons.verified,
                    ),
                    _GuidelineCard(
                      good: false,
                      title: 'Blurry photos',
                      body: 'no blurry photo\nplease',
                      icon: Icons.close,
                    ),
                    _GuidelineCard(
                      good: false,
                      title: 'Heavy filters',
                      body: 'bla idk what to\nwrite here',
                      icon: Icons.close,
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
                  child: _TryButton(
                    pressed: _tryButtonPressed,
                    onTapDown: () => setState(() => _tryButtonPressed = true),
                    onTapCancel: () => setState(() => _tryButtonPressed = false),
                    onTapUp: () {
                      setState(() => _tryButtonPressed = false);
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UploadScreen(
                            style: widget.style,
                            isDarkMode: _isDark,
                            onToggleDarkMode: _toggleDark,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SimilarStylesSection(
                  anchorStyle: widget.style,
                  isDarkMode: isDark,
                  onToggleDarkMode: widget.onToggleDarkMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFavorite() {
    HapticFeedback.mediumImpact();
    final nowFavorite = FavoritesProvider.of(context).toggleFavorite(widget.style.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(nowFavorite ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareStyle() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${widget.style.name}'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// "You may also like" - styles similar to [anchorStyle], ranked entirely by
/// RecommendationService (GET /api/styles/:id/similar). Unlike Home's
/// "Recommended For You", this is never gated by the personalization
/// setting: it's style-to-style similarity, not the viewer's own history, so
/// it renders the same way for every user, logged in or not.
class _SimilarStylesSection extends StatefulWidget {
  final StyleModel anchorStyle;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  const _SimilarStylesSection({
    required this.anchorStyle,
    required this.isDarkMode,
    this.onToggleDarkMode,
  });

  @override
  State<_SimilarStylesSection> createState() => _SimilarStylesSectionState();
}

class _SimilarStylesSectionState extends State<_SimilarStylesSection> {
  List<StyleModel>? _similarStyles;

  @override
  void initState() {
    super.initState();
    StyleProvider.read(context).loadSimilarStyles(widget.anchorStyle.id).then((styles) {
      if (mounted) setState(() => _similarStyles = styles);
    });
  }

  void _onStyleTapped(StyleModel style) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDetailsScreen(
          style: style,
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = _similarStyles;
    // Rendered the moment the request resolves; before that (or if it comes
    // back empty - a brand-new, untagged style) the section simply isn't
    // there, same "no half-loaded placeholder" rule Home's sections follow.
    if (styles == null || styles.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 12),
          child: Text(
            'You May Also Like',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final style = styles[index];
              return SizedBox(
                width: 135,
                child: StyleCard(
                  style: style,
                  isDarkMode: widget.isDarkMode,
                  onTap: () => _onStyleTapped(style),
                  cardWidth: 135,
                  heroTag: 'similar_${widget.anchorStyle.id}_${style.id}',
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemCount: styles.length,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HeroStyleCard extends StatelessWidget {
  final StyleModel style;
  final String heroTag;
  final bool isFavorite;
  final bool isDarkMode;
  final double marginTop;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _HeroStyleCard({
    required this.style,
    required this.heroTag,
    required this.isFavorite,
    required this.isDarkMode,
    this.marginTop = 0,
    required this.onBack,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: marginTop),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImageViewer(
                          imagePath: style.displayImage,
                          heroTag: heroTag,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: heroTag,
                    child: buildStyleImage(
                      style.displayImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _GlassActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                    isDarkMode: isDarkMode,
                  ),
                ),
                Positioned(
                  right: 48,
                  top: 10,
                  child: _GlassActionButton(
                    icon: Icons.share_rounded,
                    onTap: onShare,
                    isDarkMode: isDarkMode,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _GlassActionButton(
                    icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    iconColor: isFavorite ? Colors.redAccent : null,
                    onTap: onFavorite,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          style.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
        ),
        if (style.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            style.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.78),
                  height: 1.4,
                ),
          ),
        ],
      ],
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;
  final Color? iconColor;

  const _GlassActionButton({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.44),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.36), width: 1),
            ),
            child: Icon(icon, color: iconColor ?? AppTheme.black, size: 20),
          ),
        ),
      ),
    );
  }
}

class _GuidelineCard extends StatelessWidget {
  final bool good;
  final String title;
  final String body;
  final IconData icon;

  const _GuidelineCard({
    required this.good,
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF121522), Color(0xFF25283B)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5962FF).withValues(alpha: 0.34),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: good ? const Color(0xFF27FF47) : const Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.black, size: 12),
            ),
          ),
          Positioned(
            left: 15,
            right: 8,
            top: 29,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            left: 15,
            right: 6,
            top: 44,
            child: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TryButton extends StatelessWidget {
  final bool pressed;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const _TryButton({
    required this.pressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: pressed ? 0.97 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accentPurple, AppTheme.accentPink],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                'Try This Style',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zoomable interactive image viewer
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: buildStyleImage(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          
          // Float close button
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
