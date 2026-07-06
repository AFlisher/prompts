import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/image_preview_screen.dart';

void main() {
  group('ImagePreviewScreen', () {
    testWidgets('renders asset preview without crashing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImagePreviewScreen(
          assetPath: 'assets/images/style_arabic.jpg',
          title: 'Arabic Style',
        ),
      ));
      await tester.pump();

      expect(find.text('Arabic Style'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Save to Gallery'), findsOneWidget);
    });

    testWidgets('back button triggers navigation pop', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImagePreviewScreen(
                    assetPath: 'assets/images/style_arabic.jpg',
                    title: 'Arabic Style',
                  ),
                ),
              );
            },
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Arabic Style'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Arabic Style'), findsNothing);
      expect(find.text('Go'), findsOneWidget);
    });
  });
}
