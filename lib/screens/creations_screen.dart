import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../data/creations_manager.dart';
import '../utils/gallery_saver.dart';
import '../utils/image_delivery.dart';
import '../widgets/success_hud.dart';
import '../widgets/app_bottom_sheet.dart';
import '../theme/app_button_styles.dart';
import '../services/haptic_service.dart';
import 'image_preview_screen.dart';
import '../widgets/floating_nav_bar_metrics.dart';
import '../widgets/progressive_network_image.dart';
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
                  : _buildCreationsGrid(context, creationsManager, creations, textColor),
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
            child: const Icon(
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
          const Text(
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

  /// Sprint 2 / B-6. Infinite scroll over the backend's cursor pagination.
  ///
  /// A [NotificationListener] rather than a [ScrollController] because this
  /// screen is a StatelessWidget: a controller would need a State to own and
  /// dispose it, and converting the widget for that would be a larger change
  /// than the feature. The notification carries the same metrics.
  ///
  /// The [PageStorageKey] is what preserves scroll position. Without it,
  /// switching tabs and coming back resets the user to the top of a gallery
  /// they may have paged a long way into - which, with pagination, is now a
  /// real amount of lost progress rather than a cosmetic jump.
  Widget _buildCreationsGrid(
    BuildContext context,
    CreationsManager manager,
    List<CreationItem> creations,
    Color textColor,
  ) {
    // One extra cell for the footer (spinner or end-of-list), only when there
    // is something to say.
    final showFooter = manager.hasMore || manager.isLoadingMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // depth 0 only: this grid's own scrollable, not a nested one.
        if (notification.depth != 0) return false;
        if (notification is! ScrollUpdateNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }

        final metrics = notification.metrics;
        if (!metrics.hasContentDimensions) return false;

        // Fetch a screen-height early so the next page is usually already
        // there by the time the user reaches the end.
        final remaining = metrics.maxScrollExtent - metrics.pixels;
        if (remaining <= metrics.viewportDimension) {
          // loadMore() self-guards against re-entry and against having nothing
          // left to fetch, so calling it on every scroll frame is cheap and
          // cannot stampede.
          manager.loadMore();
        }
        return false;
      },
      child: GridView.builder(
        key: const PageStorageKey<String>('creations_grid'),
        padding: const EdgeInsets.fromLTRB(
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
        itemCount: creations.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= creations.length) {
            return _buildLoadMoreFooter(manager, textColor);
          }
          final item = creations[index];
          return _buildCreationCard(context, item, textColor);
        },
      ),
    );
  }

  /// Occupies one grid cell so the loading state does not reflow the layout.
  Widget _buildLoadMoreFooter(CreationsManager manager, Color textColor) {
    return Center(
      child: manager.isLoadingMore
          ? const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(
              'Scroll for more',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
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
              // Main generated image - browsing-only, so this always uses the
              // thumbnail (falls back to the full imagePath if no thumbnail
              // exists yet). item.displayThumbnail is a full network URL for
              // backend-generated creations (any provider) and a bundled asset
              // path for pre-migration local-only ones, so this must dispatch
              // on scheme like every other image in the app instead of
              // assuming one or the other.
              // SEC-8.1B-2: keyed on the creation, not on the URL, so the
              // cached bytes survive delivery moving behind the backend.
              AuthorizedImage(
                url: item.displayThumbnail,
                builder: (headers) => buildStyleImage(
                  item.displayThumbnail,
                  fit: BoxFit.cover,
                  cacheKey: creationCacheKey(item.id, thumbnail: true),
                  httpHeaders: headers,
                ),
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
                        thumbnailPath: item.displayThumbnail,
                        title: item.styleName,
                        creationId: item.id,
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
                        // Styled generation output photo - progressive: the
                        // thumbnail (already cached from the grid) shows
                        // immediately while the full-resolution original
                        // loads in behind it. This box is a fixed 340px-tall
                        // card, never zoomable itself (tapping it opens a
                        // separate ImagePreviewScreen, which decodes its own
                        // full-res copy independently) - so the original only
                        // needs decoding at this box's actual on-screen size.
                        // Width matches showAppBottomSheet's default
                        // horizontal padding (24px each side).
                        // SEC-8.1B-2: same credential requirement as the grid
                        // card above - without it the original layer 401s and
                        // this card never upgrades past the thumbnail.
                        AuthorizedImage(
                          url: item.imagePath,
                          builder: (headers) => ProgressiveNetworkImage(
                            thumbnailUrl: item.displayThumbnail,
                            originalUrl: item.imagePath,
                            thumbnailCacheKey:
                                creationCacheKey(item.id, thumbnail: true),
                            originalCacheKey:
                                creationCacheKey(item.id, thumbnail: false),
                            fit: BoxFit.cover,
                            memCacheWidth: ((MediaQuery.sizeOf(context).width - 48) *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                            memCacheHeight:
                                (340 * MediaQuery.devicePixelRatioOf(context)).round(),
                            httpHeaders: headers,
                          ),
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
                        // SEC-8.1B-2: loadImageBytes attaches credentials when
                        // the URL is ours and reports the server's own content
                        // type, which a stable backend URL carries no
                        // extension to guess from.
                        final loaded =
                            await GallerySaver.loadImageBytes(item.imagePath);
                        final bytes = loaded?.bytes;

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
                                mimeType: GallerySaver.mimeTypeFor(
                                  item.imagePath,
                                  serverContentType: loaded?.contentType,
                                ),
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
                          SizedBox(width: 8),
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
