import 'image_generation_config.dart';

/// Result of a successful [ImageGenerationProvider.generate] call.
/// [provider] is stamped on by [ImageGenerationService], not by individual
/// providers, so it always reflects which one actually ran.
class GenerationResult {
  final String imageUrl;

  /// ~320x400 WebP browsing thumbnail of [imageUrl], generated server-side.
  /// Null if the backend couldn't produce one - callers should fall back to
  /// [imageUrl] in that case.
  final String? thumbnailUrl;
  final ImageGenerationProviderType provider;

  /// The creations row id the backend recorded for this generation, if the
  /// server-side history write succeeded. Round-tripped back on the
  /// post-generation feedback submission (POST /api/feedback). Only
  /// populated for style-transfer generations - null for text-to-image.
  final String? generationId;

  /// The generated style's category id, for the same feedback round-trip.
  final String? categoryId;

  /// Server-side AI provider call duration in milliseconds, for the same
  /// feedback round-trip.
  final int? generationTimeMs;

  const GenerationResult({
    required this.imageUrl,
    this.thumbnailUrl,
    required this.provider,
    this.generationId,
    this.categoryId,
    this.generationTimeMs,
  });
}
