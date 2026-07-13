import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../data/style_data.dart';
import '../models/style_model.dart';
import '../main.dart';
import 'style_details_screen.dart';
import '../widgets/floating_nav_bar_metrics.dart';

class FavoritesScreen extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  const FavoritesScreen({
    super.key,
    required this.isDarkMode,
    this.onToggleDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppTheme.black : AppTheme.white;
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;
    final favManager = FavoritesProvider.of(context);

    final styleManager = StyleProvider.of(context);
    final favoriteStyles = styleManager.categories
        .expand((c) => c.styles)
        .where((s) => favManager.isFavorite(s.id))
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(
                'Favorites',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (favoriteStyles.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppTheme.darkCard
                              : AppTheme.lightGray,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: AppTheme.mediumGray,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No favorites yet',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Styles you heart will show up here',
                        style: TextStyle(
                          color: AppTheme.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    20 + FloatingNavBarMetrics.scrollClearance,
                  ),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: favoriteStyles.length,
                  itemBuilder: (context, index) {
                    final style = favoriteStyles[index];
                    return _FavoriteStyleCard(
                      style: style,
                      isDarkMode: isDarkMode,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StyleDetailsScreen(
                              style: style,
                              isDarkMode: isDarkMode,
                              onToggleDarkMode: onToggleDarkMode,
                            ),
                          ),
                        );
                      },
                      onUnfavorite: () {
                        HapticFeedback.mediumImpact();
                        favManager.toggleFavorite(style.id);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteStyleCard extends StatelessWidget {
  final StyleModel style;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onUnfavorite;

  const _FavoriteStyleCard({
    required this.style,
    required this.isDarkMode,
    required this.onTap,
    required this.onUnfavorite,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkMode ? 0.4 : 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                    child: Image.asset(
                      style.imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: isDarkMode
                              ? AppTheme.darkSurface
                              : AppTheme.lightGray,
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: AppTheme.mediumGray,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onUnfavorite,
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            style.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
