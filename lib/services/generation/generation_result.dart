import 'image_generation_config.dart';

/// Result of a successful [ImageGenerationProvider.generate] call.
/// [provider] is stamped on by [ImageGenerationService], not by individual
/// providers, so it always reflects which one actually ran.
class GenerationResult {
  final String imageUrl;
  final ImageGenerationProviderType provider;

  const GenerationResult({
    required this.imageUrl,
    required this.provider,
  });
}
