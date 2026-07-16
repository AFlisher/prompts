// test/screens/profile/privacy_screen_test.dart
//
// PrivacyScreen: Delete Account and Usage Analytics are intentionally gone
// (deleting + recreating an account could farm the free daily ad credit),
// and the Privacy Policy / Terms of Service tiles open the in-app
// LegalDocumentScreen instead of showing a "not available yet" snackbar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/legal_document_screen.dart';
import 'package:prombt_app/screens/privacy_screen.dart';

Widget _wrap() => const MaterialApp(home: PrivacyScreen(isDarkMode: true));

void main() {
  group('PrivacyScreen', () {
    testWidgets('no longer shows Delete Account or Usage Analytics', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Delete Account'), findsNothing);
      expect(find.text('Usage Analytics'), findsNothing);
      // The remaining items are intact.
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Personalization'), findsOneWidget);
    });

    testWidgets('tapping Privacy Policy opens the in-app document', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('What We Collect'), findsOneWidget);
      expect(find.textContaining('support@styliai.app'), findsWidgets);
    });

    testWidgets('tapping Terms of Service opens the in-app document', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('Credits & Purchases'), findsOneWidget);
    });

    testWidgets('legal document back button returns to PrivacyScreen', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentScreen), findsNothing);
      expect(find.byType(PrivacyScreen), findsOneWidget);
    });
  });
}
