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
class ProgressiveNetworkImage extends StatefulWidget {
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

  static const Duration _fadeInDuration = Duration(milliseconds: 250);

  const ProgressiveNetworkImage({
    super.key,
    required this.thumbnailUrl,
    required this.originalUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  State<ProgressiveNetworkImage> createState() => _ProgressiveNetworkImageState();
}

class _ProgressiveNetworkImageState extends State<ProgressiveNetworkImage> {
  // Whether the thumbnail layer should still be in the tree at all. Not
  // just an opacity/paint-order question: BoxFit.contain/cover each
  // independently letterbox to *their own* image's aspect ratio, so once
  // thumbnailUrl (a fixed-ratio server-generated crop) and originalUrl (the
  // source's real aspect ratio) differ, the original's content rect doesn't
  // necessarily cover the thumbnail's - painting the original opaquely on
  // top is not enough to hide it, it has to leave the tree.
  bool _hideThumbnail = false;
  bool _hideScheduled = false;

  @override
  void didUpdateWidget(covariant ProgressiveNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originalUrl != widget.originalUrl) {
      // A different original to load - show the thumbnail again underneath
      // it until this one is ready, same as a fresh mount.
      _hideThumbnail = false;
      _hideScheduled = false;
    }
  }

  /// Called once [ProgressiveNetworkImage.originalUrl] has a decoded frame
  /// ready to paint. Waits exactly [ProgressiveNetworkImage._fadeInDuration]
  /// - the same duration the original's own [CachedNetworkImage.fadeInDuration]
  /// below animates its fade-in over - so the thumbnail stays in place for
  /// that crossfade and is only removed once the original has fully settled
  /// at opacity 1, instead of lingering underneath it forever.
  void _scheduleHideThumbnail() {
    if (_hideThumbnail || _hideScheduled) return;
    _hideScheduled = true;
    Future.delayed(ProgressiveNetworkImage._fadeInDuration, () {
      if (mounted) setState(() => _hideThumbnail = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = widget.thumbnailUrl;
    final originalUrl = widget.originalUrl;
    final fit = widget.fit;
    final memCacheWidth = widget.memCacheWidth;
    final memCacheHeight = widget.memCacheHeight;

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
        // Base layer: the thumbnail, visible instantly - only while the
        // original hasn't finished loading yet (see _scheduleHideThumbnail).
        if (!_hideThumbnail)
          buildStyleImage(
            thumbnailUrl,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
          ),

        // Top layer: the original. While it loads, this stays fully
        // transparent (no placeholder/error widget of its own) so the
        // thumbnail underneath keeps showing through - once it's ready it
        // fades in, and the thumbnail is dropped from the tree entirely
        // shortly after (not just painted over - see _hideThumbnail above).
        if (isNetworkOriginal)
          CachedNetworkImage(
            imageUrl: originalUrl,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            fadeInDuration: ProgressiveNetworkImage._fadeInDuration,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
            imageBuilder: (context, imageProvider) {
              _scheduleHideThumbnail();
              return Image(image: imageProvider, fit: fit);
            },
          )
        else
          // Local-asset original with a distinct thumbnail (e.g. a legacy
          // style with no imageUrl, falling back to a bundled asset path).
          // Rare enough in practice that this branch keeps the pre-fix
          // behavior - the thumbnail isn't dropped from the tree here - but
          // it's worth noting it carries the same theoretical exposure this
          // fix addresses for the network case above.
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
