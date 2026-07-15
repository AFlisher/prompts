// StyleField parsing tests (Dynamic Prompt Template feature).

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/models/style_field.dart';
import 'package:prombt_app/models/style.dart';
import 'package:prombt_app/models/style_model.dart';

void main() {
  group('StyleField.fromJson', () {
    test('parses a full text field', () {
      final f = StyleField.fromJson({
        'key': 'team', 'label': 'Team', 'type': 'text', 'required': true,
        'placeholder': 'Barcelona', 'sortOrder': 2,
      });
      expect(f.key, 'team');
      expect(f.required, isTrue);
      expect(f.placeholder, 'Barcelona');
      expect(f.type, 'text');
    });

    test('parses dropdown options as string list or {value,label} objects', () {
      final a = StyleField.fromJson({'key': 's', 'label': 'S', 'type': 'dropdown', 'options': ['S', 'M']});
      expect(a.options.map((o) => o.value).toList(), ['S', 'M']);

      final b = StyleField.fromJson({'key': 's', 'label': 'S', 'type': 'dropdown', 'options': [
        {'value': 'sm', 'label': 'Small'}
      ]});
      expect(b.options.first.value, 'sm');
      expect(b.options.first.label, 'Small');
    });

    test('applies defaults for missing fields', () {
      final f = StyleField.fromJson({'key': 'x'});
      expect(f.label, 'x'); // falls back to key
      expect(f.type, 'text');
      expect(f.required, isFalse);
      expect(f.options, isEmpty);
    });

    test('listFromJson sorts by sortOrder and ignores non-maps', () {
      final list = StyleField.listFromJson([
        {'key': 'b', 'label': 'B', 'sortOrder': 1},
        {'key': 'a', 'label': 'A', 'sortOrder': 0},
        'garbage',
      ]);
      expect(list.map((f) => f.key).toList(), ['a', 'b']);
    });

    test('listFromJson returns empty for null / non-list (backward compatible)', () {
      expect(StyleField.listFromJson(null), isEmpty);
      expect(StyleField.listFromJson('nope'), isEmpty);
    });
  });

  group('Style carries fields end to end', () {
    test('Style.fromJson parses fields and toStyleModel preserves them', () {
      final style = Style.fromJson({
        'id': 's1', 'name': 'Jersey', 'categoryId': 'c', 'coverImage': 'u',
        'creditCost': 2, 'isTrending': false, 'isPremium': false, 'isEnabled': true, 'sortOrder': 0,
        'fields': [
          {'key': 'team', 'label': 'Team', 'type': 'text', 'required': true},
        ],
      });
      expect(style.fields, hasLength(1));
      final model = style.toStyleModel();
      expect(model.fields.single.key, 'team');
    });

    test('a style with no fields yields an empty list (classic styles work)', () {
      final style = Style.fromJson({
        'id': 's', 'name': 'Plain', 'categoryId': 'c', 'coverImage': 'u',
        'creditCost': 1, 'isTrending': false, 'isPremium': false, 'isEnabled': true, 'sortOrder': 0,
      });
      expect(style.fields, isEmpty);
      expect(style.toStyleModel().fields, isEmpty);
    });

    test('StyleModel.fromJson round-trips fields', () {
      final m = StyleModel.fromJson({
        'id': 'x', 'name': 'N', 'imagePath': 'p',
        'fields': [
          {'key': 'title', 'label': 'Title', 'type': 'text', 'required': true},
        ],
      });
      expect(m.fields.single.key, 'title');
    });
  });
}
