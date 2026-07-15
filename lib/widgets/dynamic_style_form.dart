import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/style_field.dart';

/// A fully data-driven form built from a style's [StyleField] definitions.
///
/// No field is hardcoded: the widget renders the right control for each field
/// type, validates required + per-type rules with friendly messages, and
/// reports the current values and overall validity via [onChanged]. The parent
/// passes a [formKey] so it can trigger visible validation (e.g. when the user
/// taps Generate) - values are collected continuously so the parent can gate
/// generation on validity.
class DynamicStyleForm extends StatefulWidget {
  final List<StyleField> fields;
  final void Function(Map<String, dynamic> values, bool isValid) onChanged;
  final GlobalKey<FormState>? formKey;

  const DynamicStyleForm({
    super.key,
    required this.fields,
    required this.onChanged,
    this.formKey,
  });

  @override
  State<DynamicStyleForm> createState() => _DynamicStyleFormState();
}

class _DynamicStyleFormState extends State<DynamicStyleForm> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      if (f.type == 'checkbox') {
        _values[f.key] = f.config['default'] == true;
      } else {
        final def = f.config['default']?.toString() ?? '';
        _values[f.key] = def;
        if (_needsController(f.type)) {
          _controllers[f.key] = TextEditingController(text: def);
        }
      }
    }
    // Report initial validity after first frame so parents can gate the button.
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _needsController(String type) =>
      type == 'text' || type == 'textarea' || type == 'number' || type == 'color' || type == 'date';

  bool _isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty);

  int? _intConfig(StyleField f, String key) {
    final v = f.config[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  num? _numConfig(StyleField f, String key) {
    final v = f.config[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  /// Returns a friendly error message, or null when valid. Shared by the
  /// visible FormField validators and the silent validity computation. All
  /// rules are driven by the field's [config] - nothing is hardcoded per style.
  String? _validate(StyleField f, dynamic value) {
    if (_isBlank(value)) {
      return f.required ? '${f.label} is required.' : null;
    }
    final s = value.toString().trim();
    switch (f.type) {
      case 'number':
        final n = num.tryParse(s);
        if (n == null) return 'Enter a valid number.';
        final min = _numConfig(f, 'min');
        final max = _numConfig(f, 'max');
        if (min != null && n < min) return '${f.label} must be at least $min.';
        if (max != null && n > max) return '${f.label} must be at most $max.';
        return null;
      case 'dropdown':
        if (!f.options.any((o) => o.value == s)) return 'Choose a valid option.';
        return null;
      case 'color':
        if (!RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(s)) {
          return 'Enter a hex color like #A855F7.';
        }
        return null;
      case 'date':
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) || DateTime.tryParse(s) == null) {
          return 'Enter a valid date (YYYY-MM-DD).';
        }
        return null;
      case 'text':
      case 'textarea':
        final minLength = _intConfig(f, 'minLength');
        if (minLength != null && s.length < minLength) {
          return '${f.label} must be at least $minLength characters.';
        }
        final pattern = f.config['regex'];
        if (pattern is String && pattern.trim().isNotEmpty) {
          RegExp? re;
          try {
            re = RegExp(pattern);
          } catch (_) {
            re = null; // a malformed admin regex never blocks the user
          }
          if (re != null && !re.hasMatch(s)) {
            return '${f.label} is not in the expected format.';
          }
        }
        return null;
      default:
        return null;
    }
  }

  bool get _isValid => widget.fields.every((f) => _validate(f, _values[f.key]) == null);

  void _set(String key, dynamic value) {
    _values[key] = value;
    _report();
  }

  void _report() {
    widget.onChanged(Map<String, dynamic>.from(_values), _isValid);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) return const SizedBox.shrink();
    return Form(
      key: widget.formKey ?? GlobalKey<FormState>(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildField(f),
            ),
        ],
      ),
    );
  }

  Widget _buildField(StyleField f) {
    switch (f.type) {
      case 'checkbox':
        return _buildCheckbox(f);
      case 'dropdown':
        return _buildDropdown(f);
      case 'textarea':
        return _buildText(f, maxLines: 4);
      case 'number':
        return _buildText(f, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]);
      case 'date':
        return _buildDate(f);
      case 'color':
      case 'text':
      default:
        return _buildText(f);
    }
  }

  InputDecoration _decoration(StyleField f) {
    final help = f.config['helpText'];
    return InputDecoration(
      labelText: f.required ? '${f.label} *' : f.label,
      hintText: f.placeholder,
      helperText: help is String && help.isNotEmpty ? help : null,
      helperMaxLines: 3,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  Widget _buildText(StyleField f, {int maxLines = 1, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) {
    // maxLength (config) hard-limits input length so the user can't exceed it,
    // matching the server's cap - driven entirely by config, not per style.
    final maxLength = _intConfig(f, 'maxLength');
    return TextFormField(
      key: ValueKey('field_${f.key}'),
      controller: _controllers[f.key],
      decoration: _decoration(f),
      maxLines: maxLines,
      maxLength: maxLength != null && maxLength > 0 ? maxLength : null,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => _validate(f, v),
      onChanged: (v) => _set(f.key, v),
    );
  }

  Widget _buildDropdown(StyleField f) {
    final current = (_values[f.key] as String?)?.isNotEmpty == true ? _values[f.key] as String : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('field_${f.key}'),
      initialValue: current,
      decoration: _decoration(f),
      items: [
        for (final o in f.options) DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => _validate(f, v),
      onChanged: (v) => _set(f.key, v ?? ''),
    );
  }

  Widget _buildCheckbox(StyleField f) {
    return SwitchListTile(
      key: ValueKey('field_${f.key}'),
      contentPadding: EdgeInsets.zero,
      title: Text(f.required ? '${f.label} *' : f.label),
      value: _values[f.key] == true,
      onChanged: (v) => setState(() => _set(f.key, v)),
    );
  }

  Widget _buildDate(StyleField f) {
    return TextFormField(
      key: ValueKey('field_${f.key}'),
      controller: _controllers[f.key],
      decoration: _decoration(f).copyWith(
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 100),
              lastDate: DateTime(now.year + 100),
            );
            if (picked != null) {
              final s = '${picked.year.toString().padLeft(4, '0')}-'
                  '${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
              _controllers[f.key]?.text = s;
              _set(f.key, s);
            }
          },
        ),
      ),
      keyboardType: TextInputType.datetime,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => _validate(f, v),
      onChanged: (v) => _set(f.key, v),
    );
  }
}
