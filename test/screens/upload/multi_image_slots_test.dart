// Multi-image styles: the upload screen renders one card per required/allowed
// source photo, and the slot math keeps classic 1/1 styles on exactly one card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/models/style_model.dart';
import 'package:prombt_app/screens/upload_screen.dart';

StyleModel _style({int minImages = 1, int maxImages = 1}) => StyleModel(
      id: 's1',
      name: 'Test Style',
      imagePath: '',
      imageUrl: '',
      minImages: minImages,
      maxImages: maxImages,
    );

Widget _host(StyleModel style) => MaterialApp(
      home: CreditProvider(
        notifier: CreditManager(),
        child: UploadScreen(style: style, isDarkMode: true),
      ),
    );

void main() {
  group('visibleImageSlots', () {
    test('1/1 style always shows exactly one card (current behavior)', () {
      expect(visibleImageSlots(minImages: 1, maxImages: 1, selectedCount: 0), 1);
      expect(visibleImageSlots(minImages: 1, maxImages: 1, selectedCount: 1), 1);
    });

    test('fixed 2/2 style always shows two cards', () {
      expect(visibleImageSlots(minImages: 2, maxImages: 2, selectedCount: 0), 2);
      expect(visibleImageSlots(minImages: 2, maxImages: 2, selectedCount: 1), 2);
      expect(visibleImageSlots(minImages: 2, maxImages: 2, selectedCount: 2), 2);
    });

    test('1..3 style grows one empty slot at a time up to the max', () {
      expect(visibleImageSlots(minImages: 1, maxImages: 3, selectedCount: 0), 1);
      expect(visibleImageSlots(minImages: 1, maxImages: 3, selectedCount: 1), 2);
      expect(visibleImageSlots(minImages: 1, maxImages: 3, selectedCount: 2), 3);
      expect(visibleImageSlots(minImages: 1, maxImages: 3, selectedCount: 3), 3);
    });
  });

  group('UploadScreen dynamic image cards', () {
    testWidgets('a classic single-image style renders one empty card', (tester) async {
      await tester.pumpWidget(_host(_style()));
      await tester.pump();
      expect(find.text('No photo added yet'), findsOneWidget);
    });

    testWidgets('a two-image style renders two empty cards', (tester) async {
      await tester.pumpWidget(_host(_style(minImages: 2, maxImages: 2)));
      await tester.pump();
      expect(find.text('No photo added yet'), findsNWidgets(2));
    });
  });
}
