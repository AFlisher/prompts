// test/services/feedback_prompt_service_test.dart
//
// Unit tests for FeedbackPromptService: the smart-trigger cadence (never
// after generation #1/#2, yes on #3, then every 10th after that), the
// persisted generation counter, and the askEnabled/"don't ask again" flag.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/services/feedback_prompt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FeedbackPromptService.shouldPromptForGenerationNumber (cadence)', () {
    test('never prompts on generation #1 or #2', () {
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(1), isFalse);
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(2), isFalse);
    });

    test('prompts exactly on generation #3', () {
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(3), isTrue);
    });

    test('does not prompt between #4 and #12', () {
      for (var n = 4; n < 13; n++) {
        expect(FeedbackPromptService.shouldPromptForGenerationNumber(n), isFalse, reason: 'n=$n');
      }
    });

    test('prompts every 10th generation after #3 (13, 23, 33, ...)', () {
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(13), isTrue);
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(23), isTrue);
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(33), isTrue);
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(103), isTrue);
    });

    test('does not prompt on generations between the 10-cadence marks', () {
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(14), isFalse);
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(22), isFalse);
      expect(FeedbackPromptService.shouldPromptForGenerationNumber(30), isFalse);
    });
  });

  group('FeedbackPromptService.load', () {
    test('defaults to askEnabled=true and generationCount=0 when nothing persisted', () async {
      await FeedbackPromptService.load();
      expect(FeedbackPromptService.askEnabled, isTrue);
      expect(FeedbackPromptService.generationCount, 0);
    });

    test('reads previously persisted values', () async {
      SharedPreferences.setMockInitialValues({
        'feedbackPromptAskEnabled': false,
        'feedbackPromptGenerationCount': 7,
      });
      await FeedbackPromptService.load();
      expect(FeedbackPromptService.askEnabled, isFalse);
      expect(FeedbackPromptService.generationCount, 7);
    });
  });

  group('FeedbackPromptService.setAskEnabled', () {
    test('updates the in-memory flag immediately and persists across a fresh load()', () async {
      await FeedbackPromptService.load();
      await FeedbackPromptService.setAskEnabled(false);
      expect(FeedbackPromptService.askEnabled, isFalse);

      // Simulate a restart: load() re-reads from SharedPreferences.
      FeedbackPromptService.askEnabled = true;
      await FeedbackPromptService.load();
      expect(FeedbackPromptService.askEnabled, isFalse);
    });
  });

  group('FeedbackPromptService.recordGenerationAndShouldPrompt', () {
    test('increments and persists the counter every call, prompt-eligible or not', () async {
      await FeedbackPromptService.load();

      final first = await FeedbackPromptService.recordGenerationAndShouldPrompt();
      expect(FeedbackPromptService.generationCount, 1);
      expect(first, isFalse);

      final second = await FeedbackPromptService.recordGenerationAndShouldPrompt();
      expect(FeedbackPromptService.generationCount, 2);
      expect(second, isFalse);

      final third = await FeedbackPromptService.recordGenerationAndShouldPrompt();
      expect(FeedbackPromptService.generationCount, 3);
      expect(third, isTrue);
    });

    test('persists the counter across a fresh load()', () async {
      await FeedbackPromptService.load();
      await FeedbackPromptService.recordGenerationAndShouldPrompt();
      await FeedbackPromptService.recordGenerationAndShouldPrompt();

      FeedbackPromptService.generationCount = 0;
      await FeedbackPromptService.load();
      expect(FeedbackPromptService.generationCount, 2);
    });

    test('never prompts when askEnabled is false, even on an otherwise-eligible generation', () async {
      await FeedbackPromptService.load();
      await FeedbackPromptService.setAskEnabled(false);

      FeedbackPromptService.generationCount = 2;
      final shouldPrompt = await FeedbackPromptService.recordGenerationAndShouldPrompt();

      expect(FeedbackPromptService.generationCount, 3);
      expect(shouldPrompt, isFalse);
    });

    test('re-enabling askEnabled resumes prompting on the same cadence (counter unaffected)', () async {
      await FeedbackPromptService.load();
      await FeedbackPromptService.setAskEnabled(false);
      FeedbackPromptService.generationCount = 12;
      await FeedbackPromptService.recordGenerationAndShouldPrompt(); // -> 13, suppressed by askEnabled

      await FeedbackPromptService.setAskEnabled(true);
      FeedbackPromptService.generationCount = 22;
      final shouldPrompt = await FeedbackPromptService.recordGenerationAndShouldPrompt(); // -> 23

      expect(FeedbackPromptService.generationCount, 23);
      expect(shouldPrompt, isTrue);
    });
  });
}
