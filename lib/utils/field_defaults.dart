import '../models/field_definition.dart';

/// Parses stored default text into a value suitable for record storage / UI.
dynamic parseDefaultValue(FieldType type, String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  switch (type) {
    case FieldType.number:
      return double.tryParse(raw.trim());
    case FieldType.date:
      final trimmed = raw.trim();
      final parts = trimmed.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
      return DateTime.tryParse(trimmed);
    case FieldType.text:
    case FieldType.dropdown:
    case FieldType.boolean:
      return raw.trim();
  }
}

String? defaultValueHint(FieldType type) {
  switch (type) {
    case FieldType.text:
      return 'Optional default text';
    case FieldType.number:
      return 'e.g. 0 or 2.5';
    case FieldType.date:
      return 'dd/MM/yyyy or leave empty';
    default:
      return null;
  }
}
