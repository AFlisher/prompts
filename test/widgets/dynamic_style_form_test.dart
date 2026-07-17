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

  // --- Rich (config-driven) validation metadata ---

  testWidgets('respects minLength from config', (tester) async {
    bool? valid;
    final fields = [const StyleField(key: 'code', label: 'Code', type: 'text', required: true, config: {'minLength': 3})];
    await tester.pumpWidget(_host(fields, onChanged: (_, v) => valid = v));
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('field_code')), 'ab');
    await tester.pump();
    expect(valid, isFalse);
    await tester.enterText(find.byKey(const ValueKey('field_code')), 'abc');
    await tester.pump();
    expect(valid, isTrue);
  });

  testWidgets('respects a regex pattern from config with a friendly message', (tester) async {
    final formKey = GlobalKey<FormState>();
    final fields = [const StyleField(key: 'code', label: 'Code', type: 'text', required: true, config: {'regex': r'^[A-Z]{3}$'})];
    await tester.pumpWidget(_host(fields, onChanged: (_, __) {}, formKey: formKey));
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('field_code')), 'abc');
    await tester.pump();
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Code is not in the expected format.'), findsOneWidget);
  });

  testWidgets('a malformed regex never blocks the user', (tester) async {
    bool? valid;
    final fields = [const StyleField(key: 'x', label: 'X', type: 'text', required: false, config: {'regex': '(['})];
    await tester.pumpWidget(_host(fields, onChanged: (_, v) => valid = v));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('field_x')), 'whatever');
    await tester.pump();
    expect(valid, isTrue);
  });

  testWidgets('applies maxLength and helpText from config to the field', (tester) async {
    final fields = [
      const StyleField(key: 'note', label: 'Note', type: 'text', config: {'maxLength': 5, 'helpText': 'Keep it short'}),
    ];
    await tester.pumpWidget(_host(fields, onChanged: (_, __) {}));
    await tester.pump();

    final inner = tester.widget<TextField>(
      find.descendant(of: find.byKey(const ValueKey('field_note')), matching: find.byType(TextField)),
    );
    expect(inner.maxLength, 5);
    expect(find.text('Keep it short'), findsOneWidget); // helperText rendered
  });

  testWidgets('respects number min/max from config', (tester) async {
    bool? valid;
    final fields = [const StyleField(key: 'age', label: 'Age', type: 'number', required: true, config: {'min': 18, 'max': 99})];
    await tester.pumpWidget(_host(fields, onChanged: (_, v) => valid = v));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('field_age')), '10');
    await tester.pump();
    expect(valid, isFalse);
    await tester.enterText(find.byKey(const ValueKey('field_age')), '25');
    await tester.pump();
    expect(valid, isTrue);
  });

  // MaterialApp pins themeMode: dark and screens simulate light mode manually,
  // so the form must re-scope Theme from its isDarkMode flag or every field
  // renders dark-mode (near-white) text on the light background.
  testWidgets('isDarkMode re-scopes the ambient theme so fields stay readable', (tester) async {
    final fields = [
      const StyleField(key: 'team', label: 'Team', type: 'text', required: true, placeholder: 'Enter team', config: {'helpText': 'Any club', 'maxLength': 10}),
      const StyleField(key: 'note', label: 'Note', type: 'textarea'),
      const StyleField(key: 'age', label: 'Age', type: 'number'),
      const StyleField(key: 'size', label: 'Size', type: 'dropdown', options: [StyleFieldOption(value: 'S', label: 'Small')]),
      const StyleField(key: 'hd', label: 'HD', type: 'checkbox'),
    ];

    Widget host({required bool isDarkMode}) => MaterialApp(
          // The real app's ambient theme: always dark.
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicStyleForm(fields: fields, isDarkMode: isDarkMode, onChanged: (_, __) {}),
            ),
          ),
        );

    // Light mode: every field type resolves against a light theme.
    await tester.pumpWidget(host(isDarkMode: false));
    await tester.pump();
    for (final key in ['field_team', 'field_note', 'field_age', 'field_size', 'field_hd']) {
      final themed = Theme.of(tester.element(find.byKey(ValueKey(key))));
      expect(themed.brightness, Brightness.light, reason: '$key must see the light theme');
      // Entered text/label derive from onSurface - must be dark on light.
      expect(themed.colorScheme.onSurface.computeLuminance(), lessThan(0.5), reason: '$key text must be dark in light mode');
    }

    // Dark mode: unchanged - fields still see the dark theme.
    await tester.pumpWidget(host(isDarkMode: true));
    await tester.pump();
    final themed = Theme.of(tester.element(find.byKey(const ValueKey('field_team'))));
    expect(themed.brightness, Brightness.dark);
    expect(themed.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
  });
}
