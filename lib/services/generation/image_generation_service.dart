import 'package:flutter/foundation.dart';
import 'generation_result.dart';
import 'image_generation_config.dart';
import 'image_generation_provider.dart';
import 'nano_banana_provider.dart';
import 'stability_provider.dart';

/// The only door into image generation the rest of the app should use.
/// Screens/widgets call [generate] and never see which provider ran, what
/// endpoint it hit, or how it built its request - all of that lives behind
/// [ImageGenerationProvider] implementations, selected solely by
/// [ImageGenerationConfig.currentProvider].
///
/// To add a third provider: create a class implementing
/// [ImageGenerationProvider], add a value to [ImageGenerationProviderType],
/// and add one case below. No UI or business-logic change required.
class ImageGenerationService {
  ImageGenerationService._();

  /// Test-only escape hatch so unit tests can verify [generate] delegates
  /// correctly without a real provider/network call. Never set in app code.
  @visibleForTesting
  static ImageGenerationProvider? debugProviderOverride;

  static ImageGenerationProvider _resolveProvider() {
    if (debugProviderOverride != null) {
      return debugProviderOverride!;
    }
    switch (ImageGenerationConfig.currentProvider) {
      case ImageGenerationProviderType.nano:
        return NanoBananaProvider();
      case ImageGenerationProviderType.stability:
        return StabilityProvider();
    }
  }

  /// Generates an image using whichever provider is currently configured.
  ///
  /// [prompt] - raw prompt text (used by text-to-image providers).
  /// [styleId] - required by style-transfer providers.
  /// [imagePaths] - source photo paths (used by style-transfer providers).
  /// [fieldValues] - dynamic per-style field values (style-transfer only).
  /// [negativePrompt] - optional, used by providers that support it.
  static Future<GenerationResult> generate({
    required String prompt,
    required String styleId,
    List<String> imagePaths = const [],
    Map<String, dynamic>? fieldValues,
    String? negativePrompt,
  }) {
    return _resolveProvider().generate(
      prompt: prompt,
      styleId: styleId,
      imagePaths: imagePaths,
      fieldValues: fieldValues,
      negativePrompt: negativePrompt,
    );
  }
}
