import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Helper to render images from either local assets or network URLs.
Widget buildStyleImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: path,
      fit: fit,
      width: width,
      height: height,
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
