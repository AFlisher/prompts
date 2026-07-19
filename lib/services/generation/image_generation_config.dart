/// Every backend image-generation provider the app can route to.
/// Add a new value here when adding a new provider (step 1 of 2 - the
/// provider class itself is step 2, see [ImageGenerationService]).
enum ImageGenerationProviderType {
  nano,
  stability,
}

/// Single source of truth for which provider is active. Nothing else in the
/// app should decide this - screens and widgets call
/// [ImageGenerationService.generate] and never see this value.
class ImageGenerationConfig {
  ImageGenerationConfig._();

  static const ImageGenerationProviderType currentProvider =
      ImageGenerationProviderType.stability;
}
