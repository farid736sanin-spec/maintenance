import '../../core/filters.dart';

class DateRangePreset {
  const DateRangePreset(this.label, this.from, this.to);

  final String label;
  final DateTime from;
  final DateTime to;
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

List<DateRangePreset> datePresets(DateTime now) {
  final today = _startOfDay(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekday = today.weekday;
  final weekStart = today.subtract(Duration(days: weekday - 1));
  final weekEnd = _endOfDay(weekStart.add(const Duration(days: 6)));
  final monthStart = DateTime(today.year, today.month, 1);
  final monthEnd = _endOfDay(DateTime(today.year, today.month + 1, 0));

  return [
    DateRangePreset('Today', today, _endOfDay(today)),
    DateRangePreset('Yesterday', yesterday, _endOfDay(yesterday)),
    DateRangePreset('This week', weekStart, weekEnd),
    DateRangePreset('This month', monthStart, monthEnd),
  ];
}

RecordFilter? dateRangeFilter(String fieldId, DateTime? from, DateTime? to) {
  if (from == null && to == null) return null;
  return RecordFilter(
    fieldId: fieldId,
    operator: FilterOperator.between,
    value: from,
    valueTo: to,
  );
}
