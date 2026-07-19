// test/services/haptic_service_test.dart
//
// Unit tests for HapticService: settings persistence, immediate in-session
// effect, and that `enabled` actually gates the underlying platform call.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Counts how many times the platform channel actually received a haptic
  // call, standing in for "did HapticFeedback fire" without needing a real
  // device - see MethodChannel/SystemChannels.platform in Flutter's own docs.
  int platformCallCount = 0;

  setUp(() async {
    platformCallCount = 0;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          platformCallCount++;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  group('HapticService', () {
    test('defaults to enabled before load() has run', () {
      expect(HapticService.enabled, isTrue);
    });

    test('load() reads a previously persisted false value', () async {
      SharedPreferences.setMockInitialValues({'hapticFeedbackEnabled': false});
      await HapticService.load();
      expect(HapticService.enabled, isFalse);
    });

    test('load() defaults to true when nothing has been persisted yet', () async {
      await HapticService.load();
      expect(HapticService.enabled, isTrue);
    });

    test('setEnabled updates the in-memory flag immediately', () async {
      await HapticService.load();
      await HapticService.setEnabled(false);
      expect(HapticService.enabled, isFalse);
    });

    test('setEnabled persists across a fresh load()', () async {
      await HapticService.setEnabled(false);
      // Simulate a restart: load() re-reads from SharedPreferences.
      HapticService.enabled = true;
      await HapticService.load();
      expect(HapticService.enabled, isFalse);
    });

    test('a haptic call reaches the platform when enabled', () async {
      await HapticService.setEnabled(true);
      await HapticService.vibrate();
      expect(platformCallCount, equals(1));
    });

    test('a haptic call is suppressed when disabled', () async {
      await HapticService.setEnabled(false);
      await HapticService.vibrate();
      expect(platformCallCount, equals(0));
    });

    test('every exposed method respects enabled = false', () async {
      await HapticService.setEnabled(false);
      await HapticService.selection();
      await HapticService.light();
      await HapticService.medium();
      await HapticService.heavy();
      await HapticService.vibrate();
      expect(platformCallCount, equals(0));
    });
  });
}
