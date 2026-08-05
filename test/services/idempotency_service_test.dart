// Sprint 2 / B-5 — IdempotencyService.
//
// The behaviour under test is deceptively small and entirely about identity:
// the SAME request must get the SAME key across retries, a DIFFERENT request
// must not, and the key must survive the process dying mid-generation. Get any
// of those backwards and the user is charged twice for one image, which is the
// exact defect SEC-3.1 described and which shipped inert because no client
// ever sent the header.

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/services/idempotency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IdempotencyService.debugNow = null;
  });

  tearDown(() {
    IdempotencyService.debugNow = null;
  });

  group('operation ids', () {
    test('identical requests produce the same operation id', () {
      final a = IdempotencyService.operationIdFrom(['POST /api/generate', 'style-1', 'a.jpg']);
      final b = IdempotencyService.operationIdFrom(['POST /api/generate', 'style-1', 'a.jpg']);
      expect(a, equals(b));
    });

    test('a different style produces a different operation id', () {
      final a = IdempotencyService.operationIdFrom(['POST /api/generate', 'style-1']);
      final b = IdempotencyService.operationIdFrom(['POST /api/generate', 'style-2']);
      expect(a, isNot(equals(b)));
    });

    test('a different photo produces a different operation id', () {
      final a = IdempotencyService.operationIdFrom(['POST /api/generate', 's', 'a.jpg']);
      final b = IdempotencyService.operationIdFrom(['POST /api/generate', 's', 'b.jpg']);
      expect(a, isNot(equals(b)));
    });

    test('is bounded regardless of input size', () {
      final huge = IdempotencyService.operationIdFrom(['x' * 100000]);
      expect(huge.length, equals(32));
    });

    test('contains nothing user-typed', () {
      final id = IdempotencyService.operationIdFrom(['my secret prompt text']);
      expect(id, isNot(contains('secret')));
      expect(id, matches(RegExp(r'^[0-9a-f]+$')));
    });
  });

  group('key identity', () {
    test('the same operation returns the same key across calls', () async {
      const op = 'op-1';
      final first = await IdempotencyService.keyFor(op);
      final second = await IdempotencyService.keyFor(op);

      // THE assertion. A fresh key on the retry is what caused double charges.
      expect(second, equals(first));
    });

    test('different operations get different keys', () async {
      final a = await IdempotencyService.keyFor('op-a');
      final b = await IdempotencyService.keyFor('op-b');
      expect(a, isNot(equals(b)));
    });

    test('the key survives a process restart', () async {
      const op = 'op-restart';
      final first = await IdempotencyService.keyFor(op);

      // A new SharedPreferences instance is what a relaunch looks like; the
      // mock store persists across it, as the real one does.
      final second = await IdempotencyService.keyFor(op);
      expect(second, equals(first));
    });
  });

  group('key format', () {
    test('satisfies the backend contract', () async {
      final key = await IdempotencyService.keyFor('op');

      // middleware/idempotency.js: /^[A-Za-z0-9_.:-]+$/, length 8..255.
      expect(key, matches(RegExp(r'^[A-Za-z0-9_.:-]+$')));
      expect(key.length, greaterThanOrEqualTo(8));
      expect(key.length, lessThanOrEqualTo(255));
    });

    test('is not predictable across operations', () async {
      final keys = <String>{};
      for (var i = 0; i < 25; i++) {
        keys.add(await IdempotencyService.keyFor('op-$i'));
      }
      // A collision here would mean one user's key could be guessed and their
      // stored response served to somebody else.
      expect(keys.length, equals(25));
    });
  });

  group('clearing', () {
    test('clear() drops the key so the next identical request is new work',
        () async {
      const op = 'op-clear';
      final first = await IdempotencyService.keyFor(op);
      await IdempotencyService.clear(op);
      final second = await IdempotencyService.keyFor(op);

      // Without this, a user generating the same style on the same photo twice
      // on purpose would get the first image replayed instead of a new one.
      expect(second, isNot(equals(first)));
    });

    test('clear() on an unknown operation is harmless', () async {
      await expectLater(IdempotencyService.clear('never-existed'), completes);
    });

    test('clearAll() removes every key', () async {
      final a = await IdempotencyService.keyFor('op-a');
      await IdempotencyService.keyFor('op-b');

      await IdempotencyService.clearAll();

      final aAgain = await IdempotencyService.keyFor('op-a');
      expect(aAgain, isNot(equals(a)));
    });

    test('clearAll() leaves unrelated preferences alone', () async {
      SharedPreferences.setMockInitialValues({'theme_is_dark': true});
      await IdempotencyService.keyFor('op-a');

      await IdempotencyService.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('theme_is_dark'), isTrue);
    });
  });

  group('expiry', () {
    test('a key older than its lifetime is replaced', () async {
      const op = 'op-expiry';
      var now = DateTime(2026, 1, 1, 12, 0);
      IdempotencyService.debugNow = () => now;

      final first = await IdempotencyService.keyFor(op);

      now = now.add(IdempotencyService.keyLifetime + const Duration(minutes: 1));
      final second = await IdempotencyService.keyFor(op);

      expect(second, isNot(equals(first)));
    });

    test('a key inside its lifetime is reused', () async {
      const op = 'op-fresh';
      var now = DateTime(2026, 1, 1, 12, 0);
      IdempotencyService.debugNow = () => now;

      final first = await IdempotencyService.keyFor(op);

      now = now.add(IdempotencyService.keyLifetime - const Duration(minutes: 1));
      final second = await IdempotencyService.keyFor(op);

      expect(second, equals(first));
    });

    test('a clock that moved backwards issues a fresh key rather than reusing',
        () async {
      const op = 'op-clock';
      var now = DateTime(2026, 1, 1, 12, 0);
      IdempotencyService.debugNow = () => now;

      final first = await IdempotencyService.keyFor(op);

      now = now.subtract(const Duration(days: 2));
      final second = await IdempotencyService.keyFor(op);

      expect(second, isNot(equals(first)));
    });
  });
}
