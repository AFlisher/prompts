import '../api_service.dart';
import 'generation_result.dart';
import 'image_generation_config.dart';
import 'image_generation_provider.dart';

/// Wraps [ApiService.generateStabilityImage] (POST /api/ai/generate) -
/// text-to-image only. [imagePaths] and [fieldValues] are intentionally
/// unused: the backend endpoint doesn't accept a source image or a
/// field-template. [prompt] is normally empty (the client never receives a
/// style's real prompt text - see [ApiService.generateStabilityImage]), so
/// [styleId] is forwarded and the backend resolves the prompt itself.
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
    final result = await _apiService.generateStabilityImage(
      prompt: prompt,
      styleId: styleId,
      negativePrompt: negativePrompt,
    );
    return GenerationResult(
      imageUrl: result.imageUrl,
      thumbnailUrl: result.thumbnailUrl,
      provider: ImageGenerationProviderType.stability,
    );
  }
}
