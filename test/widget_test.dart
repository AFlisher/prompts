import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prombt_app/main.dart';

void main() {
  testWidgets('Prombt app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PrombtApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
