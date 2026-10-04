import 'dart:math';

import '../models/default_field_templates.dart';
import '../models/field_definition.dart';
import '../utils/field_defaults.dart';

class RandomRecordGenerator {
  RandomRecordGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  Map<String, dynamic> generateValues(
    List<FieldDefinition> fields, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final values = <String, dynamic>{};
    for (final field in fields) {
      values[field.id] = _valueForField(field, now);
    }
    return values;
  }

  dynamic _valueForField(FieldDefinition field, DateTime now) {
    final template = DefaultFieldTemplate.findByLabel(field.label);
    switch (field.type) {
      case FieldType.number:
        final min = template?.numberMin ?? 0;
        final max = template?.numberMax ?? 100;
        final v = min + _random.nextDouble() * (max - min);
        return double.parse(v.toStringAsFixed(1));
      case FieldType.date:
        final daysBack = _random.nextInt(120);
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysBack));
      case FieldType.text:
        if (template != null && template.sampleValues.isNotEmpty) {
          return template.sampleValues[_random.nextInt(template.sampleValues.length)];
        }
        if (field.defaultValue != null && field.defaultValue!.isNotEmpty) {
          return field.defaultValue;
        }
        return 'Sample ${field.label} ${_random.nextInt(9999)}';
      default:
        return field.defaultValue ?? 'Value';
    }
  }

  DateTime randomCreatedAt(DateTime now) {
    final daysBack = _random.nextInt(365);
    final hour = _random.nextInt(24);
    final minute = _random.nextInt(60);
    return DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(Duration(days: daysBack));
  }

  static dynamic defaultForTemplate(DefaultFieldTemplate template) {
    if (template.defaultValue != null) {
      return parseDefaultValue(template.type, template.defaultValue);
    }
    if (template.sampleValues.isNotEmpty) {
      return template.sampleValues.first;
    }
    return null;
  }
}
