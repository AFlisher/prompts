// test/data/profile_manager_test.dart
//
// Startup performance fix: ProfileManager.loadProfile() only guarded against
// "already loaded" (`_profile != null`), not "already in flight" - so two
// near-simultaneous callers (MainShell's startup init and ProfileScreen's
// own mount-time call) could each see `_profile` still null and both fire a
// network request. The fix adds an `_isLoading` check to the guard.
//
// Dart async functions run synchronously up to their first `await`, so
// calling loadProfile() without awaiting it still executes the guard check
// and the first notifyListeners() call synchronously before returning - that
// lets this test observe the in-flight state without needing to mock
// ProfileService (which isn't constructor-injectable in ProfileManager).

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/profile_manager.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ProfileManager - loadProfile() request deduplication', () {
    test('a second plain call while the first is still in flight does not re-fetch', () async {
      final manager = ProfileManager();
      var notifyCount = 0;
      manager.addListener(() => notifyCount++);

      final first = manager.loadProfile();
      expect(manager.isLoading, isTrue,
          reason: 'the synchronous prefix of loadProfile() must have run '
              'before this line, since nothing was awaited yet');
      final notifyCountAfterFirstStarts = notifyCount;

      final second = manager.loadProfile();
      expect(notifyCount, equals(notifyCountAfterFirstStarts),
          reason: 'the second call must hit the guard and return immediately '
              '(no extra notifyListeners) instead of re-entering the fetch '
              'while the first is still in flight');

      await first;
      await second;
    });

    test('force: true always bypasses the guard, even mid-flight', () async {
      final manager = ProfileManager();
      var notifyCount = 0;
      manager.addListener(() => notifyCount++);

      final first = manager.loadProfile();
      final notifyCountAfterFirstStarts = notifyCount;

      // Unlike the plain case above, force:true must still re-enter and
      // notify again - this is the profile error state's explicit Retry
      // button, which must never silently no-op.
      final forced = manager.loadProfile(force: true);
      expect(notifyCount, greaterThan(notifyCountAfterFirstStarts),
          reason: 'force:true must run fresh regardless of an in-flight '
              'plain fetch');

      await first;
      await forced;
    });

    test('the in-flight guard is cleared once the first call completes, not stuck forever', () async {
      final manager = ProfileManager();
      await manager.loadProfile();
      // No live Supabase session in this test environment, so this resolves
      // via the error path (loadProfile()'s own try/catch) rather than a
      // successful fetch - `_profile` stays null either way. What this test
      // actually verifies is narrower and unrelated to that: the in-flight
      // guard (`_isLoading`) must not still be true after the call settles.
      expect(manager.isLoading, isFalse);

      var notifyCount = 0;
      manager.addListener(() => notifyCount++);

      // A later plain call must still be able to run (not permanently
      // no-op'd by a guard that never got reset).
      await manager.loadProfile();
      expect(notifyCount, greaterThan(0),
          reason: 'a call made after the previous one fully settled must '
              'still be able to fetch - the in-flight guard is only meant '
              'to dedupe truly *concurrent* calls, not block all future ones');
    });
  });
}
