enum FilterOperator {
  equals,
  notEquals,
  contains,
  startsWith,
  endsWith,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  between,
  inList,
  isEmpty,
  isNotEmpty,
}

class RecordFilter {
  const RecordFilter({
    required this.fieldId,
    required this.operator,
    this.value,
    this.valueTo,
  });

  final String fieldId;
  final FilterOperator operator;
  final dynamic value;
  final dynamic valueTo;

  RecordFilter copyWith({
    String? fieldId,
    FilterOperator? operator,
    dynamic value,
    dynamic valueTo,
  }) {
    return RecordFilter(
      fieldId: fieldId ?? this.fieldId,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      valueTo: valueTo ?? this.valueTo,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordFilter &&
        other.fieldId == fieldId &&
        other.operator == operator &&
        other.value == value &&
        other.valueTo == valueTo;
  }

  @override
  int get hashCode => Object.hash(fieldId, operator, value, valueTo);
}
