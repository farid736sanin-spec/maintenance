import '../models/field_definition.dart';
import '../models/maintenance_record.dart';

String buildMaintenanceAiPrompt(
  MaintenanceRecordRow row,
  List<FieldDefinition> dataColumns,
) {
  final buffer = StringBuffer(
    'Review this maintenance record and suggest how to solve or prevent the problem.\n\n',
  );
  for (final col in dataColumns) {
    if (SystemFields.isProtectedColumn(col.id) ||
        col.id == SystemFields.form ||
        col.id == SystemFields.actions) {
      continue;
    }
    final value = row.displayValue(col.id).trim();
    if (value.isEmpty) continue;
    buffer.writeln('${col.label}: $value');
  }
  buffer.writeln(
    '\nReply in clear English (2–5 sentences). Focus on root cause and practical steps.',
  );
  return buffer.toString();
}
