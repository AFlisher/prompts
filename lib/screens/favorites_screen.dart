import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/style_model.dart';
import '../main.dart';
import 'style_details_screen.dart';
import '../widgets/style_card.dart';
import '../widgets/floating_nav_bar_metrics.dart';

class FavoritesScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onToggleDarkMode;

  const FavoritesScreen({
    super.key,
    required this.isDarkMode,
    this.onToggleDarkMode,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<StyleModel> _favoriteStyles = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favManager = FavoritesProvider.of(context);
    final styleManager = StyleProvider.of(context);
    final ids = favManager.favoriteIds.toList();

    final favs = await styleManager.loadFavoriteStyles(ids);
    if (mounted) {
      setState(() {
        _favoriteStyles = favs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? AppTheme.black : AppTheme.lightBackground;
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;
    final favManager = FavoritesProvider.of(context);
    // Matches the GridView below: crossAxisCount 2, 20px padding each side,
    // 12px crossAxisSpacing.
    final cardWidth = (MediaQuery.sizeOf(context).width - 40 - 12) / 2;

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
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentPurple),
                ),
              )
            else if (_favoriteStyles.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
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
                    childAspectRatio: 0.55,
                  ),
                  itemCount: _favoriteStyles.length,
                  itemBuilder: (context, index) {
                    final style = _favoriteStyles[index];
                    return StyleCard(
                      style: style,
                      isDarkMode: widget.isDarkMode,
                      cardWidth: cardWidth,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StyleDetailsScreen(
                              style: style,
                              isDarkMode: widget.isDarkMode,
                              onToggleDarkMode: widget.onToggleDarkMode,
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

