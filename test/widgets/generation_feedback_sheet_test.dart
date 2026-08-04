import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/widgets/generation_feedback_sheet.dart';
import '../helpers/test_helpers.dart';

Widget _harness(ValueChanged<Future<GenerationFeedbackSheetResult?>>? onOpen) {
  return wrapWithApp(
    Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () {
            final future = showGenerationFeedbackSheet(context, isDarkMode: true);
            onOpen?.call(future);
          },
          child: const Text('Open Sheet'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the sheet title, star rating, comment field, and buttons', (tester) async {
    await tester.pumpWidget(_harness(null));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('🎉 How do you like this result?'), findsOneWidget);
    expect(find.text("Don't ask me again"), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
  });

  testWidgets('Submit is disabled until a star is tapped', (tester) async {
    await tester.pumpWidget(_harness(null));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    final submitButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Submit'),
    );
    expect(submitButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();

    final submitButtonAfter = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Submit'),
    );
    expect(submitButtonAfter.onPressed, isNotNull);
  });

  testWidgets('submitting returns the selected rating and trimmed comment', (tester) async {
    Future<GenerationFeedbackSheetResult?>? sheetFuture;
    await tester.pumpWidget(_harness((f) => sheetFuture = f));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Tap the 4th star (index 3) to select a rating of 4.
    final stars = find.byIcon(Icons.star_border_rounded);
    await tester.tap(stars.at(3));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '  Loved it!  ');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    final result = await sheetFuture;
    expect(result?.submitted, isTrue);
    expect(result?.rating, 4);
    expect(result?.comment, 'Loved it!');
    expect(result?.dontAskAgain, isFalse);
  });

  testWidgets('skip returns submitted=false and honors a checked "don\'t ask again"', (tester) async {
    Future<GenerationFeedbackSheetResult?>? sheetFuture;
    await tester.pumpWidget(_harness((f) => sheetFuture = f));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    final result = await sheetFuture;
    expect(result?.submitted, isFalse);
    expect(result?.rating, isNull);
    expect(result?.dontAskAgain, isTrue);
  });
}
