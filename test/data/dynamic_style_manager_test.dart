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
        'styles_cache_v2_$categoryId': json.encode(<dynamic>[]),
        'styles_timestamp_v2_$categoryId': DateTime.now().millisecondsSinceEpoch,
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
}
