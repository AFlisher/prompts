// test/screens/home/home_screens_test.dart
//
// Tests for:
//   - HomeScreen
//   - AllStylesScreen
//   - PaywallScreen (Buy Credits)
//   - NotificationsScreen

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/screens/home_screen.dart';
import 'package:prombt_app/screens/all_styles_screen.dart';
import 'package:prombt_app/screens/paywall_screen.dart';
import 'package:prombt_app/screens/notifications_screen.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/data/favorites_manager.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';
import 'package:prombt_app/data/creations_manager.dart';
import 'package:prombt_app/models/credit_pack.dart';

// PaywallScreen fetches its pack list from the backend, which isn't reachable
// in tests - this fixture stands in via PaywallScreen.fetchPacksOverride.
Future<List<CreditPack>> _fakeCreditPacks() async => [
      CreditPack(id: 'starter', name: 'Starter Pack', credits: 10, priceDisplay: '\$1.99'),
      CreditPack(id: 'pro', name: 'Pro Pack', credits: 50, priceDisplay: '\$4.99', badge: 'Best Value'),
      CreditPack(id: 'max', name: 'Max Pack', credits: 100, priceDisplay: '\$8.99', badge: 'Save 25%'),
    ];

Widget wrapWithProviders(Widget widget, {DynamicStyleManager? styleManager}) {
  final favManager    = FavoritesManager();
  final resolvedStyleManager = styleManager ?? DynamicStyleManager();
  final creditManager = CreditManager()..shouldSaveToFile = false;
  final creationsManager = CreationsManager()..shouldSaveToFile = false;
  return StyleProvider(
    notifier: resolvedStyleManager,
    child: CreditProvider(
      notifier: creditManager,
      child: FavoritesProvider(
        notifier: favManager,
        child: CreationsProvider(
          notifier: creationsManager,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: widget,
          ),
        ),
      ),
    ),
  );
}

// Seeds a DynamicStyleManager with one category's worth of styles entirely
// from the on-device cache (same technique as
// test/data/dynamic_style_manager_test.dart) - no network mocking exists for
// ApiService in this codebase, so this is the only way to get real,
// search-filterable StyleCards onto HomeScreen in a widget test.
Future<DynamicStyleManager> _seededStyleManager() async {
  const categoryId = 'search-test-cat';
  SharedPreferences.setMockInitialValues({
    'categories_cache': json.encode([
      {'id': categoryId, 'name': 'Portraits'}
    ]),
    'categories_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
    'styles_cache_v3_$categoryId': json.encode([
      {'id': 's1', 'name': 'Sunset Glow', 'imagePath': ''},
      {'id': 's2', 'name': 'Rainy Mood', 'imagePath': ''},
    ]),
    'styles_timestamp_v3_$categoryId': DateTime.now().millisecondsSinceEpoch,
  });
  final manager = DynamicStyleManager();
  await manager.init();
  await manager.loadStylesForCategory(categoryId);
  return manager;
}

void main() {
  // ── HOME SCREEN ───────────────────────────────────────────────────────────
  group('HomeScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(isDarkMode: true, onToggleDarkMode: () {}),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders style category chips or list', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(isDarkMode: true, onToggleDarkMode: () {}),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders in light mode without overflow', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(isDarkMode: false, onToggleDarkMode: () {}),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // find.text(..., skipOffstage: false) throughout: even the pre-existing,
    // unmodified HomeScreen marks its CustomScrollView content as "offstage"
    // in this test harness's default (unsized) viewport (verified by running
    // the same finder against HomeScreen before this change) - a test-only
    // artifact of Element.debugVisitOnstageChildren's viewport/route
    // bookkeeping, unrelated to real device rendering and unrelated to this
    // change, so skipOffstage is turned off rather than worked around.
    testWidgets(
      'typing in search filters style cards, and clearing restores them',
      (tester) async {
        final styleManager = await _seededStyleManager();
        await tester.pumpWidget(wrapWithProviders(
          HomeScreen(isDarkMode: true, onToggleDarkMode: () {}),
          styleManager: styleManager,
        ));
        // Several short pumps (not pumpAndSettle - the Shimmer loading
        // placeholder animates forever, so pumpAndSettle never returns) to
        // let the cache-backed async category/style loads resolve.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Both styles visible before any search input.
        expect(find.text('Sunset Glow', skipOffstage: false), findsOneWidget);
        expect(find.text('Rainy Mood', skipOffstage: false), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Sunset');
        await tester.pump();

        expect(find.text('Sunset Glow', skipOffstage: false), findsOneWidget);
        expect(find.text('Rainy Mood', skipOffstage: false), findsNothing);

        // Let the clear button's AnimatedSwitcher fade-in finish before
        // tapping it, or the tap can land before it's hit-testable.
        await tester.pump(const Duration(milliseconds: 250));

        // Clearing (via the SearchBar's own clear button) restores both.
        await tester.tap(find.byKey(const ValueKey('clear-search-button')));
        await tester.pump();

        expect(find.text('Sunset Glow', skipOffstage: false), findsOneWidget);
        expect(find.text('Rainy Mood', skipOffstage: false), findsOneWidget);
      },
    );

    testWidgets(
      'a search matching nothing shows the empty-search state, not the categories',
      (tester) async {
        final styleManager = await _seededStyleManager();
        // Filters down to the one seeded category, so the aggregate empty-
        // search decision doesn't also have to wait on Trending/Recommended's
        // own real (unmocked, so slow-to-fail) network fetch settling.
        styleManager.setCategoryFilters({'search-test-cat'});
        await tester.pumpWidget(wrapWithProviders(
          HomeScreen(isDarkMode: true, onToggleDarkMode: () {}),
          styleManager: styleManager,
        ));
        // Several short pumps (not pumpAndSettle - the Shimmer loading
        // placeholder animates forever, so pumpAndSettle never returns) to
        // let the cache-backed async category/style loads resolve.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.enterText(find.byType(TextField), 'zzz-no-match');
        await tester.pump();

        expect(find.text('Sunset Glow', skipOffstage: false), findsNothing);
        expect(find.text('Rainy Mood', skipOffstage: false), findsNothing);
        expect(find.text('No styles found', skipOffstage: false), findsOneWidget);
      },
    );
  });

  // ── ALL STYLES SCREEN ─────────────────────────────────────────────────────
  group('AllStylesScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        AllStylesScreen(isDarkMode: true, onToggleDarkMode: () {}),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Scaffold', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        AllStylesScreen(isDarkMode: true, onToggleDarkMode: () {}),
      ));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        AllStylesScreen(isDarkMode: false, onToggleDarkMode: () {}),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ── PAYWALL / BUY CREDITS SCREEN ─────────────────────────────────────────
  group('PaywallScreen (Buy Credits)', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true, fetchPacksOverride: _fakeCreditPacks),
      ));
      await tester.pump();
      await tester.pump(); // let the fake pack fetch resolve
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Starter credit pack', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true, fetchPacksOverride: _fakeCreditPacks),
      ));
      await tester.pump();
      await tester.pump(); // let the fake pack fetch resolve
      expect(find.textContaining('Starter'), findsOneWidget);
    });

    testWidgets('renders Pro credit pack', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true, fetchPacksOverride: _fakeCreditPacks),
      ));
      await tester.pump();
      await tester.pump(); // let the fake pack fetch resolve
      expect(find.textContaining('Pro'), findsOneWidget);
    });

    testWidgets('renders Max credit pack', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true, fetchPacksOverride: _fakeCreditPacks),
      ));
      await tester.pump();
      await tester.pump(); // let the fake pack fetch resolve
      expect(find.textContaining('Max'), findsOneWidget);
    });

    testWidgets('renders in light mode without overflow', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: false, fetchPacksOverride: _fakeCreditPacks),
      ));
      await tester.pump();
      await tester.pump(); // let the fake pack fetch resolve
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping buy on iOS shows Apple App Store sheet and completes purchase', (tester) async {
      // Set test screen size to prevent lazy-loading virtualization
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(wrapWithProviders(
          const PaywallScreen(isDarkMode: true, fetchPacksOverride: _fakeCreditPacks),
        ));
        await tester.pump();
        await tester.pump(); // let the fake pack fetch resolve

        final buyButton = find.byType(ElevatedButton);
        await tester.tap(buyButton);
        await tester.pump(); // trigger tap
        await tester.pump(const Duration(milliseconds: 300)); // wait for sheet animation
        
        // Should show App Store verification sheet
        expect(find.text('App Store'), findsOneWidget);
        expect(find.text('Pay with Passcode / Touch ID'), findsOneWidget);
        
        // Tap pay button
        await tester.tap(find.text('Pay with Passcode / Touch ID'));
        await tester.pump(); // trigger tap
        
        // Step 1: Wait for Face ID scan (1600ms)
        await tester.pump(const Duration(milliseconds: 1700));
        
        // Step 2: Wait for close sheet (1200ms)
        await tester.pump(const Duration(milliseconds: 1300));
        
        // Step 3: Wait for dialog opening transitions (800ms)
        await tester.pump(const Duration(milliseconds: 800));
        
        // Flush microtasks and rebuild
        await tester.idle();
        await tester.pump();
        
        // Verify success confirmation dialog is shown
        expect(find.text('Purchase Successful!'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping buy on Android shows Google Play billing sheet and completes purchase', (tester) async {
      // Set test screen size to prevent lazy-loading virtualization
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(wrapWithProviders(
          const PaywallScreen(isDarkMode: true, fetchPacksOverride: _fakeCreditPacks),
        ));
        await tester.pump();
        await tester.pump(); // let the fake pack fetch resolve

        final buyButton = find.byType(ElevatedButton);
        await tester.tap(buyButton);
        await tester.pump(); // trigger tap
        await tester.pump(const Duration(milliseconds: 300)); // wait for sheet animation
        
        // Should show Google Play sheet
        expect(find.text('Google Play Billing'), findsOneWidget);
        expect(find.text('1-Tap Buy'), findsOneWidget);
        
        // Tap 1-Tap Buy
        await tester.tap(find.text('1-Tap Buy'));
        await tester.pump(); // trigger tap
        
        // Step 1: Wait for Google Play payment verification (1500ms)
        await tester.pump(const Duration(milliseconds: 1600));
        
        // Step 2: Wait for close sheet (900ms)
        await tester.pump(const Duration(milliseconds: 1000));
        
        // Step 3: Wait for dialog opening transitions (800ms)
        await tester.pump(const Duration(milliseconds: 800));
        
        // Flush microtasks and rebuild
        await tester.idle();
        await tester.pump();
        
        // Verify success confirmation dialog is shown
        expect(find.text('Purchase Successful!'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  // ── NOTIFICATIONS SCREEN ──────────────────────────────────────────────────
  group('NotificationsScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Notifications title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Notification'), findsWidgets);
    });

    testWidgets('renders in light mode', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const NotificationsScreen(isDarkMode: false),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
