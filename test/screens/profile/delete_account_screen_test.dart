// Sprint 1 / B-1 — the in-app account deletion screen.
//
// What is worth asserting here is the set of guards standing between a tap and
// an irreversible action. Each of them is invisible when it works and only
// noticed when it is gone, which is exactly the shape of a control that gets
// quietly refactored away.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/delete_account_screen.dart';
import 'package:prombt_app/services/auth_service.dart';

/// Records what the screen asked for, so the test can assert on the call
/// rather than on a rendered side effect.
class Recorder {
  int calls = 0;
  String? lastPassword;
  Object? throwThis;

  Future<void> delete({String? currentPassword}) async {
    calls += 1;
    lastPassword = currentPassword;
    if (throwThis != null) throw throwThis!;
  }
}

Future<void> pumpScreen(
  WidgetTester tester, {
  required bool requiresPassword,
  required Recorder recorder,
  VoidCallback? onDeleted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DeleteAccountScreen(
        isDarkMode: true,
        requiresPassword: requiresPassword,
        deleteAccountOverride: recorder.delete,
        onDeleted: onDeleted ?? () {},
      ),
    ),
  );
  await tester.pump();
}

Finder get deleteButton => find.widgetWithText(ElevatedButton, 'Permanently Delete Account');

/// The button sits below the fold in the default test viewport, so a bare
/// tap() silently misses it and the test fails for a reason that has nothing
/// to do with what it is asserting.
Future<void> tapDelete(WidgetTester tester) async {
  await tester.ensureVisible(deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(deleteButton);
  await tester.pump();
}

Finder fieldWithHint(String hint) => find.widgetWithText(TextField, hint).evaluate().isEmpty
    ? find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint)
    : find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint);

void main() {
  group('the destructive action is guarded', () {
    testWidgets('the delete button starts disabled', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: true, recorder: rec);

      final button = tester.widget<ElevatedButton>(deleteButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('typing the phrase alone is not enough for a password account',
        (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: true, recorder: rec);

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.pump();

      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);
      expect(rec.calls, 0);
    });

    testWidgets('a password alone is not enough', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: true, recorder: rec);

      await tester.enterText(fieldWithHint('Current password'), 'hunter22');
      await tester.pump();

      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);
      expect(rec.calls, 0);
    });

    testWidgets('a near-miss confirmation phrase does not enable the button',
        (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: false, recorder: rec);

      // Lower case must not pass - the backend compares case-sensitively, so a
      // client that accepted this would produce a confusing 400.
      await tester.enterText(fieldWithHint('DELETE'), 'delete');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE ME');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNull);
    });

    testWidgets('surrounding whitespace is forgiven', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: false, recorder: rec);

      // Keyboards add this; the user did not mean it.
      await tester.enterText(fieldWithHint('DELETE'), ' DELETE ');
      await tester.pump();

      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNotNull);
    });
  });

  group('account types', () {
    testWidgets('a Google account is not asked for a password', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: false, recorder: rec);

      expect(fieldWithHint('Current password'), findsNothing);

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.pump();
      await tapDelete(tester);

      expect(rec.calls, 1);
      // No password may be invented on the client's behalf.
      expect(rec.lastPassword, isNull);
    });

    testWidgets('a password account sends the typed password', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: true, recorder: rec);

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.enterText(fieldWithHint('Current password'), 'hunter22');
      await tester.pump();
      await tapDelete(tester);

      expect(rec.calls, 1);
      expect(rec.lastPassword, 'hunter22');
    });

    testWidgets('the password field is obscured', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: true, recorder: rec);

      final field = tester.widget<TextField>(fieldWithHint('Current password'));
      expect(field.obscureText, isTrue);
    });
  });

  group('outcomes', () {
    testWidgets('a success invokes onDeleted exactly once', (tester) async {
      final rec = Recorder();
      var deletedCalls = 0;

      await pumpScreen(
        tester,
        requiresPassword: false,
        recorder: rec,
        onDeleted: () => deletedCalls += 1,
      );

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.pump();
      await tapDelete(tester);

      expect(deletedCalls, 1);
    });

    testWidgets('a failure shows the backend message and does NOT navigate away',
        (tester) async {
      final rec = Recorder()..throwThis = const AuthException('Incorrect password.');
      var deletedCalls = 0;

      await pumpScreen(
        tester,
        requiresPassword: true,
        recorder: rec,
        onDeleted: () => deletedCalls += 1,
      );

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.enterText(fieldWithHint('Current password'), 'wrong');
      await tester.pump();
      await tapDelete(tester);

      expect(find.text('Incorrect password.'), findsOneWidget);
      // The account still exists, so the user must stay where they are.
      expect(deletedCalls, 0);
    });

    testWidgets('a transport failure never shows a raw exception', (tester) async {
      final rec = Recorder()..throwThis = Exception('SocketException: host lookup failed');

      await pumpScreen(tester, requiresPassword: false, recorder: rec);

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.pump();
      await tapDelete(tester);

      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('host lookup'), findsNothing);
      // ...but the user is still told something went wrong.
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('the user can retry after a failure', (tester) async {
      final rec = Recorder()..throwThis = const AuthException('Incorrect password.');
      var deletedCalls = 0;

      await pumpScreen(
        tester,
        requiresPassword: true,
        recorder: rec,
        onDeleted: () => deletedCalls += 1,
      );

      await tester.enterText(fieldWithHint('DELETE'), 'DELETE');
      await tester.enterText(fieldWithHint('Current password'), 'wrong');
      await tester.pump();
      await tapDelete(tester);

      // The button must come back, or a mistyped password bricks the flow.
      expect(tester.widget<ElevatedButton>(deleteButton).onPressed, isNotNull);

      rec.throwThis = null;
      await tester.enterText(fieldWithHint('Current password'), 'correct');
      await tester.pump();
      await tapDelete(tester);

      expect(rec.calls, 2);
      expect(deletedCalls, 1);
    });
  });

  group('the screen states what will be destroyed', () {
    testWidgets('warns that the action is irreversible', (tester) async {
      await pumpScreen(tester, requiresPassword: false, recorder: Recorder());

      expect(find.textContaining('cannot be undone'), findsWidgets);
    });

    testWidgets('names the categories being erased, including credits',
        (tester) async {
      await pumpScreen(tester, requiresPassword: false, recorder: Recorder());

      expect(find.textContaining('generated'), findsWidgets);
      expect(find.textContaining('credits'), findsWidgets);
      expect(find.textContaining('signed out everywhere'), findsWidgets);
    });

    testWidgets('offers a cancel that does not delete', (tester) async {
      final rec = Recorder();
      await pumpScreen(tester, requiresPassword: false, recorder: rec);

      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(rec.calls, 0);
    });
  });

  group('accessibility', () {
    testWidgets('the destructive button carries an explicit semantic label',
        (tester) async {
      await pumpScreen(tester, requiresPassword: false, recorder: Recorder());

      expect(
        find.bySemanticsLabel('Permanently delete my account'),
        findsOneWidget,
      );
    });
  });
}
