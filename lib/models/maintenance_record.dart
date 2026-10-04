class MaintenanceRecordRow {
  const MaintenanceRecordRow({
    required this.id,
    required this.formId,
    required this.formName,
    required this.createdAt,
    required this.fieldValues,
  });

  final int id;
  final int formId;
  final String formName;
  final DateTime createdAt;
  final Map<String, String> fieldValues;

  String displayValue(String fieldId) {
    if (fieldId == 'sys_date') {
      return _formatDate(createdAt);
    }
    if (fieldId == 'sys_form') {
      return formName;
    }
    return fieldValues[fieldId] ?? '';
  }

  static String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}
