/// A single dynamic input field configured for a style, mirroring the backend
/// `style_fields` schema. Drives the data-driven form on the generation flow.
///
/// New field types can appear without breaking older clients: an unrecognized
/// [type] falls back to a plain text input, and per-type knobs live in the
/// open-ended [config] map rather than in fixed columns.
class StyleFieldOption {
  final String value;
  final String label;

  const StyleFieldOption({required this.value, required this.label});

  factory StyleFieldOption.fromJson(dynamic json) {
    if (json is String) return StyleFieldOption(value: json, label: json);
    if (json is Map) {
      final value = (json['value'] ?? '').toString();
      return StyleFieldOption(value: value, label: (json['label'] ?? value).toString());
    }
    return const StyleFieldOption(value: '', label: '');
  }
}

class StyleField {
  final String key;
  final String label;
  final String type; // text | textarea | number | dropdown | checkbox | color | date
  final bool required;
  final String? placeholder;
  final List<StyleFieldOption> options;
  final Map<String, dynamic> config;
  final int sortOrder;

  const StyleField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.placeholder,
    this.options = const [],
    this.config = const {},
    this.sortOrder = 0,
  });

  factory StyleField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((o) => StyleFieldOption.fromJson(o)).toList()
        : const <StyleFieldOption>[];
    return StyleField(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? (json['key'] as String? ?? ''),
      type: json['type'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      placeholder: json['placeholder'] as String?,
      options: options,
      config: (json['config'] as Map?)?.cast<String, dynamic>() ?? const {},
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  static List<StyleField> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final list = raw
        .whereType<Map>()
        .map((m) => StyleField.fromJson(m.cast<String, dynamic>()))
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }
}
