import '../api_service.dart';
import 'generation_result.dart';
import 'image_generation_config.dart';
import 'image_generation_provider.dart';

/// Wraps the existing, already-in-production [ApiService.generateStyleImage]
/// call (POST /api/generate) - unchanged behavior, just routed through the
/// provider interface. Style-transfer: uses [styleId], [imagePaths] and
/// [fieldValues]; the server resolves the final prompt itself, so [prompt]
/// and [negativePrompt] are intentionally unused here.
class NanoBananaProvider implements ImageGenerationProvider {
  final ApiService _apiService;

  NanoBananaProvider({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  @override
  Future<GenerationResult> generate({
    required String prompt,
    required String styleId,
    List<String> imagePaths = const [],
    Map<String, dynamic>? fieldValues,
    String? negativePrompt,
  }) async {
    final imageUrl = await _apiService.generateStyleImage(
      imagePaths,
      styleId,
      fieldValues: fieldValues,
    );
    return GenerationResult(
      imageUrl: imageUrl,
      provider: ImageGenerationProviderType.nano,
    );
  }
}
