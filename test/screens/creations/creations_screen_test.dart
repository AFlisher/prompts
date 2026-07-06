import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/creations_screen.dart';
import 'package:prombt_app/data/creations_manager.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('MyCreationsScreen', () {
    testWidgets('renders empty state when no creations', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const MyCreationsScreen(isDarkMode: true),
      ));
      await tester.pump();

      expect(find.text('No creations yet'), findsOneWidget);
      expect(find.text('Your styled photos will appear here'), findsOneWidget);
      expect(find.text('✨ Create Your First'), findsOneWidget);
    });

    testWidgets('tapping Create Your First changes active tab to 0', (tester) async {
      final manager = CreationsManager()..shouldSaveToFile = false;
      manager.setTab(1); // Start on tab 1
      
      await tester.pumpWidget(wrapWithProviders(
        const MyCreationsScreen(isDarkMode: true),
        creationsManager: manager,
      ));
      await tester.pump();

      await tester.tap(find.text('✨ Create Your First'));
      await tester.pumpAndSettle();

      expect(manager.currentTab, equals(0));
    });

    testWidgets('renders creations cards when creations are present', (tester) async {
      final manager = CreationsManager()..shouldSaveToFile = false;
      await manager.addCreation(CreationItem(
        id: 'c1',
        styleId: 'comic',
        styleName: 'Comic Pop Art',
        imagePath: 'assets/images/style_arabic.jpg',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(wrapWithProviders(
        const MyCreationsScreen(isDarkMode: true),
        creationsManager: manager,
      ));
      await tester.pump();

      expect(find.text('Comic Pop Art'), findsOneWidget);
      expect(find.text('No creations yet'), findsNothing);
    });

    testWidgets('tapping creation card opens details sheet and deleting removes it', (tester) async {
      final manager = CreationsManager()..shouldSaveToFile = false;
      await manager.addCreation(CreationItem(
        id: 'c1',
        styleId: 'comic',
        styleName: 'Comic Pop Art',
        imagePath: 'assets/images/style_arabic.jpg',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(wrapWithProviders(
        const MyCreationsScreen(isDarkMode: true),
        creationsManager: manager,
      ));
      await tester.pump();

      // Tap card to open details sheet
      await tester.tap(find.text('Comic Pop Art'));
      await tester.pumpAndSettle();

      // Verify sheet contents (e.g. Save to Gallery, Share, Delete icon)
      expect(find.text('Save to Gallery'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Tap Delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Should be removed from creations list and empty state shows
      expect(manager.creations, isEmpty);
      expect(find.text('No creations yet'), findsOneWidget);
    });
  });
}
