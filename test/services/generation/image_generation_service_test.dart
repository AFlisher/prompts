import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/services/generation/generation_result.dart';
import 'package:prombt_app/services/generation/image_generation_config.dart';
import 'package:prombt_app/services/generation/image_generation_provider.dart';
import 'package:prombt_app/services/generation/image_generation_service.dart';

class _FakeProvider implements ImageGenerationProvider {
  String? capturedPrompt;
  String? capturedStyleId;
  List<String>? capturedImagePaths;
  Map<String, dynamic>? capturedFieldValues;
  String? capturedNegativePrompt;

  Object? errorToThrow;
  GenerationResult resultToReturn = const GenerationResult(
    imageUrl: 'https://example.com/fake.webp',
    provider: ImageGenerationProviderType.stability,
  );

  @override
  Future<GenerationResult> generate({
    required String prompt,
    required String styleId,
    List<String> imagePaths = const [],
    Map<String, dynamic>? fieldValues,
    String? negativePrompt,
  }) async {
    capturedPrompt = prompt;
    capturedStyleId = styleId;
    capturedImagePaths = imagePaths;
    capturedFieldValues = fieldValues;
    capturedNegativePrompt = negativePrompt;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return resultToReturn;
  }
}

void main() {
  tearDown(() {
    // Never leak a test override into another test or the real app.
    ImageGenerationService.debugProviderOverride = null;
  });

  group('ImageGenerationConfig', () {
    test('currentProvider is stability', () {
      expect(ImageGenerationConfig.currentProvider, ImageGenerationProviderType.stability);
    });
  });

  group('ImageGenerationService.generate', () {
    test('delegates every argument to whichever provider is configured', () async {
      final fake = _FakeProvider();
      ImageGenerationService.debugProviderOverride = fake;

      final result = await ImageGenerationService.generate(
        prompt: 'a red fox in a forest',
        styleId: 'style-123',
        imagePaths: const ['/tmp/photo1.jpg', '/tmp/photo2.jpg'],
        fieldValues: const {'age': '25'},
        negativePrompt: 'blurry',
      );

      expect(fake.capturedPrompt, 'a red fox in a forest');
      expect(fake.capturedStyleId, 'style-123');
      expect(fake.capturedImagePaths, ['/tmp/photo1.jpg', '/tmp/photo2.jpg']);
      expect(fake.capturedFieldValues, {'age': '25'});
      expect(fake.capturedNegativePrompt, 'blurry');
      expect(result.imageUrl, 'https://example.com/fake.webp');
      expect(result.provider, ImageGenerationProviderType.stability);
    });

    test('works with only the required arguments (imagePaths/fieldValues/negativePrompt omitted)', () async {
      final fake = _FakeProvider();
      ImageGenerationService.debugProviderOverride = fake;

      await ImageGenerationService.generate(
        prompt: 'a small robot',
        styleId: 'style-456',
      );

      expect(fake.capturedImagePaths, isEmpty);
      expect(fake.capturedFieldValues, isNull);
      expect(fake.capturedNegativePrompt, isNull);
    });

    test('propagates errors thrown by the provider unchanged', () async {
      final fake = _FakeProvider()..errorToThrow = Exception('boom');
      ImageGenerationService.debugProviderOverride = fake;

      expect(
        () => ImageGenerationService.generate(prompt: 'x', styleId: 'y'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
