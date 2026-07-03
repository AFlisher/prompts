import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FavoritesScreen extends StatelessWidget {
  final bool isDarkMode;

  const FavoritesScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppTheme.black : AppTheme.white;
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;

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
                      child: Icon(
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
            ),
          ],
        ),
      ),
    );
  }
}
