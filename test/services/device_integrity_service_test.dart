// test/services/device_integrity_service_test.dart
//
// Unit tests for SEC-13.4's DeviceIntegrityService.
//
// The security-relevant assertions here are the negative ones: that the
// service is Android-only, that a failing plugin cannot break the app, and
// that the emulator probe is never called at all. The root detection itself
// is the plugin's job and is not re-tested here.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/services/device_integrity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('safe_device');

  // Records what the service actually asked the platform, so "did it run at
  // all" is observable without a device - same approach as
  // haptic_service_test.dart.
  late List<String> calls;

  void mockPlatform({required bool jailBroken, required bool realDevice}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isJailBroken':
          return jailBroken;
        case 'isRealDevice':
          return realDevice;
        default:
          return null;
      }
    });
  }

  setUp(() {
    calls = <String>[];
    SharedPreferences.setMockInitialValues({});
    DeviceIntegrityService.resetForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('platform gating', () {
    test('does nothing on iOS - SEC-13.4 is Android-only', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockPlatform(jailBroken: true, realDevice: true);

      await DeviceIntegrityService.check();

      expect(calls, isEmpty, reason: 'no platform call may be made on iOS');
      expect(DeviceIntegrityService.isRooted, isFalse);
      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });

    test('does nothing on desktop/other platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      mockPlatform(jailBroken: true, realDevice: true);

      await DeviceIntegrityService.check();

      expect(calls, isEmpty);
      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });
  });

  group('detection', () {
    test('records a rooted device and offers the notice once', () async {
      mockPlatform(jailBroken: true, realDevice: true);

      await DeviceIntegrityService.check();

      expect(calls, contains('isJailBroken'));
      expect(DeviceIntegrityService.isRooted, isTrue);
      expect(DeviceIntegrityService.shouldShowNotice, isTrue);

      await DeviceIntegrityService.markNoticeShown();
      expect(DeviceIntegrityService.shouldShowNotice, isFalse,
          reason: 'the notice is once per install, not once per launch');
    });

    test('a clean device produces no notice', () async {
      mockPlatform(jailBroken: false, realDevice: true);

      await DeviceIntegrityService.check();

      expect(DeviceIntegrityService.isRooted, isFalse);
      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });

    test('an acknowledged notice stays acknowledged across a restart', () async {
      SharedPreferences.setMockInitialValues({'deviceIntegrityNoticeShown': true});
      mockPlatform(jailBroken: true, realDevice: true);

      await DeviceIntegrityService.check();

      expect(DeviceIntegrityService.isRooted, isTrue);
      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });
  });

  group('emulator detection is not collected at all', () {
    test('isRealDevice is never probed', () async {
      // Emulator detection was deliberately dropped - see the field doc on
      // isRooted. Two reasons, and the second is why this is a test and not a
      // comment: SafeDevice.isRealDevice swallows platform exceptions and
      // returns false, so `!isRealDevice` reports "emulator" for a probe that
      // merely broke. Asserting the call is never made is stronger than
      // asserting its result is ignored, because it cannot rot.
      mockPlatform(jailBroken: false, realDevice: false);

      await DeviceIntegrityService.check();

      expect(calls, contains('isJailBroken'));
      expect(calls, isNot(contains('isRealDevice')));
      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });

    test('an emulator that is not rooted produces no notice', () async {
      mockPlatform(jailBroken: false, realDevice: false);

      await DeviceIntegrityService.check();

      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });
  });

  group('failure handling', () {
    test('a throwing plugin leaves the defaults and never propagates', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });

      // The whole point: a courtesy notice must never be able to break launch.
      await expectLater(DeviceIntegrityService.check(), completes);

      expect(DeviceIntegrityService.isRooted, isFalse);
      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });

    test('a missing plugin implementation is survivable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await expectLater(DeviceIntegrityService.check(), completes);

      expect(DeviceIntegrityService.shouldShowNotice, isFalse);
    });
  });
}
