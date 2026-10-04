Map<String, Object?> recordValueColumns(dynamic value) {
  if (value is num) {
    return {'value_real': value, 'value_int': value.round()};
  }
  if (value is bool) {
    return {'value_int': value ? 1 : 0, 'value_text': value ? 'Yes' : 'No'};
  }
  if (value is DateTime) {
    final iso = value.toUtc().toIso8601String();
    return {'value_date_iso': iso, 'value_text': iso};
  }
  final text = value?.toString();
  return {'value_text': text};
}
