import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../data/creations_manager.dart';
import '../utils/gallery_saver.dart';
import '../widgets/success_hud.dart';
import '../widgets/app_bottom_sheet.dart';
import '../theme/app_button_styles.dart';
import '../services/haptic_service.dart';
import 'image_preview_screen.dart';
import '../widgets/floating_nav_bar_metrics.dart';
import '../utils/image_helper.dart';

class MyCreationsScreen extends StatelessWidget {
  final bool isDarkMode;

  const MyCreationsScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;
    final creationsManager = CreationsProvider.of(context);
    final creations = creationsManager.creations;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'My Creations',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            Expanded(
              child: creations.isEmpty
                  ? _buildEmptyState(context)
                  : _buildCreationsGrid(context, creations, textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkCard : AppTheme.lightGray,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
          GestureDetector(
            onTap: () {
              HapticService.medium();
              CreationsProvider.of(context).setTab(0); // Navigate to Home
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.white : AppTheme.black,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: (isDarkMode ? AppTheme.white : AppTheme.black).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✨ Create Your First',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.black : AppTheme.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreationsGrid(
    BuildContext context,
    List<CreationItem> creations,
    Color textColor,
  ) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + FloatingNavBarMetrics.scrollClearance,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: creations.length,
      itemBuilder: (context, index) {
        final item = creations[index];
        return _buildCreationCard(context, item, textColor);
      },
    );
  }

  Widget _buildCreationCard(BuildContext context, CreationItem item, Color textColor) {
    final cardBg = isDarkMode ? AppTheme.darkCard : AppTheme.lightGray;

    return GestureDetector(
      onTap: () {
        HapticService.medium();
        _showCreationDetailSheet(context, item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main generated image - item.imagePath is a full network URL for
              // backend-generated creations (any provider) and a bundled asset
              // path for pre-migration local-only ones, so this must dispatch
              // on scheme like every other image in the app instead of
              // assuming one or the other.
              buildStyleImage(
                item.imagePath,
                fit: BoxFit.cover,
              ),

              // Bottom gradient overlay for readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),

              // Creation details label overlay
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.styleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Tiny user uploaded photo badge overlay for before/after comparison style
              if (item.originalImagePath != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.file(
                        File(item.originalImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.person, color: Colors.white60, size: 16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreationDetailSheet(BuildContext context, CreationItem item) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    showAppBottomSheet(
      context,
      isDarkMode: isDarkMode,
      isScrollControlled: true,
      contentBuilder: (context) {
        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creation details title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.styleName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Created on ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} at ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, "0")}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () {
                      HapticService.heavy();
                      CreationsProvider.of(context).deleteCreation(item.id);
                      Navigator.pop(context); // Close sheet
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  HapticService.medium();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImagePreviewScreen(
                        assetPath: item.imagePath,
                        title: item.styleName,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 340,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.5 : 0.15),
                        blurRadius: 16,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Styled generation output photo
                        buildStyleImage(
                          item.imagePath,
                          fit: BoxFit.cover,
                        ),

                      // Before (Original photo) small floating container
                      if (item.originalImagePath != null)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ORIGINAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  shadows: [Shadow(blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(item.originalImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Colors.black54,
                                      child: const Icon(Icons.image, color: Colors.white38),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

              // Action buttons: Download & Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final savedPath = await GallerySaver.saveImage(
                          assetPath: item.imagePath,
                        );

                        if (!context.mounted) return;

                        if (savedPath != null) {
                          HapticService.light();
                          SuccessHUD.show(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to save image. Check storage permissions.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, color: textColor),
                          const SizedBox(width: 8),
                          Text('Save to Gallery', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticService.light();
                        final bytes = await GallerySaver.loadBytes(item.imagePath);

                        if (!context.mounted) return;

                        if (bytes == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to share image.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        await SharePlus.instance.share(
                          ShareParams(
                            files: [
                              XFile.fromData(
                                bytes,
                                name: 'StyliAI_${item.id}',
                                mimeType: GallerySaver.mimeTypeFor(item.imagePath),
                              ),
                            ],
                            text: 'Check out my ${item.styleName} photo, made with StyliAI!',
                          ),
                        );
                      },
                      style: AppButtonStyles.primary(),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ios_share_rounded),
                          const SizedBox(width: 8),
                          Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
      },
    );
  }
}
