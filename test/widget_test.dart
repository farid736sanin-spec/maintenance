import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/core/pagination.dart';

void main() {
  test('PaginatedResult computes total pages', () {
    const result = PaginatedResult<int>(
      records: [1, 2],
      totalRecords: 120,
      currentPage: 1,
      pageSize: 50,
    );
    expect(result.totalPages, 3);
    expect(result.endIndex, 50);
  });
}
