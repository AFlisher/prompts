import '../api_service.dart';
import 'generation_result.dart';
import 'image_generation_config.dart';
import 'image_generation_provider.dart';

/// Wraps [ApiService.generateStabilityImage] (POST /api/ai/generate) -
/// text-to-image only. [styleId], [imagePaths] and [fieldValues] are
/// intentionally unused: the backend endpoint doesn't accept a source image
/// or a style/field-template, only a raw prompt.
class StabilityProvider implements ImageGenerationProvider {
  final ApiService _apiService;

  StabilityProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  @override
  Future<GenerationResult> generate({
    required String prompt,
    required String styleId,
    List<String> imagePaths = const [],
    Map<String, dynamic>? fieldValues,
    String? negativePrompt,
  }) async {
    final imageUrl = await _apiService.generateStabilityImage(
      prompt,
      negativePrompt: negativePrompt,
    );
    return GenerationResult(
      imageUrl: imageUrl,
      provider: ImageGenerationProviderType.stability,
    );
  }
}
