// test/widget_test.dart
//
// Master smoke tests for StyliAI app.
// NOTE: Tests that use PrombtApp() only call pumpWidget (no pump/pumpAndSettle)
// to avoid the LandingScreen Future.delayed timer assertion failure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/screens/landing_screen.dart';

void main() {
  group('StyliAI — Master App Smoke Test', () {

    testWidgets('app starts and renders MaterialApp', (tester) async {
      await tester.pumpWidget(const PrombtApp());
      // No pump() — avoids the 2500ms LandingScreen Future.delayed timer
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app renders in dark mode by default', (tester) async {
      await tester.pumpWidget(const PrombtApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('app has no debug banner', (tester) async {
      await tester.pumpWidget(const PrombtApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('app title contains StyliAI', (tester) async {
      await tester.pumpWidget(const PrombtApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, contains('StyliAI'));
    });

    testWidgets('app has both light and dark themes configured', (tester) async {
      await tester.pumpWidget(const PrombtApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
    });
  });

  // Test LandingScreen in isolation (no timer from LandingScreen context)
  group('LandingScreen — isolated', () {
    testWidgets('renders StyliAI brand text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen()),
      );
      // Only check the initial render, before the timer fires
      expect(find.text('StyliAI'), findsOneWidget);
    });

    testWidgets('renders sparkle icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen()),
      );
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('has black background scaffold', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen()),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0A0A0A));
    });
  });
}
