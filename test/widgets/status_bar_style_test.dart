// test/widgets/status_bar_style_test.dart
//
// StatusBarStyle keeps the Android status bar icons readable on screens
// pushed outside MainShell (which otherwise fall back to the app-root
// white-icon baseline and become invisible on light backgrounds).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/notifications_screen.dart';
import 'package:prombt_app/widgets/status_bar_style.dart';

SystemUiOverlayStyle _annotatedValue(WidgetTester tester) {
  final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.descendant(
      of: find.byType(StatusBarStyle),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    ),
  );
  return region.value;
}

void main() {
  group('StatusBarStyle', () {
    testWidgets('dark screens get light (white) status bar icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: StatusBarStyle(isDark: true, child: Scaffold()),
      ));
      expect(_annotatedValue(tester), SystemUiOverlayStyle.light);
    });

    testWidgets('light screens get dark status bar icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: StatusBarStyle(isDark: false, child: Scaffold()),
      ));
      expect(_annotatedValue(tester), SystemUiOverlayStyle.dark);
    });
  });

  group('pushed screens carry their own status bar style', () {
    testWidgets('NotificationsScreen in light mode uses dark icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: NotificationsScreen(isDarkMode: false),
      ));
      await tester.pump();
      expect(_annotatedValue(tester), SystemUiOverlayStyle.dark);
    });

    testWidgets('NotificationsScreen in dark mode uses light icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(_annotatedValue(tester), SystemUiOverlayStyle.light);
    });
  });
}
