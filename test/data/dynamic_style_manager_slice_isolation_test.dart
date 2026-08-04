// test/data/dynamic_style_manager_slice_isolation_test.dart
//
// DynamicStyleManager used to be one large ChangeNotifier: any mutation
// (categories, filters, trending, or recommended) called the same
// notifyListeners(), so every listener - regardless of which slice of data
// it actually cared about - rebuilt on every change. This suite proves the
// fix directly at the manager level: each slice (categoryCatalog/
// categoryFilter/trending/recommended) is now its own independent
// ChangeNotifier, so mutating one slice notifies *only* that slice's own
// listeners, leaving the other three untouched.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DynamicStyleManager - slice notification isolation', () {
    late DynamicStyleManager manager;
    late int categoryCatalogNotifications;
    late int categoryFilterNotifications;
    late int trendingNotifications;
    late int recommendedNotifications;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = DynamicStyleManager();
      categoryCatalogNotifications = 0;
      categoryFilterNotifications = 0;
      trendingNotifications = 0;
      recommendedNotifications = 0;

      manager.categoryCatalog.addListener(() => categoryCatalogNotifications++);
      manager.categoryFilter.addListener(() => categoryFilterNotifications++);
      manager.trending.addListener(() => trendingNotifications++);
      manager.recommended.addListener(() => recommendedNotifications++);
    });

    test(
      'Scenario 1 - categories loading notifies only categoryCatalog',
      () async {
        const categoryId = 'isolation-test-cat';
        SharedPreferences.setMockInitialValues({
          'categories_cache': json.encode([
            {'id': categoryId, 'name': 'Isolation Test Category'}
          ]),
          'categories_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        // Re-create with the seeded cache in place (setUp already attached
        // listeners to a manager built before the cache existed).
        manager = DynamicStyleManager();
        categoryCatalogNotifications = 0;
        categoryFilterNotifications = 0;
        trendingNotifications = 0;
        recommendedNotifications = 0;
        manager.categoryCatalog.addListener(() => categoryCatalogNotifications++);
        manager.categoryFilter.addListener(() => categoryFilterNotifications++);
        manager.trending.addListener(() => trendingNotifications++);
        manager.recommended.addListener(() => recommendedNotifications++);

        await manager.init();

        expect(categoryCatalogNotifications, greaterThan(0),
            reason: 'categories loaded - categoryCatalog must notify');
        expect(categoryFilterNotifications, 0,
            reason: 'unrelated to categories loading - must not notify');
        expect(trendingNotifications, 0,
            reason: 'unrelated to categories loading - must not notify');
        expect(recommendedNotifications, 0,
            reason: 'unrelated to categories loading - must not notify');
      },
    );

    test(
      'Scenario 2 - trending refreshing notifies only trending',
      () async {
        await manager.loadTrendingStyles();

        expect(trendingNotifications, greaterThan(0),
            reason: 'trending refreshed - trending must notify');
        expect(categoryCatalogNotifications, 0,
            reason: 'unrelated to trending - must not notify');
        expect(categoryFilterNotifications, 0,
            reason: 'unrelated to trending - must not notify');
        expect(recommendedNotifications, 0,
            reason: 'unrelated to trending - must not notify');
      },
    );

    test(
      'Scenario 3 - recommended updating notifies only recommended',
      () async {
        await manager.loadRecommendedStyles();

        expect(recommendedNotifications, greaterThan(0),
            reason: 'recommended updated - recommended must notify');
        expect(categoryCatalogNotifications, 0,
            reason: 'unrelated to recommended - must not notify');
        expect(categoryFilterNotifications, 0,
            reason: 'unrelated to recommended - must not notify');
        expect(trendingNotifications, 0,
            reason: 'unrelated to recommended - must not notify');
      },
    );

    test(
      'Scenario 4 - filter changes notify only categoryFilter',
      () {
        manager.setCategoryFilters({'cat-1', 'cat-2'});

        expect(categoryFilterNotifications, greaterThan(0),
            reason: 'filters changed - categoryFilter must notify');
        expect(categoryCatalogNotifications, 0,
            reason: 'unrelated to filters - must not notify');
        expect(trendingNotifications, 0,
            reason: 'unrelated to filters - must not notify');
        expect(recommendedNotifications, 0,
            reason: 'unrelated to filters - must not notify');
      },
    );

    test(
      'clear() notifies categoryCatalog, trending, and recommended - each independently',
      () async {
        await manager.clear();

        expect(categoryCatalogNotifications, greaterThan(0));
        expect(trendingNotifications, greaterThan(0));
        expect(recommendedNotifications, greaterThan(0));
        // Filters aren't part of clear() - logging out doesn't touch the
        // active Home category filter selection.
        expect(categoryFilterNotifications, 0);
      },
    );

    test(
      'DynamicStyleManager itself never fires its own notifyListeners() - '
      'only the four slices do',
      () async {
        var managerNotifications = 0;
        manager.addListener(() => managerNotifications++);

        manager.setCategoryFilters({'cat-1'});
        await manager.loadTrendingStyles();
        await manager.loadRecommendedStyles();
        await manager.clear();

        expect(managerNotifications, 0,
            reason: 'all real notifications now flow through the four '
                'slice notifiers, not the umbrella manager - a widget still '
                'listening to StyleProvider.of(context) directly would '
                'never rebuild, which is why every consumer was migrated '
                'to listen to the specific slice it needs instead');
      },
    );
  });
}
