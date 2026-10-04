import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/core/sort.dart';
import 'package:maintenance/data/record_query_builder.dart';
import 'package:maintenance/models/field_definition.dart';

void main() {
  test('sort join placeholder comes before where args in SQL', () {
    final builder = RecordQueryBuilder({'problem': FieldType.text});
    final built = builder.build(
      sort: const SortConfig(
        fieldId: 'problem',
        direction: SortDirection.ascending,
      ),
    );
    expect(built.sortJoinSql, isNotNull);
    expect(built.sortJoinArgs, ['problem']);
    expect(built.whereArgs, isEmpty);
    // Repository must bind: sortJoinArgs, then whereArgs, then limit/offset.
    final bound = [...built.sortJoinArgs, ...built.whereArgs, 50, 0];
    expect(bound.first, 'problem');
  });
}
