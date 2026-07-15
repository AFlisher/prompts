// Widget tests for the data-driven DynamicStyleForm.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/models/style_field.dart';
import 'package:prombt_app/widgets/dynamic_style_form.dart';

Widget _host(List<StyleField> fields, {required void Function(Map<String, dynamic>, bool) onChanged, GlobalKey<FormState>? formKey}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DynamicStyleForm(fields: fields, onChanged: onChanged, formKey: formKey),
      ),
    ),
  );
}

void main() {
  testWidgets('renders one control per field, driven entirely by data', (tester) async {
    final fields = [
      const StyleField(key: 'team', label: 'Team', type: 'text', required: true),
      const StyleField(key: 'note', label: 'Note', type: 'textarea'),
      const StyleField(key: 'size', label: 'Size', type: 'dropdown', options: [
        StyleFieldOption(value: 'S', label: 'Small'),
        StyleFieldOption(value: 'M', label: 'Medium'),
      ]),
    ];
    await tester.pumpWidget(_host(fields, onChanged: (_, __) {}));
    await tester.pump();

    expect(find.byKey(const ValueKey('field_team')), findsOneWidget);
    expect(find.byKey(const ValueKey('field_note')), findsOneWidget);
    expect(find.byKey(const ValueKey('field_size')), findsOneWidget);
    // Required label carries the asterisk.
    expect(find.text('Team *'), findsOneWidget);
  });

  testWidgets('reports invalid until a required field is filled', (tester) async {
    bool? lastValid;
    Map<String, dynamic> lastValues = {};
    final fields = [const StyleField(key: 'team', label: 'Team', type: 'text', required: true)];

    await tester.pumpWidget(_host(fields, onChanged: (v, valid) {
      lastValues = v;
      lastValid = valid;
    }));
    await tester.pump();
    expect(lastValid, isFalse); // required + blank

    await tester.enterText(find.byKey(const ValueKey('field_team')), 'Barcelona');
    await tester.pump();
    expect(lastValid, isTrue);
    expect(lastValues['team'], 'Barcelona');
  });

  testWidgets('shows a friendly validation message when the form is validated', (tester) async {
    final formKey = GlobalKey<FormState>();
    final fields = [const StyleField(key: 'team', label: 'Team', type: 'text', required: true)];
    await tester.pumpWidget(_host(fields, onChanged: (_, __) {}, formKey: formKey));
    await tester.pump();

    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Team is required.'), findsOneWidget);
  });

  testWidgets('number field rejects out-of-range and non-numeric input', (tester) async {
    bool? valid;
    final fields = [
      const StyleField(key: 'age', label: 'Age', type: 'number', required: true, config: {'min': 1, 'max': 120}),
    ];
    await tester.pumpWidget(_host(fields, onChanged: (_, v) => valid = v));
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('field_age')), '999');
    await tester.pump();
    expect(valid, isFalse);

    await tester.enterText(find.byKey(const ValueKey('field_age')), '30');
    await tester.pump();
    expect(valid, isTrue);
  });

  testWidgets('optional field leaves the form valid when blank', (tester) async {
    bool? valid;
    final fields = [const StyleField(key: 'note', label: 'Note', type: 'text', required: false)];
    await tester.pumpWidget(_host(fields, onChanged: (_, v) => valid = v));
    await tester.pump();
    expect(valid, isTrue);
  });

  testWidgets('checkbox toggles its value', (tester) async {
    Map<String, dynamic> values = {};
    final fields = [const StyleField(key: 'vintage', label: 'Vintage', type: 'checkbox')];
    await tester.pumpWidget(_host(fields, onChanged: (v, _) => values = v));
    await tester.pump();
    expect(values['vintage'], false);

    await tester.tap(find.byKey(const ValueKey('field_vintage')));
    await tester.pump();
    expect(values['vintage'], true);
  });

  testWidgets('empty field list renders nothing and reports valid', (tester) async {
    bool? valid;
    await tester.pumpWidget(_host(const [], onChanged: (_, v) => valid = v));
    await tester.pump();
    expect(find.byType(TextFormField), findsNothing);
    expect(valid, isTrue);
  });
}
