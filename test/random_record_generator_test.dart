import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/data/random_record_generator.dart';
import 'package:maintenance/models/default_field_templates.dart';
import 'package:maintenance/models/field_definition.dart';

void main() {
  test(
    'Problem subjects cover computers, computer science and office software',
    () {
      final template = DefaultFieldTemplate.findByLabel('Problem')!;
      final values = template.sampleValues;

      expect(values, isNotEmpty);
      for (final keyword in [
        'Windows',
        'Wi-Fi',
        'SSD',
        'RAM',
        'database',
        'Excel',
        'Word',
        'Outlook',
        'PowerPoint',
        'OneDrive',
      ]) {
        expect(
          values.any((v) => v.toLowerCase().contains(keyword.toLowerCase())),
          isTrue,
          reason: 'missing a Problem subject containing "$keyword"',
        );
      }
      expect(
        values.any((v) => v.contains('Motor') || v.contains('belt')),
        isFalse,
        reason: 'old mechanical wording should be gone',
      );
    },
  );

  test('random generator only produces Problem subjects from the template', () {
    final template = DefaultFieldTemplate.findByLabel('Problem')!;
    const field = FieldDefinition(
      id: 'problem',
      label: 'Problem',
      type: FieldType.text,
    );
    final generator = RandomRecordGenerator(random: Random(7));

    final seen = <String>{};
    for (var i = 0; i < 200; i++) {
      final values = generator.generateValues([field]);
      seen.add(values['problem'] as String);
    }

    expect(seen, isNotEmpty);
    expect(seen.difference(template.sampleValues.toSet()), isEmpty);
  });

  test('Machine default is a computer device tag', () {
    expect(DefaultFieldTemplate.findByLabel('Machine')!.defaultValue, 'PC-01');
  });
}
