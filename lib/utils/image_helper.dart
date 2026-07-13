import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Helper to render images from either local assets or network URLs.
///
/// [memCacheWidth]/[memCacheHeight] (device pixels) bound the size the image
/// is actually decoded at, instead of decoding the source at its full native
/// resolution. Style cover images are often much larger than the small
/// card/thumbnail boxes they're displayed in, and decoding each one at full
/// size is a common cause of scroll jank when many cards build at once -
/// callers rendering a small, known-size box (e.g. a grid/list card) should
/// always pass these.
Widget buildStyleImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? memCacheWidth,
  int? memCacheHeight,
}) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: path,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          color: AppTheme.lightGray,
          width: width,
          height: height,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppTheme.lightGray,
        width: width,
        height: height,
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: AppTheme.mediumGray,
            size: 28,
          ),
        ),
      ),
    );
  }

  return Image.asset(
    path,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: memCacheWidth,
    cacheHeight: memCacheHeight,
    errorBuilder: (context, error, stackTrace) {
      return Container(
        color: AppTheme.lightGray,
        width: width,
        height: height,
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: AppTheme.mediumGray,
            size: 28,
          ),
        ),
      );
    },
  );
}
