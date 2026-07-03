import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MyCreationsScreen extends StatelessWidget {
  final bool isDarkMode;

  const MyCreationsScreen({super.key, required this.isDarkMode});

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
                'My Creations',
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
                        Icons.auto_awesome_mosaic_outlined,
                        color: AppTheme.mediumGray,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No creations yet',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your styled photos will appear here',
                      style: TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppTheme.white : AppTheme.black,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      child: Text(
                        '✨ Create Your First',
                        style: TextStyle(
                          color: isDarkMode ? AppTheme.black : AppTheme.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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
