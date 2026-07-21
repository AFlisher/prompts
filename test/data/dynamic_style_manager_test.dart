// test/data/dynamic_style_manager_test.dart
//
// Regression test for the empty-category reload loop: styles.isEmpty was
// being used as a proxy for "not loaded," so a category that's genuinely
// empty (loaded, confirmed zero styles) was indistinguishable from a
// never-loaded one and reloaded on every notifyListeners(). The fix adds
// CategoryModel.hasLoadedStyles as the real "has this been resolved" signal.
//
// This exercises the fix via the cache-TTL short-circuit path specifically,
// since that path never touches the network (no HTTP mocking exists for
// ApiService in this codebase) - a fresh, validly-cached empty style list
// should mark the category as loaded without any network call, which is
// exactly what used to be impossible.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DynamicStyleManager - empty category loading', () {
    test('a fresh, validly-cached empty style list marks the category as loaded', () async {
      const categoryId = 'test-empty-cat';

      SharedPreferences.setMockInitialValues({
        'categories_cache': json.encode([
          {'id': categoryId, 'name': 'Test Empty Category'}
        ]),
        // Genuinely empty, but a real (non-null) cached entry.
        'styles_cache_v3_$categoryId': json.encode(<dynamic>[]),
        'styles_timestamp_v3_$categoryId': DateTime.now().millisecondsSinceEpoch,
      });

      final manager = DynamicStyleManager();
      await manager.init();

      // Before the fix, hasLoadedStyles didn't exist and styles.isEmpty was
      // the only signal - indistinguishable from "never loaded."
      final beforeLoad = manager.categories.firstWhere((c) => c.id == categoryId);
      expect(beforeLoad.hasLoadedStyles, isFalse);
      expect(beforeLoad.styles, isEmpty);

      // This must resolve via the cache-TTL short-circuit alone (the cache
      // is fresh), never touching the network.
      await manager.loadStylesForCategory(categoryId);

      final afterLoad = manager.categories.firstWhere((c) => c.id == categoryId);
      expect(afterLoad.hasLoadedStyles, isTrue,
          reason: 'a genuinely-empty but freshly-cached category must be marked loaded, '
              'or the UI reload trigger (!hasLoadedStyles) will fire forever');
      expect(afterLoad.styles, isEmpty);

      // Calling it again (simulating the widget's reload trigger firing on
      // every rebuild) must stay resolved, not regress back to "not loaded."
      await manager.loadStylesForCategory(categoryId);
      final afterSecondLoad = manager.categories.firstWhere((c) => c.id == categoryId);
      expect(afterSecondLoad.hasLoadedStyles, isTrue);
    });
  });

  group('DynamicStyleManager - full clear on sign-out', () {
    test('clear() wipes categories/trending/recommended plus their on-disk caches', () async {
      const categoryId = 'test-clear-cat';

      SharedPreferences.setMockInitialValues({
        'categories_cache': json.encode([
          {'id': categoryId, 'name': 'Test Category'}
        ]),
        'categories_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        'styles_cache_v3_$categoryId': json.encode(<dynamic>[]),
        'styles_timestamp_v3_$categoryId': DateTime.now().millisecondsSinceEpoch,
      });

      final manager = DynamicStyleManager();
      await manager.init();
      await manager.loadStylesForCategory(categoryId);
      expect(manager.categories, isNotEmpty);

      await manager.clear();

      expect(manager.categories, isEmpty);
      expect(manager.isInitialized, isFalse,
          reason: 'must be false, not just categories empty, so the next '
              "account's MainShell.init() actually re-fetches instead of "
              'short-circuiting');
      expect(manager.trendingStyles, isEmpty);
      expect(manager.hasLoadedTrending, isFalse);
      expect(manager.recommendedStyles, isEmpty);
      expect(manager.hasLoadedRecommended, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('categories_cache'), isNull,
          reason: 'a guest signed out to the Guest Home screen must never be '
              'able to recover a stale cached catalog');
      expect(prefs.getString('styles_cache_v3_$categoryId'), isNull);
    });
  });

  group('DynamicStyleManager - fetchCategories() request deduplication', () {
    // Startup performance fix: init() (via MainShell) and HomeScreen's own
    // mount-time check can both call fetchCategories() within the same
    // cold-start window. Without deduplication that fires two concurrent
    // network requests for identical data.
    test('two concurrent plain calls share the same in-flight future', () {
      SharedPreferences.setMockInitialValues({});
      final manager = DynamicStyleManager();

      final first = manager.fetchCategories();
      final second = manager.fetchCategories();

      expect(identical(first, second), isTrue,
          reason: 'a second plain call made while the first is still in '
              'flight must reuse it, not start a redundant network request');
    });

    test('a forceRefresh call never reuses an in-flight plain fetch', () {
      SharedPreferences.setMockInitialValues({});
      final manager = DynamicStyleManager();

      final plain = manager.fetchCategories();
      final forced = manager.fetchCategories(forceRefresh: true);

      expect(identical(plain, forced), isFalse,
          reason: 'pull-to-refresh must always hit the network fresh, never '
              'silently resolve to whatever plain fetch happens to already '
              'be in flight');
    });

    test('a new plain call after the first completes fetches again (not stuck deduplicated forever)', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = DynamicStyleManager();

      final first = manager.fetchCategories();
      await first;

      final second = manager.fetchCategories();
      expect(identical(first, second), isFalse,
          reason: 'once the first fetch has completed, the dedup slot must '
              'be cleared so a later call (e.g. reopening Home) fetches '
              'again rather than being permanently stuck reusing a finished '
              'future');
    });
  });
}
