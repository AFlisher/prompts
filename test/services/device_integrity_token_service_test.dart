// test/services/device_integrity_token_service_test.dart
//
// SEC-0.1. The assertions that matter here are almost all negative:
// that the client never blocks, never inspects the token, never mints one it
// was not asked for, and never lets a slow or broken Play Services turn into a
// hung request. The token's meaning is Google's business and the backend's -
// see SEC-0.2.

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/services/device_integrity_token_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('styliai/play_integrity');
  late List<MethodCall> calls;

  void mockChannel({
    Object? prepareResult = true,
    Object? tokenResult = 'opaque-google-token',
    Duration? delay,
    bool throws = false,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (delay != null) await Future<void>.delayed(delay);
      if (throws) throw PlatformException(code: 'UNAVAILABLE');
      return call.method == 'prepare' ? prepareResult : tokenResult;
    });
  }

  setUp(() {
    dotenv.loadFromString(envString: 'PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=393948547098');
    calls = <MethodCall>[];
    DeviceIntegrityTokenService.resetForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('requestHashFor', () {
    test('is stable, and differs when the request differs', () {
      final a = DeviceIntegrityTokenService.requestHashFor('POST /x\nbody');
      final b = DeviceIntegrityTokenService.requestHashFor('POST /x\nbody');
      final c = DeviceIntegrityTokenService.requestHashFor('POST /x\nBODY');

      expect(a, equals(b), reason: 'the backend must be able to recompute it');
      expect(a, isNot(equals(c)));
    });

    test('is a base64url SHA-256, short enough for the API request-hash limit', () {
      final h = DeviceIntegrityTokenService.requestHashFor('anything');

      // REQUEST_HASH_TOO_LONG is a real StandardIntegrityErrorCode; a 32-byte
      // digest leaves an enormous margin, and this pins that it stays that way.
      expect(h.length, lessThan(64));
      expect(h, matches(RegExp(r'^[A-Za-z0-9_\-=]+$')));
    });
  });

  group('platform gating', () {
    test('never touches the channel on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockChannel();

      await DeviceIntegrityTokenService.warmUp();
      final token = await DeviceIntegrityTokenService.tokenFor('h');

      expect(calls, isEmpty);
      expect(token, isNull);
    });
  });

  group('token acquisition', () {
    test('returns the opaque token verbatim, unparsed', () async {
      mockChannel(tokenResult: 'a.b.c-opaque');
      await DeviceIntegrityTokenService.warmUp();

      final token = await DeviceIntegrityTokenService.tokenFor('hash-1');

      // Verbatim: the client has no business decoding, trimming or validating
      // this. Only Google can read it, and only the backend may act on it.
      expect(token, 'a.b.c-opaque');
      expect(calls.last.method, 'requestToken');
      expect(calls.last.arguments['requestHash'], 'hash-1');
    });

    test('yields no token when the provider was never prepared', () async {
      mockChannel(prepareResult: false);
      await DeviceIntegrityTokenService.warmUp();

      expect(DeviceIntegrityTokenService.prepared, isFalse);
      expect(await DeviceIntegrityTokenService.tokenFor('h'), isNull);
      expect(calls.where((c) => c.method == 'requestToken'), isEmpty);
    });
  });

  group('failure is never blocking', () {
    test('an uninitialised .env does not throw from the startup path', () async {
      // main() swallows a dotenv load failure, so `dotenv.env` can legitimately
      // be uninitialised at warm-up time - and reading it then THROWS. Guarding
      // that is the difference between "integrity is off" and "an uncaught
      // error in a post-frame callback".
      dotenv.clean();
      mockChannel();

      await expectLater(DeviceIntegrityTokenService.warmUp(), completes);

      expect(DeviceIntegrityTokenService.prepared, isFalse);
      expect(calls, isEmpty, reason: 'no channel call without configuration');
    });

    test('a throwing channel yields null rather than propagating', () async {
      DeviceIntegrityTokenService.preparedForTest = true;
      mockChannel(throws: true);

      await expectLater(DeviceIntegrityTokenService.tokenFor('h'), completes);
      expect(await DeviceIntegrityTokenService.tokenFor('h'), isNull);
    });

    test('warm-up failure never propagates', () async {
      mockChannel(throws: true);

      await expectLater(DeviceIntegrityTokenService.warmUp(), completes);
      expect(DeviceIntegrityTokenService.prepared, isFalse);
    });

    test('a hung Play Services is bounded by the token timeout', () async {
      DeviceIntegrityTokenService.preparedForTest = true;
      mockChannel(delay: DeviceIntegrityTokenService.tokenTimeout * 2);

      final sw = Stopwatch()..start();
      final token = await DeviceIntegrityTokenService.tokenFor('h');
      sw.stop();

      // The whole point: without its own timeout this would sit in front of the
      // user's tap indefinitely, because AuthorizedHttpClient's timeout only
      // wraps the HTTP call, not the header-building that precedes it.
      expect(token, isNull);
      expect(sw.elapsed, lessThan(DeviceIntegrityTokenService.tokenTimeout * 2));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
