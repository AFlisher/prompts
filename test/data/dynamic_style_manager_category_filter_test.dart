// test/data/dynamic_style_manager_category_filter_test.dart
//
// Unit tests for DynamicStyleManager's Home search category filter
// (selectedCategoryFilterIds / setCategoryFilters / removeCategoryFilter /
// clearCategoryFilters). This state deliberately lives on the manager
// rather than as local State on HomeScreen, since MainShell tears down and
// rebuilds HomeScreen's State on every tab switch (KeyedSubtree keyed on
// the tab index) - only manager-level state survives navigating away and
// back, which the filter is required to do.
//
// Notifications are asserted on manager.categoryFilter (a CategoryFilterNotifier),
// not on the manager itself: DynamicStyleManager was split into independent
// per-slice ChangeNotifiers (categoryCatalog/categoryFilter/trending/
// recommended) so a filter change no longer rebuilds Categories/Trending/
// Recommended-only widgets - the manager itself never fires its own
// notifyListeners() anymore.

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DynamicStyleManager - category filter', () {
    test('starts with no filters applied', () {
      final manager = DynamicStyleManager();
      expect(manager.selectedCategoryFilterIds, isEmpty);
    });

    test('setCategoryFilters replaces the set and notifies listeners', () {
      final manager = DynamicStyleManager();
      var notifyCount = 0;
      manager.categoryFilter.addListener(() => notifyCount++);

      manager.setCategoryFilters({'cat-1', 'cat-2'});

      expect(manager.selectedCategoryFilterIds, {'cat-1', 'cat-2'});
      expect(notifyCount, 1);
    });

    test('setCategoryFilters with an unchanged set does not notify (avoids unnecessary rebuilds)', () {
      final manager = DynamicStyleManager();
      manager.setCategoryFilters({'cat-1'});

      var notifyCount = 0;
      manager.categoryFilter.addListener(() => notifyCount++);
      manager.setCategoryFilters({'cat-1'});

      expect(notifyCount, 0);
    });

    test('removeCategoryFilter removes a single id and notifies', () {
      final manager = DynamicStyleManager();
      manager.setCategoryFilters({'cat-1', 'cat-2'});

      var notifyCount = 0;
      manager.categoryFilter.addListener(() => notifyCount++);
      manager.removeCategoryFilter('cat-1');

      expect(manager.selectedCategoryFilterIds, {'cat-2'});
      expect(notifyCount, 1);
    });

    test('removeCategoryFilter on an id that is not selected does not notify', () {
      final manager = DynamicStyleManager();
      manager.setCategoryFilters({'cat-1'});

      var notifyCount = 0;
      manager.categoryFilter.addListener(() => notifyCount++);
      manager.removeCategoryFilter('cat-does-not-exist');

      expect(manager.selectedCategoryFilterIds, {'cat-1'});
      expect(notifyCount, 0);
    });

    test('clearCategoryFilters empties the set and notifies once', () {
      final manager = DynamicStyleManager();
      manager.setCategoryFilters({'cat-1', 'cat-2', 'cat-3'});

      var notifyCount = 0;
      manager.categoryFilter.addListener(() => notifyCount++);
      manager.clearCategoryFilters();

      expect(manager.selectedCategoryFilterIds, isEmpty);
      expect(notifyCount, 1);
    });

    test('clearCategoryFilters when already empty does not notify', () {
      final manager = DynamicStyleManager();

      var notifyCount = 0;
      manager.categoryFilter.addListener(() => notifyCount++);
      manager.clearCategoryFilters();

      expect(notifyCount, 0);
    });

    test('selectedCategoryFilterIds is unmodifiable from the outside', () {
      final manager = DynamicStyleManager();
      manager.setCategoryFilters({'cat-1'});

      expect(
        () => manager.selectedCategoryFilterIds.add('cat-2'),
        throwsUnsupportedError,
      );
    });
  });
}
