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
/// [cacheKey] decouples the cache entry from the URL string (SEC-8.1B-2).
/// Leave it null for catalog images, whose URLs are permanent and public;
/// pass one for user creations, whose URLs are going to change form. See
/// [creationCacheKey].
///
/// [httpHeaders] is forwarded to `CachedNetworkImage` and should come from
/// [imageAuthHeaders], which returns nothing at all for a URL that is not
/// ours - so today this stays null and the request is unchanged.
Widget buildStyleImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? memCacheWidth,
  int? memCacheHeight,
  String? cacheKey,
  Map<String, String>? httpHeaders,
}) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: path,
      cacheKey: cacheKey,
      httpHeaders: httpHeaders,
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
