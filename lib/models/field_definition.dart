enum FieldType { text, number, date, dropdown, boolean }

class FieldDefinition {
  const FieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.defaultWidth = 140,
    this.defaultValue,
  });

  final String id;
  final String label;
  final FieldType type;
  final List<String> options;
  final double defaultWidth;
  final String? defaultValue;

  static FieldType typeFromDb(String raw) {
    switch (raw) {
      case 'number':
        return FieldType.number;
      case 'date':
        return FieldType.date;
      case 'dropdown':
        return FieldType.dropdown;
      case 'boolean':
        return FieldType.boolean;
      default:
        return FieldType.text;
    }
  }

  String get dbType {
    switch (type) {
      case FieldType.number:
        return 'number';
      case FieldType.date:
        return 'date';
      case FieldType.dropdown:
        return 'dropdown';
      case FieldType.boolean:
        return 'boolean';
      case FieldType.text:
        return 'text';
    }
  }

  double get suggestedWidth {
    if (defaultWidth != 140) return defaultWidth;
    switch (type) {
      case FieldType.text:
        final lower = label.toLowerCase();
        if (lower.contains('problem') ||
            lower.contains('solution') ||
            lower.contains('cause') ||
            lower.contains('description') ||
            lower.contains('note')) {
          return 220;
        }
        return 160;
      case FieldType.date:
        return 110;
      case FieldType.number:
        return 100;
      case FieldType.dropdown:
        return 120;
      case FieldType.boolean:
        return 90;
    }
  }
}

/// Built-in columns not stored in form_fields.
class SystemFields {
  static const date = 'sys_date';
  static const form = 'sys_form';
  static const actions = 'sys_actions';
  static const aiAnswer = 'sys_ai_answer';

  static const defaultActionsColumnWidth = 132.0;

  static const FieldDefinition dateField = FieldDefinition(
    id: date,
    label: 'Date',
    type: FieldType.date,
    defaultWidth: 110,
  );

  static const FieldDefinition formField = FieldDefinition(
    id: form,
    label: 'Form',
    type: FieldType.dropdown,
    defaultWidth: 140,
  );

  static const FieldDefinition aiAnswerField = FieldDefinition(
    id: aiAnswer,
    label: 'AI Answer',
    type: FieldType.text,
    defaultWidth: 260,
  );

  static bool isProtectedColumn(String fieldId) =>
      fieldId == aiAnswer || fieldId == date;
}
