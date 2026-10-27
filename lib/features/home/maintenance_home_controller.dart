import 'package:flutter/foundation.dart';

import '../../core/filters.dart';
import '../../core/pagination.dart';
import '../../core/sort.dart';
import '../../data/maintenance_repository.dart';
import '../../models/field_definition.dart';
import '../../models/maintenance_record.dart';
import '../../models/ai_backend.dart';
import '../../services/column_preferences_service.dart';
import '../../services/litert_lm_service.dart';
import '../../services/lm_studio_service.dart';
import '../../services/settings_service.dart';
import '../../utils/maintenance_ai_prompt.dart';

class MaintenanceHomeController extends ChangeNotifier {
  MaintenanceHomeController({
    required MaintenanceRepository repository,
    required ColumnPreferencesService columnPrefs,
    required SettingsService settings,
    required LmStudioService lmStudio,
    required LiteRtLmService liteRtLm,
  })  : _repository = repository,
        _columnPrefs = columnPrefs,
        _settings = settings,
        _lmStudio = lmStudio,
        _liteRtLm = liteRtLm;

  final MaintenanceRepository _repository;
  final ColumnPreferencesService _columnPrefs;
  final SettingsService _settings;
  final LmStudioService _lmStudio;
  final LiteRtLmService _liteRtLm;

  List<FieldDefinition> allColumns = [];
  List<FieldDefinition> visibleColumns = [];
  Set<String> hiddenColumnIds = {};
  Map<String, double> columnWidths = {};

  PaginatedResult<MaintenanceRecordRow>? pageResult;
  List<RecordFilter> columnFilters = [];
  SortState sortState = const SortState(
    primary: SortConfig(
      fieldId: SystemFields.date,
      direction: SortDirection.descending,
    ),
  );

  String searchText = '';
  int currentPage = 1;
  int pageSize = 50;
  List<int> pageSizeOptions = SettingsService.defaultPageSizes;

  bool loading = false;
  int totalUnfiltered = 0;
  String? errorMessage;

  Map<String, List<String>> distinctCache = {};
  Map<int, String> aiAnswersByRecordId = {};
  final Set<int> aiLoadingRecordIds = {};
  int? _customFormId;

  Future<void> initialize() async {
    pageSize = await _settings.getDefaultPageSize();
    pageSizeOptions = await _settings.getPageSizeOptions();
    _customFormId = await _repository.getCustomFormId();
    allColumns = await _repository.getTableColumns();
    final validIds = allColumns.map((c) => c.id).toSet();
    hiddenColumnIds = (await _columnPrefs.loadHiddenColumnIds(
      allColumns.map((c) => c.id).toList(),
    ))
        .where(validIds.contains)
        .where((id) => id != SystemFields.aiAnswer)
        .toSet();
    columnWidths = await _columnPrefs.loadWidths();
    totalUnfiltered = await _repository.getTotalRecordCountUnfiltered();
    _recomputeVisibleColumns();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      pageResult = await _repository.getRecords(
        page: currentPage,
        pageSize: pageSize,
        search: searchText.isEmpty ? null : searchText,
        filters: columnFilters,
        sort: sortState.primary,
        formId: _customFormId,
      );
      final totalPages = pageResult!.totalPages;
      if (totalPages > 0 && currentPage > totalPages) {
        currentPage = totalPages;
        pageResult = await _repository.getRecords(
          page: currentPage,
          pageSize: pageSize,
          search: searchText.isEmpty ? null : searchText,
          filters: columnFilters,
          sort: sortState.primary,
          formId: _customFormId,
        );
      }
      totalUnfiltered = await _repository.getTotalRecordCountUnfiltered();
      await _loadAiAnswersForCurrentPage();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAiAnswersForCurrentPage() async {
    final records = pageResult?.records ?? [];
    if (records.isEmpty) {
      aiAnswersByRecordId = {};
      return;
    }
    aiAnswersByRecordId = await _repository.loadAiAnswersForRecords(
      records.map((r) => r.id).toList(),
    );
  }

  String aiAnswerFor(int recordId) => aiAnswersByRecordId[recordId] ?? '';

  bool isAiLoading(int recordId) => aiLoadingRecordIds.contains(recordId);

  List<FieldDefinition> get dataColumnsForAi =>
      allColumns.where((c) => c.id != SystemFields.aiAnswer).toList();

  Future<String?> askAiForRecord(MaintenanceRecordRow row) async {
    if (aiLoadingRecordIds.contains(row.id)) return null;
    aiLoadingRecordIds.add(row.id);
    notifyListeners();
    try {
      final prompt = buildMaintenanceAiPrompt(row, dataColumnsForAi);
      final backend = await _settings.loadAiBackend();
      final answer = switch (backend) {
        AiBackend.lmStudio => await _lmStudio.askMaintenanceAssistant(
          prompt: prompt,
        ),
        AiBackend.liteRtLm => await _liteRtLm.askMaintenanceAssistant(
          prompt: prompt,
        ),
      };
      await _repository.saveAiAnswer(row.id, answer);
      aiAnswersByRecordId[row.id] = answer;
      return answer;
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      aiLoadingRecordIds.remove(row.id);
      notifyListeners();
    }
  }

  void setSearch(String value) {
    searchText = value;
    currentPage = 1;
    refresh();
  }

  void setColumnFilter(RecordFilter? filter) {
    columnFilters.removeWhere((f) => f.fieldId == filter?.fieldId);
    if (filter != null &&
        filter.operator != FilterOperator.isEmpty &&
        !(filter.operator == FilterOperator.inList &&
            filter.value is List &&
            (filter.value as List).isEmpty)) {
      columnFilters.add(filter);
    }
    currentPage = 1;
    refresh();
  }

  void removeFilter(String fieldId) {
    columnFilters.removeWhere((f) => f.fieldId == fieldId);
    currentPage = 1;
    refresh();
  }

  void clearFilters() {
    columnFilters = [];
    searchText = '';
    currentPage = 1;
    refresh();
  }

  void toggleSort(String fieldId) {
    sortState = sortState.withFieldToggled(fieldId);
    currentPage = 1;
    refresh();
  }

  void setPage(int page) {
    currentPage = page;
    refresh();
  }

  void setPageSize(int size) {
    pageSize = size;
    currentPage = 1;
    refresh();
  }

  Future<void> toggleColumnVisibility(String fieldId, bool visible) async {
    if (fieldId == SystemFields.aiAnswer) return;
    if (visible) {
      hiddenColumnIds.remove(fieldId);
    } else {
      hiddenColumnIds.add(fieldId);
    }
    await _columnPrefs.saveHiddenColumnIds(hiddenColumnIds);
    _recomputeVisibleColumns();
    notifyListeners();
  }

  Future<void> resetColumns() async {
    await _columnPrefs.resetVisibility(allColumns.map((c) => c.id).toList());
    hiddenColumnIds = await _columnPrefs.loadHiddenColumnIds(
      allColumns.map((c) => c.id).toList(),
    );
    _recomputeVisibleColumns();
    notifyListeners();
  }

  double get actionsColumnWidth =>
      columnWidths[SystemFields.actions] ??
      SystemFields.defaultActionsColumnWidth;

  Future<void> setColumnWidth(
    String fieldId,
    double width, {
    bool persist = true,
  }) async {
    final min = fieldId == SystemFields.actions ? 120.0 : 60.0;
    columnWidths[fieldId] = width.clamp(min, 600);
    if (persist) {
      await _columnPrefs.saveWidths(columnWidths);
    }
    notifyListeners();
  }

  Future<void> persistColumnWidths() =>
      _columnPrefs.saveWidths(columnWidths);

  Future<List<String>> distinctValuesFor(String fieldId) async {
    if (distinctCache.containsKey(fieldId)) {
      return distinctCache[fieldId]!;
    }
    final values = await _repository.getDistinctFieldValues(fieldId);
    distinctCache[fieldId] = values;
    return values;
  }

  Future<void> deleteRecord(int id) async {
    await _repository.deleteRecord(id);
    distinctCache.clear();
    await refresh();
  }

  Future<List<MaintenanceRecordRow>> exportRows() {
    return _repository.getRecordsForExport(
      search: searchText.isEmpty ? null : searchText,
      filters: columnFilters,
      sort: sortState.primary,
      formId: _customFormId,
    );
  }

  bool get hasActiveFilters =>
      searchText.isNotEmpty || columnFilters.isNotEmpty;

  void _recomputeVisibleColumns() {
    visibleColumns =
        allColumns.where((c) => !hiddenColumnIds.contains(c.id)).toList();
    if (!visibleColumns.any((c) => c.id == SystemFields.aiAnswer) &&
        allColumns.any((c) => c.id == SystemFields.aiAnswer)) {
      visibleColumns.add(SystemFields.aiAnswerField);
    }
  }

  double widthFor(FieldDefinition column) {
    return columnWidths[column.id] ?? column.suggestedWidth;
  }

  FieldDefinition? columnById(String id) {
    for (final c in allColumns) {
      if (c.id == id) return c;
    }
    return null;
  }
}
