import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_helper.dart';

/// Shows [thumbnailUrl] immediately - it's typically already warm in cache
/// from the browsing grid the user tapped in from - while [originalUrl]
/// loads in the background, then seamlessly swaps to the original the
/// moment it finishes. Used by every detail/full-screen surface so opening
/// an item never blocks on a full-resolution download.
///
/// [thumbnailUrl] and [originalUrl] are cached independently (distinct
/// [CachedNetworkImage] keys), so this never re-downloads an image the grid
/// or a previous visit already fetched.
///
/// If [thumbnailUrl] is empty or identical to [originalUrl] (a pre-backfill
/// row, or a bundled local asset with no separate thumbnail), this renders
/// [originalUrl] directly - there's nothing to progressively upgrade from.
class ProgressiveNetworkImage extends StatelessWidget {
  final String thumbnailUrl;
  final String originalUrl;
  final BoxFit fit;

  /// Bounds the decoded size (device pixels) of both layers, instead of the
  /// original decoding at its native resolution. Leave both null (the
  /// default) for a pinch-zoomable viewer, where the user can scale well
  /// past this widget's own on-screen size and native resolution is exactly
  /// what's wanted. Pass them when this renders inside a fixed-size,
  /// non-zoomable box (a hero card, a result preview, a detail sheet) - the
  /// original can never be displayed larger than that box, so decoding it
  /// at native resolution there only wastes memory and decode time.
  final int? memCacheWidth;
  final int? memCacheHeight;

  const ProgressiveNetworkImage({
    super.key,
    required this.thumbnailUrl,
    required this.originalUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final hasDistinctThumbnail = thumbnailUrl.isNotEmpty && thumbnailUrl != originalUrl;

    if (!hasDistinctThumbnail) {
      return buildStyleImage(
        originalUrl,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
      );
    }

    final isNetworkOriginal =
        originalUrl.startsWith('http://') || originalUrl.startsWith('https://');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base layer: the thumbnail, visible instantly.
        buildStyleImage(
          thumbnailUrl,
          fit: fit,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
        ),

        // Top layer: the original. While it loads, this stays fully
        // transparent (no placeholder/error widget of its own) so the
        // thumbnail underneath keeps showing through - once it's ready it
        // fades in and, being opaque, the thumbnail is no longer visible.
        if (isNetworkOriginal)
          CachedNetworkImage(
            imageUrl: originalUrl,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          )
        else
          buildStyleImage(
            originalUrl,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
          ),
      ],
    );
  }
}
