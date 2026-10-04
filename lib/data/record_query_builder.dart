import '../core/filters.dart';
import '../core/sort.dart';
import '../models/field_definition.dart';

class BuiltQuery {
  BuiltQuery({
    required this.whereSql,
    required this.whereArgs,
    this.sortJoinSql,
    this.sortJoinArgs = const [],
    this.orderBySql,
  });

  final String whereSql;
  final List<Object?> whereArgs;
  final String? sortJoinSql;
  final List<Object?> sortJoinArgs;
  final String? orderBySql;
}

class RecordQueryBuilder {
  RecordQueryBuilder(this._fieldTypes);

  final Map<String, FieldType> _fieldTypes;

  BuiltQuery build({
    String? search,
    List<RecordFilter> filters = const [],
    SortConfig? sort,
  }) {
    final where = <String>['1=1'];
    final args = <Object?>[];

    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      where.add('''(
        f.name LIKE ? COLLATE NOCASE
        OR EXISTS (
          SELECT 1 FROM record_field_values sv
          WHERE sv.record_id = r.id
            AND sv.value_text LIKE ? COLLATE NOCASE
        )
      )''');
      args..add(term)..add(term);
    }

    for (final filter in filters) {
      _applyFilter(filter, where, args);
    }

    String? sortJoin;
    List<Object?> sortJoinArgs = [];
    String? orderBy;
    if (sort != null && sort.direction != SortDirection.none) {
      final dir = sort.direction == SortDirection.ascending ? 'ASC' : 'DESC';
      if (sort.fieldId == SystemFields.date) {
        orderBy = 'r.created_at $dir';
      } else if (sort.fieldId == SystemFields.form) {
        orderBy = 'f.name COLLATE NOCASE $dir';
      } else {
        final type = _fieldTypes[sort.fieldId] ?? FieldType.text;
        sortJoin =
            'LEFT JOIN record_field_values sort_v ON sort_v.record_id = r.id AND sort_v.field_id = ?';
        sortJoinArgs = [sort.fieldId];
        orderBy = switch (type) {
          FieldType.number =>
            'COALESCE(sort_v.value_real, sort_v.value_int) $dir',
          FieldType.date => 'sort_v.value_date_iso $dir',
          FieldType.boolean => 'sort_v.value_int $dir',
          FieldType.dropdown || FieldType.text =>
            'sort_v.value_text COLLATE NOCASE $dir',
        };
      }
    } else {
      orderBy = 'r.created_at DESC';
    }

    return BuiltQuery(
      whereSql: where.join(' AND '),
      whereArgs: args,
      sortJoinSql: sortJoin,
      sortJoinArgs: sortJoinArgs,
      orderBySql: orderBy,
    );
  }

  void _applyFilter(
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    final fieldId = filter.fieldId;
    if (fieldId == SystemFields.form) {
      _applySystemFormFilter(filter, where, args);
      return;
    }
    if (fieldId == SystemFields.date) {
      _applySystemDateFilter(filter, where, args);
      return;
    }

    final type = _fieldTypes[fieldId] ?? FieldType.text;
    switch (filter.operator) {
      case FilterOperator.isEmpty:
        where.add('''NOT EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND (
              v.value_text IS NOT NULL AND TRIM(v.value_text) != ''
              OR v.value_real IS NOT NULL
              OR v.value_int IS NOT NULL
              OR v.value_date_iso IS NOT NULL
            )
        )''');
        args.add(fieldId);
        return;
      case FilterOperator.isNotEmpty:
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND (
              v.value_text IS NOT NULL AND TRIM(v.value_text) != ''
              OR v.value_real IS NOT NULL
              OR v.value_int IS NOT NULL
              OR v.value_date_iso IS NOT NULL
            )
        )''');
        args.add(fieldId);
        return;
      default:
        break;
    }

    switch (type) {
      case FieldType.number:
        _applyNumberFilter(fieldId, filter, where, args);
      case FieldType.date:
        _applyDateFieldFilter(fieldId, filter, where, args);
      case FieldType.boolean:
        _applyBooleanFilter(fieldId, filter, where, args);
      case FieldType.dropdown:
        _applyDropdownFilter(fieldId, filter, where, args);
      case FieldType.text:
        _applyTextFilter(fieldId, filter, where, args);
    }
  }

  void _applySystemFormFilter(
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    if (filter.operator == FilterOperator.inList && filter.value is List) {
      final names = (filter.value as List).cast<String>();
      if (names.isEmpty) return;
      final placeholders = List.filled(names.length, '?').join(', ');
      where.add('f.name IN ($placeholders)');
      args.addAll(names);
      return;
    }
    if (filter.operator == FilterOperator.equals && filter.value != null) {
      where.add('f.name = ? COLLATE NOCASE');
      args.add(filter.value);
    }
  }

  void _applySystemDateFilter(
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    if (filter.operator == FilterOperator.between) {
      final from = filter.value as DateTime?;
      final to = filter.valueTo as DateTime?;
      if (from != null) {
        where.add('r.created_at >= ?');
        args.add(from.toUtc().toIso8601String());
      }
      if (to != null) {
        where.add('r.created_at <= ?');
        args.add(to.toUtc().toIso8601String());
      }
    }
  }

  void _applyTextFilter(
    String fieldId,
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    final op = filter.operator;
    final value = filter.value?.toString() ?? '';
    if (value.isEmpty && op != FilterOperator.isEmpty) return;

    String sqlOp;
    String pattern;
    switch (op) {
      case FilterOperator.contains:
        sqlOp = 'LIKE';
        pattern = '%$value%';
      case FilterOperator.startsWith:
        sqlOp = 'LIKE';
        pattern = '$value%';
      case FilterOperator.endsWith:
        sqlOp = 'LIKE';
        pattern = '%$value';
      case FilterOperator.equals:
        sqlOp = '=';
        pattern = value;
      case FilterOperator.notEquals:
        where.add('''NOT EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND v.value_text = ? COLLATE NOCASE
        )''');
        args..add(fieldId)..add(value);
        return;
      default:
        return;
    }

    if (sqlOp == 'LIKE') {
      where.add('''EXISTS (
        SELECT 1 FROM record_field_values v
        WHERE v.record_id = r.id AND v.field_id = ?
          AND v.value_text LIKE ? COLLATE NOCASE
      )''');
      args..add(fieldId)..add(pattern);
    } else {
      where.add('''EXISTS (
        SELECT 1 FROM record_field_values v
        WHERE v.record_id = r.id AND v.field_id = ?
          AND v.value_text = ? COLLATE NOCASE
      )''');
      args..add(fieldId)..add(pattern);
    }
  }

  void _applyNumberFilter(
    String fieldId,
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    final value = _asDouble(filter.value);
    if (value == null && filter.operator != FilterOperator.between) return;

    switch (filter.operator) {
      case FilterOperator.between:
        final a = _asDouble(filter.value);
        final b = _asDouble(filter.valueTo);
        if (a == null || b == null) return;
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND COALESCE(v.value_real, v.value_int * 1.0) BETWEEN ? AND ?
        )''');
        args..add(fieldId)..add(a)..add(b);
      case FilterOperator.greaterThan:
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND COALESCE(v.value_real, v.value_int * 1.0) > ?
        )''');
        args..add(fieldId)..add(value);
      case FilterOperator.lessThan:
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND COALESCE(v.value_real, v.value_int * 1.0) < ?
        )''');
        args..add(fieldId)..add(value);
      case FilterOperator.greaterThanOrEqual:
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND COALESCE(v.value_real, v.value_int * 1.0) >= ?
        )''');
        args..add(fieldId)..add(value);
      case FilterOperator.lessThanOrEqual:
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND COALESCE(v.value_real, v.value_int * 1.0) <= ?
        )''');
        args..add(fieldId)..add(value);
      case FilterOperator.equals:
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND COALESCE(v.value_real, v.value_int * 1.0) = ?
        )''');
        args..add(fieldId)..add(value);
      default:
        break;
    }
  }

  void _applyDateFieldFilter(
    String fieldId,
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    if (filter.operator == FilterOperator.between) {
      final from = filter.value as DateTime?;
      final to = filter.valueTo as DateTime?;
      if (from != null) {
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND v.value_date_iso >= ?
        )''');
        args..add(fieldId)..add(from.toUtc().toIso8601String());
      }
      if (to != null) {
        where.add('''EXISTS (
          SELECT 1 FROM record_field_values v
          WHERE v.record_id = r.id AND v.field_id = ?
            AND v.value_date_iso <= ?
        )''');
        args..add(fieldId)..add(to.toUtc().toIso8601String());
      }
    }
  }

  void _applyBooleanFilter(
    String fieldId,
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    if (filter.value == null) return;
    final boolVal = filter.value == true || filter.value == 'yes';
    where.add('''EXISTS (
      SELECT 1 FROM record_field_values v
      WHERE v.record_id = r.id AND v.field_id = ?
        AND v.value_int = ?
    )''');
    args..add(fieldId)..add(boolVal ? 1 : 0);
  }

  void _applyDropdownFilter(
    String fieldId,
    RecordFilter filter,
    List<String> where,
    List<Object?> args,
  ) {
    if (filter.operator == FilterOperator.inList && filter.value is List) {
      final values = (filter.value as List).cast<String>();
      if (values.isEmpty) return;
      final placeholders = List.filled(values.length, '?').join(', ');
      where.add('''EXISTS (
        SELECT 1 FROM record_field_values v
        WHERE v.record_id = r.id AND v.field_id = ?
          AND v.value_text IN ($placeholders)
      )''');
      args.add(fieldId);
      args.addAll(values);
      return;
    }
    if (filter.operator == FilterOperator.equals && filter.value != null) {
      where.add('''EXISTS (
        SELECT 1 FROM record_field_values v
        WHERE v.record_id = r.id AND v.field_id = ?
          AND v.value_text = ? COLLATE NOCASE
      )''');
      args..add(fieldId)..add(filter.value);
    }
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
