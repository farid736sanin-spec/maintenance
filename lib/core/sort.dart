enum SortDirection { none, ascending, descending }

class SortConfig {
  const SortConfig({required this.fieldId, required this.direction});

  final String fieldId;
  final SortDirection direction;

  SortConfig copyWith({String? fieldId, SortDirection? direction}) {
    return SortConfig(
      fieldId: fieldId ?? this.fieldId,
      direction: direction ?? this.direction,
    );
  }
}

/// Supports a primary sort today; additional entries reserved for multi-sort.
class SortState {
  const SortState({this.primary});

  final SortConfig? primary;

  SortState withFieldToggled(String fieldId) {
    if (primary == null || primary!.fieldId != fieldId) {
      return SortState(
        primary: SortConfig(fieldId: fieldId, direction: SortDirection.ascending),
      );
    }
    switch (primary!.direction) {
      case SortDirection.ascending:
        return SortState(
          primary: SortConfig(fieldId: fieldId, direction: SortDirection.descending),
        );
      case SortDirection.descending:
        return const SortState();
      case SortDirection.none:
        return SortState(
          primary: SortConfig(fieldId: fieldId, direction: SortDirection.ascending),
        );
    }
  }
}
