import 'field_definition.dart';

class DefaultFieldTemplate {
  const DefaultFieldTemplate({
    required this.label,
    required this.type,
    this.defaultValue,
    this.sampleValues = const [],
    this.numberMin = 0,
    this.numberMax = 100,
  });

  final String label;
  final FieldType type;
  final String? defaultValue;
  final List<String> sampleValues;
  final double numberMin;
  final double numberMax;

  static DefaultFieldTemplate? findByLabel(String label) {
    final lower = label.toLowerCase();
    for (final t in catalog) {
      if (t.label.toLowerCase() == lower) return t;
    }
    return null;
  }

  static const catalog = [
    DefaultFieldTemplate(
      label: 'Problem',
      type: FieldType.text,
      sampleValues: [
        'Motor stopped',
        'Abnormal noise',
        'Motor overheating',
        'Oil leak',
        'Belt slipping',
        'Sensor fault',
        'Hydraulic pressure low',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Solution',
      type: FieldType.text,
      sampleValues: [
        'Replaced fuse',
        'Bearing replaced',
        'Cleaned vents',
        'Tightened belt',
        'Recalibrated sensor',
        'Refilled hydraulic fluid',
        'Aligned shaft',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Machine',
      type: FieldType.text,
      defaultValue: 'M-100',
      sampleValues: ['M-100', 'M-205', 'CNC-04', 'PUMP-12', 'CONV-03'],
    ),
    DefaultFieldTemplate(
      label: 'Technician',
      type: FieldType.text,
      defaultValue: 'Ahmed',
      sampleValues: ['Ahmed', 'Ali', 'Sara', 'Omar', 'Hassan'],
    ),
    DefaultFieldTemplate(
      label: 'Priority',
      type: FieldType.text,
      defaultValue: 'Medium',
      sampleValues: ['Low', 'Medium', 'High', 'Critical'],
    ),
    DefaultFieldTemplate(
      label: 'Root Cause',
      type: FieldType.text,
      sampleValues: [
        'Worn bearing',
        'Electrical fault',
        'Blocked filter',
        'Operator error',
        'Age-related wear',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Status',
      type: FieldType.text,
      defaultValue: 'Open',
      sampleValues: ['Open', 'In progress', 'Completed', 'On hold'],
    ),
    DefaultFieldTemplate(
      label: 'Spare Part',
      type: FieldType.text,
      sampleValues: [
        'Bearing 6205',
        'Fuse 10A',
        'V-belt B52',
        'Filter element',
        'Seal kit',
      ],
    ),
    DefaultFieldTemplate(
      label: 'Downtime (hours)',
      type: FieldType.number,
      defaultValue: '0',
      numberMin: 0.5,
      numberMax: 48,
    ),
    DefaultFieldTemplate(
      label: 'Work Order',
      type: FieldType.text,
      sampleValues: ['WO-1001', 'WO-1002', 'WO-1003', 'WO-2048', 'WO-3055'],
    ),
    DefaultFieldTemplate(
      label: 'Completed Date',
      type: FieldType.date,
    ),
  ];
}
