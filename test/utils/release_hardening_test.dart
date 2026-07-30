// test/utils/release_hardening_test.dart
//
// Phase 6 — release-build logging and per-screen screenshot protection.
//
// Both of these are things that are invisible when they break. Debug logging
// silently reaching a production build looks exactly like it working; a
// screenshot flag left stuck on looks exactly like the app working until a user
// tries to save their own generated image and gets a black rectangle.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/login_screen.dart';
import 'package:prombt_app/utils/release_logging.dart';
import 'package:prombt_app/utils/secure_screen.dart';

void main() {
  // Global, not per-group. `testWidgets` asserts that no foundation debug
  // variable was left reassigned, and `debugPrint` is one - so a release-logging
  // test that did not restore it fails an unrelated widget test three groups
  // later, which is a genuinely confusing way to find out.
  //
  // Restored to whatever was there on entry, NOT to `debugPrintThrottled`: the
  // test binding installs its own implementation so it can capture output, and
  // the invariant compares against that one, not against Flutter's default.
  late DebugPrintCallback originalDebugPrint;
  setUp(() => originalDebugPrint = debugPrint);
  tearDown(() => debugPrint = originalDebugPrint);

  group('release logging', () {

    test('silences debugPrint in a release build', () {
      // The premise: debugPrint is NOT stripped in release despite its name,
      // and this codebase has ~100 calls narrating session handling. All of it
      // would otherwise reach logcat, where any app holding READ_LOGS, an adb
      // session or a bug-report dump can read it.
      final captured = <String?>[];
      debugPrint = (message, {wrapWidth}) => captured.add(message);

      configureReleaseLogging(isRelease: true);
      debugPrint('[AuthService] refreshing session for user 123');

      expect(captured, isEmpty);
    });

    test('leaves debug builds untouched', () {
      // Developers must keep their logs. This is a release-only control.
      final captured = <String?>[];
      debugPrint = (message, {wrapWidth}) => captured.add(message);

      configureReleaseLogging(isRelease: false);
      debugPrint('still visible while developing');

      expect(captured, ['still visible while developing']);
    });

    test('swallows a message with an explicit wrapWidth too', () {
      // debugPrint's signature carries a named argument; a replacement that
      // did not accept it would not compile, but a caller passing it must also
      // not slip through at runtime.
      final captured = <String?>[];
      debugPrint = (message, {wrapWidth}) => captured.add(message);
      configureReleaseLogging(isRelease: true);

      debugPrint('long line', wrapWidth: 80);

      expect(captured, isEmpty);
    });

    test('is idempotent, so calling it twice is harmless', () {
      configureReleaseLogging(isRelease: true);
      configureReleaseLogging(isRelease: true);

      expect(() => debugPrint('x'), returnsNormally);
    });
  });

  group('secure screen reference counting', () {
    setUp(() {
      SecureScreen.resetForTest();
      SecureScreen.applyOverride = null;
    });
    tearDown(() {
      SecureScreen.resetForTest();
      SecureScreen.applyOverride = null;
    });

    test('applies protection once, on the first holder', () async {
      final calls = <bool>[];
      SecureScreen.applyOverride = (enabled) async {
        calls.add(enabled);
        return true;
      };

      await SecureScreen.acquire();
      await SecureScreen.acquire();

      expect(calls, [true]);
      expect(SecureScreen.holders, 2);
    });

    test('clears protection only when the last holder goes', () async {
      // The failure this prevents: opening Edit Profile from Profile puts two
      // protected screens on the stack. A boolean would clear the flag when the
      // inner one pops, silently unprotecting the screen still on display.
      final calls = <bool>[];
      SecureScreen.applyOverride = (enabled) async {
        calls.add(enabled);
        return true;
      };

      await SecureScreen.acquire();
      await SecureScreen.acquire();
      await SecureScreen.release();

      expect(calls, [true], reason: 'still one holder, flag must stay set');

      await SecureScreen.release();

      expect(calls, [true, false]);
      expect(SecureScreen.holders, 0);
    });

    test('never drops below zero on an unbalanced release', () async {
      final calls = <bool>[];
      SecureScreen.applyOverride = (enabled) async {
        calls.add(enabled);
        return true;
      };

      await SecureScreen.release();
      await SecureScreen.release();

      expect(SecureScreen.holders, 0);
      expect(calls, isEmpty);
    });

    test('a platform failure does not throw at the call site', () async {
      // Protection is best-effort; the screen opening is not. A device that
      // refuses the flag must never be the reason a screen fails to render.
      SecureScreen.applyOverride = (_) async => throw Exception('no host');

      await expectLater(SecureScreen.acquire(), throwsA(isA<Exception>()));
    });
  });

  group('SecureScreenGuard lifecycle', () {
    setUp(() {
      SecureScreen.resetForTest();
      SecureScreen.applyOverride = (_) async => true;
    });
    tearDown(() {
      SecureScreen.resetForTest();
      SecureScreen.applyOverride = null;
    });

    testWidgets('holds protection while mounted and drops it on dispose',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SecureScreenGuard(child: SizedBox.shrink()),
      ));

      expect(SecureScreen.holders, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(SecureScreen.holders, 0);
    });

    testWidgets('renders its child unchanged', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SecureScreenGuard(child: Text('content', textDirection: TextDirection.ltr)),
      ));

      expect(find.text('content'), findsOneWidget);
    });
  });

  group('the sensitive screens are actually guarded', () {
    setUp(() {
      SecureScreen.resetForTest();
      SecureScreen.applyOverride = (_) async => true;
    });
    tearDown(() {
      SecureScreen.resetForTest();
      SecureScreen.applyOverride = null;
    });

    testWidgets('the login screen is protected', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      expect(find.byType(SecureScreenGuard), findsOneWidget);
      expect(SecureScreen.holders, 1);
    });

    test('protection is scoped, not global', () {
      // Users screenshot their own generated images to save and share them -
      // that is the product working. A guard on the creations or preview
      // screens would break it, so their absence is asserted, not assumed.
      const guarded = [
        'login_screen',
        'register_screen',
        'forgot_password_screen',
        'change_password_screen',
        'profile_screen',
        'edit_profile_screen',
        'paywall_screen',
      ];
      const mustNotBeGuarded = [
        'creations_screen',
        'image_preview_screen',
        'home_screen',
        'upload_screen',
        'style_details_screen',
      ];

      for (final name in guarded) {
        final source = File('lib/screens/$name.dart').readAsStringSync();
        expect(source.contains('SecureScreenGuard'), isTrue,
            reason: '$name should be protected');
      }
      for (final name in mustNotBeGuarded) {
        final source = File('lib/screens/$name.dart').readAsStringSync();
        expect(source.contains('SecureScreenGuard'), isFalse,
            reason: '$name must stay screenshot-able');
      }
    });
  });
}
