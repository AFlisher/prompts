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

  const GenerationResult({
    required this.imageUrl,
    this.thumbnailUrl,
    required this.provider,
  });
}
