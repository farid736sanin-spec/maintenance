class PaginatedResult<T> {
  const PaginatedResult({
    required this.records,
    required this.totalRecords,
    required this.currentPage,
    required this.pageSize,
  });

  final List<T> records;
  final int totalRecords;
  final int currentPage;
  final int pageSize;

  int get totalPages {
    if (pageSize <= 0 || totalRecords == 0) return totalRecords == 0 ? 0 : 1;
    return (totalRecords / pageSize).ceil();
  }

  int get startIndex =>
      totalRecords == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;

  int get endIndex {
    if (totalRecords == 0) return 0;
    final end = currentPage * pageSize;
    return end > totalRecords ? totalRecords : end;
  }
}
