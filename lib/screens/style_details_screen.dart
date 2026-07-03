import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/style_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'upload_screen.dart';

class StyleDetailsScreen extends StatefulWidget {
  final StyleModel style;
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  const StyleDetailsScreen({
    super.key,
    required this.style,
    required this.isDarkMode,
    this.onToggleDarkMode,
  });

  @override
  State<StyleDetailsScreen> createState() => _StyleDetailsScreenState();
}

class _StyleDetailsScreenState extends State<StyleDetailsScreen> {
  late bool _isFavorite;
  bool _tryButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.style.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? AppTheme.black : AppTheme.white;
    final textColor = isDark ? AppTheme.white : AppTheme.black;

    return Scaffold(
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
                  onToggleDarkMode: widget.onToggleDarkMode ?? () {},
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(68, 16, 32, 0),
                child: _HeroStyleCard(
                  style: widget.style,
                  isFavorite: _isFavorite,
                  isDarkMode: isDark,
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
                padding: const EdgeInsets.fromLTRB(76, 14, 40, 12),
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
              padding: EdgeInsets.fromLTRB(78, 0, 40, 10),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 30,
                  mainAxisSpacing: 8,
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
                padding: const EdgeInsets.fromLTRB(76, 0, 40, 26),
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
                          isDarkMode: widget.isDarkMode,
                          onToggleDarkMode: widget.onToggleDarkMode ?? () {},
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite() {
    HapticFeedback.mediumImpact();
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
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

class _HeroStyleCard extends StatelessWidget {
  final StyleModel style;
  final bool isFavorite;
  final bool isDarkMode;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _HeroStyleCard({
    required this.style,
    required this.isFavorite,
    required this.isDarkMode,
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
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  style.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppTheme.lightGray,
                      child: const Icon(Icons.image_outlined),
                    );
                  },
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _GlassActionButton(
                    icon: Icons.arrow_back,
                    onTap: onBack,
                    isDarkMode: isDarkMode,
                  ),
                ),
                Positioned(
                  right: 48,
                  top: 10,
                  child: _GlassActionButton(
                    icon: Icons.share,
                    onTap: onShare,
                    isDarkMode: isDarkMode,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _GlassActionButton(
                    icon: isFavorite ? Icons.favorite : Icons.favorite_border,
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
              colors: [Color(0xFF7C3AED), Color(0xFFE735F6)],
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
              const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
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
