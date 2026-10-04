import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/core/filters.dart';
import 'package:maintenance/core/sort.dart';
import 'package:maintenance/data/record_query_builder.dart';
import 'package:maintenance/models/field_definition.dart';

void main() {
  test('builds contains filter SQL fragment', () {
    final builder = RecordQueryBuilder({
      'problem': FieldType.text,
      'priority': FieldType.dropdown,
    });
    final built = builder.build(
      search: 'motor',
      filters: [
        RecordFilter(
          fieldId: 'priority',
          operator: FilterOperator.inList,
          value: ['High'],
        ),
      ],
      sort: const SortConfig(
        fieldId: SystemFields.date,
        direction: SortDirection.descending,
      ),
    );
    expect(built.whereSql, contains('LIKE'));
    expect(built.whereSql, contains('field_id = ?'));
    expect(built.whereArgs, contains('priority'));
    expect(built.orderBySql, contains('created_at'));
  });

  test('text sort uses valid SQLite COLLATE order', () {
    final builder = RecordQueryBuilder({'problem_solver': FieldType.text});
    final built = builder.build(
      sort: const SortConfig(
        fieldId: 'problem_solver',
        direction: SortDirection.ascending,
      ),
    );
    expect(built.orderBySql, 'sort_v.value_text COLLATE NOCASE ASC');
  });
}
