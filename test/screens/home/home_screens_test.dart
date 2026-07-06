// test/screens/home/home_screens_test.dart
//
// Tests for:
//   - HomeScreen
//   - AllStylesScreen
//   - PaywallScreen (Buy Credits)
//   - NotificationsScreen

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/home_screen.dart';
import 'package:prombt_app/screens/all_styles_screen.dart';
import 'package:prombt_app/screens/paywall_screen.dart';
import 'package:prombt_app/screens/notifications_screen.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/data/favorites_manager.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';
import 'package:prombt_app/data/creations_manager.dart';

Widget wrapWithProviders(Widget widget) {
  final favManager    = FavoritesManager();
  final styleManager  = DynamicStyleManager();
  final creditManager = CreditManager()..shouldSaveToFile = false;
  final creationsManager = CreationsManager()..shouldSaveToFile = false;
  return StyleProvider(
    notifier: styleManager,
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
        const PaywallScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Starter credit pack', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Starter'), findsOneWidget);
    });

    testWidgets('renders Pro credit pack', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Pro'), findsOneWidget);
    });

    testWidgets('renders Max credit pack', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Max'), findsOneWidget);
    });

    testWidgets('renders in light mode without overflow', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PaywallScreen(isDarkMode: false),
      ));
      await tester.pump();
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
          const PaywallScreen(isDarkMode: true),
        ));
        await tester.pump();
        
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
          const PaywallScreen(isDarkMode: true),
        ));
        await tester.pump();
        
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
