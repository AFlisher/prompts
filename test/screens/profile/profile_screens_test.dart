// test/screens/profile/profile_screens_test.dart
//
// Tests for:
//   - ProfileScreen
//   - EditProfileScreen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/profile_screen.dart';
import 'package:prombt_app/screens/edit_profile_screen.dart';
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
  // ── PROFILE SCREEN ────────────────────────────────────────────────────────
  group('ProfileScreen', () {
    testWidgets('renders Profile title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('renders user avatar initials', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('A'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders Edit Profile option in menu', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Edit Profile'), findsOneWidget);
    });

    testWidgets('renders Notifications menu item', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Notifications'), findsOneWidget);
    });

    testWidgets('renders Privacy & Security menu item', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Privacy'), findsOneWidget);
    });

    testWidgets('renders Sign Out option', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.textContaining('Sign Out'), findsOneWidget);
    });

    testWidgets('renders in light mode without overflow', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProfileScreen(isDarkMode: false),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ── EDIT PROFILE SCREEN ───────────────────────────────────────────────────
  group('EditProfileScreen', () {
    testWidgets('renders Edit Profile title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('renders avatar with initial letter A', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders Tap to change photo hint', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Tap to change photo'), findsOneWidget);
    });

    testWidgets('renders Full Name editable field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Full Name'), findsOneWidget);
    });


    testWidgets('renders Bio editable field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Bio'), findsOneWidget);
    });

    testWidgets('email field shows Cannot be changed badge', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Cannot be changed'), findsOneWidget);
    });

    testWidgets('email field shows lock icon', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('renders Save Changes button', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('user can type into Name field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: true),
      ));
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'Mohammed');
      expect(find.text('Mohammed'), findsOneWidget);
    });

    testWidgets('renders without overflow in light mode', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const EditProfileScreen(isDarkMode: false),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
