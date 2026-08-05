import 'generation_result.dart';

/// A single backend AI image-generation provider. Every provider accepts
/// the full set of inputs the app's upload flow can supply and is free to
/// ignore whichever ones it doesn't use (e.g. a text-to-image provider
/// ignores [imagePaths]; a style-transfer provider ignores [prompt]) -
/// callers never need to know which.
abstract class ImageGenerationProvider {
  Future<GenerationResult> generate({
    required String prompt,
    required String styleId,
    List<String> imagePaths = const [],
    Map<String, dynamic>? fieldValues,
    String? negativePrompt,
    /// Sprint 2 / B-5. Reused across retries of the same logical generation so
    /// a lost response cannot become a second charge. Providers forward it
    /// unchanged; only the charged backend endpoints act on it.
    String? idempotencyKey,
  });
}
