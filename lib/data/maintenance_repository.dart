import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/filters.dart';
import '../core/pagination.dart';
import '../core/sort.dart';
import '../models/field_definition.dart';
import '../models/maintenance_record.dart';
import '../config/project_paths.dart';
import '../models/default_field_templates.dart';
import '../services/settings_service.dart';
import '../utils/field_id.dart';
import 'database.dart';
import 'random_record_generator.dart';
import 'record_query_builder.dart';
import 'record_values.dart';

class MaintenanceRepository {
  MaintenanceRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsService _settings;

  Database get _raw => _db.raw;

  /// Home table columns: Date + fields saved in Settings (custom form).
  Future<List<FieldDefinition>> getTableColumns() async {
    final customFields = await getCustomFormFields();
    if (customFields.isEmpty) {
      return [SystemFields.dateField, SystemFields.aiAnswerField];
    }
    final savedIds = await _settings.loadHomeColumnFieldIds();
    if (savedIds.isEmpty) {
      return [SystemFields.dateField, ...customFields];
    }
    final byId = {for (final f in customFields) f.id: f};
    final ordered = <FieldDefinition>[SystemFields.dateField];
    final used = <String>{};
    for (final id in savedIds) {
      final field = byId[id];
      if (field != null) {
        ordered.add(field);
        used.add(id);
      }
    }
    for (final f in customFields) {
      if (!used.contains(f.id)) ordered.add(f);
    }
    if (!ordered.any((c) => c.id == SystemFields.aiAnswer)) {
      ordered.add(SystemFields.aiAnswerField);
    }
    return ordered;
  }

  Future<Map<int, String>> loadAiAnswersForRecords(List<int> recordIds) async {
    if (recordIds.isEmpty) return {};
    final placeholders = List.filled(recordIds.length, '?').join(',');
    final rows = await _raw.rawQuery(
      'SELECT record_id, answer_text FROM record_ai_answers '
      'WHERE record_id IN ($placeholders)',
      recordIds,
    );
    return {
      for (final row in rows)
        row['record_id'] as int: row['answer_text'] as String,
    };
  }

  Future<void> saveAiAnswer(int recordId, String answer) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _raw.insert(
      'record_ai_answers',
      {
        'record_id': recordId,
        'answer_text': answer,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAllAiAnswers() async {
    await _raw.delete('record_ai_answers');
  }

  Future<Map<String, FieldType>> getFieldTypeMap() async {
    final cols = await getTableColumns();
    return {for (final c in cols) c.id: c.type};
  }

  Future<int> getTotalRecordCountUnfiltered() async {
    final formId = await getCustomFormId();
    return getTotalRecordCount(formId: formId);
  }

  Future<int> getTotalRecordCount({int? formId}) async {
    if (formId == null) {
      final row = await _raw.rawQuery(
        'SELECT COUNT(*) AS c FROM maintenance_records',
      );
      return row.first['c'] as int? ?? 0;
    }
    final row = await _raw.rawQuery(
      'SELECT COUNT(*) AS c FROM maintenance_records WHERE form_id = ?',
      [formId],
    );
    return row.first['c'] as int? ?? 0;
  }

  Future<PaginatedResult<MaintenanceRecordRow>> getRecords({
    required int page,
    required int pageSize,
    String? search,
    List<RecordFilter>? filters,
    SortConfig? sort,
    int? formId,
  }) async {
    final fieldTypes = await getFieldTypeMap();
    final builder = RecordQueryBuilder(fieldTypes);
    final built = builder.build(
      search: search,
      filters: filters ?? const [],
      sort: sort,
    );
    final whereParts = [built.whereSql];
    final whereArgs = [...built.whereArgs];
    if (formId != null) {
      whereParts.add('r.form_id = ?');
      whereArgs.add(formId);
    }
    final whereSql = whereParts.join(' AND ');

    final countSql = '''
SELECT COUNT(DISTINCT r.id) AS c
FROM maintenance_records r
JOIN maintenance_forms f ON f.id = r.form_id
WHERE $whereSql
''';
    final countRow = await _raw.rawQuery(countSql, whereArgs);
    final total = countRow.first['c'] as int? ?? 0;

    if (total == 0) {
      return PaginatedResult(
        records: const [],
        totalRecords: 0,
        currentPage: 1,
        pageSize: pageSize,
      );
    }

    final safePage = page < 1 ? 1 : page;
    final offset = (safePage - 1) * pageSize;
    final joinSort = built.sortJoinSql ?? '';
    final selectSql = '''
SELECT r.id, r.form_id, r.created_at, f.name AS form_name
FROM maintenance_records r
JOIN maintenance_forms f ON f.id = r.form_id
$joinSort
WHERE $whereSql
ORDER BY ${built.orderBySql}
LIMIT ? OFFSET ?
''';
    final selectArgs = [
      ...built.sortJoinArgs,
      ...whereArgs,
      pageSize,
      offset,
    ];
    final idRows = await _raw.rawQuery(selectSql, selectArgs);
    final ids = idRows.map((r) => r['id'] as int).toList();
    if (ids.isEmpty) {
      return PaginatedResult(
        records: const [],
        totalRecords: total,
        currentPage: safePage,
        pageSize: pageSize,
      );
    }

    final placeholders = List.filled(ids.length, '?').join(', ');
    final valueRows = await _raw.rawQuery(
      '''
SELECT record_id, field_id, value_text, value_real, value_int, value_date_iso
FROM record_field_values
WHERE record_id IN ($placeholders)
''',
      ids,
    );

    final valuesByRecord = <int, Map<String, String>>{};
    for (final row in valueRows) {
      final recordId = row['record_id'] as int;
      final fieldId = row['field_id'] as String;
      valuesByRecord.putIfAbsent(recordId, () => {});
      valuesByRecord[recordId]![fieldId] = _displayFromRow(row);
    }

    final records = idRows.map((row) {
      final id = row['id'] as int;
      return MaintenanceRecordRow(
        id: id,
        formId: row['form_id'] as int,
        formName: row['form_name'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        fieldValues: valuesByRecord[id] ?? {},
      );
    }).toList();

    return PaginatedResult(
      records: records,
      totalRecords: total,
      currentPage: safePage,
      pageSize: pageSize,
    );
  }

  Future<List<MaintenanceRecordRow>> getRecordsForExport({
    String? search,
    List<RecordFilter>? filters,
    SortConfig? sort,
    int? formId,
    int maxRows = 50000,
  }) async {
    final result = await getRecords(
      page: 1,
      pageSize: maxRows,
      search: search,
      filters: filters,
      sort: sort,
      formId: formId,
    );
    return result.records;
  }

  Future<List<String>> getDistinctFormNames() async {
    final rows = await _raw.query(
      'maintenance_forms',
      columns: ['name'],
      orderBy: 'display_order ASC, name ASC',
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<List<String>> getDistinctFieldValues(String fieldId) async {
    if (fieldId == SystemFields.form) {
      return getDistinctFormNames();
    }
    final rows = await _raw.rawQuery(
      '''
SELECT DISTINCT value_text AS v
FROM record_field_values
WHERE field_id = ? AND value_text IS NOT NULL AND TRIM(value_text) != ''
ORDER BY v COLLATE NOCASE ASC
''',
      [fieldId],
    );
    return rows.map((r) => r['v'] as String).toList();
  }

  Future<MaintenanceRecordRow?> getRecordById(int id) async {
    final rows = await _raw.rawQuery(
      '''
SELECT r.id, r.form_id, r.created_at, f.name AS form_name
FROM maintenance_records r
JOIN maintenance_forms f ON f.id = r.form_id
WHERE r.id = ?
''',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final valueRows = await _raw.query(
      'record_field_values',
      where: 'record_id = ?',
      whereArgs: [id],
    );
    final values = <String, String>{
      for (final v in valueRows) v['field_id'] as String: _displayFromRow(v),
    };
    return MaintenanceRecordRow(
      id: id,
      formId: row['form_id'] as int,
      formName: row['form_name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      fieldValues: values,
    );
  }

  Future<List<FieldDefinition>> getFieldsForRecord(int recordId) async {
    final row = await _raw.query(
      'maintenance_records',
      columns: ['form_id'],
      where: 'id = ?',
      whereArgs: [recordId],
      limit: 1,
    );
    if (row.isEmpty) return [];
    final formId = row.first['form_id'] as int;
    final fields = await _raw.query(
      'form_fields',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'display_order ASC',
    );
    return fields.map(_fieldFromRow).toList();
  }

  Future<void> deleteRecord(int id) async {
    await _raw.delete(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getCustomFormId() async {
    final rows = await _raw.query(
      'maintenance_forms',
      where: 'name = ?',
      whereArgs: [customMaintenanceFormName],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return _raw.insert('maintenance_forms', {
      'name': customMaintenanceFormName,
      'display_order': 0,
    });
  }

  Future<List<FieldDefinition>> getCustomFormFields() async {
    final formId = await getCustomFormId();
    final fields = await _raw.query(
      'form_fields',
      where: 'form_id = ?',
      whereArgs: [formId],
      orderBy: 'display_order ASC',
    );
    return fields.map(_fieldFromRow).toList();
  }

  FieldDefinition _fieldFromRow(Map<String, Object?> f) {
    final optionsRaw = f['options_json'] as String?;
    List<String> options = [];
    if (optionsRaw != null && optionsRaw.isNotEmpty) {
      options = (jsonDecode(optionsRaw) as List).cast<String>();
    }
    return FieldDefinition(
      id: f['id'] as String,
      label: f['label'] as String,
      type: FieldDefinition.typeFromDb(f['field_type'] as String),
      options: options,
      defaultValue: f['default_value'] as String?,
    );
  }

  Future<void> syncCustomFormFields(List<FieldDefinition> fields) async {
    if (fields.isEmpty) {
      throw StateError('Add at least one field before saving.');
    }
    final formId = await getCustomFormId();
    await _raw.transaction((txn) async {
      final existing = await txn.query(
        'form_fields',
        where: 'form_id = ?',
        whereArgs: [formId],
      );
      final keepIds = fields.map((f) => f.id).toSet();
      for (final old in existing) {
        final oldId = old['id'] as String;
        if (!keepIds.contains(oldId)) {
          await txn.delete(
            'form_fields',
            where: 'form_id = ? AND id = ?',
            whereArgs: [formId, oldId],
          );
        }
      }
      for (var i = 0; i < fields.length; i++) {
        final f = fields[i];
        final order = i + 1;
        final payload = {
          'label': f.label.trim(),
          'field_type': _dbTypeForSettings(f.type),
          'display_order': order,
          'options_json': null,
          'default_value': f.defaultValue?.trim().isEmpty ?? true
              ? null
              : f.defaultValue!.trim(),
        };
        final exists = await txn.query(
          'form_fields',
          where: 'form_id = ? AND id = ?',
          whereArgs: [formId, f.id],
          limit: 1,
        );
        if (exists.isNotEmpty) {
          await txn.update(
            'form_fields',
            payload,
            where: 'form_id = ? AND id = ?',
            whereArgs: [formId, f.id],
          );
        } else {
          await txn.insert('form_fields', {
            'form_id': formId,
            'id': f.id,
            ...payload,
          });
        }
      }
    });
    await _settings.saveHomeColumnFieldIds(fields.map((f) => f.id).toList());
    await _settings.mergeUserFieldLibrary(fields);
  }

  /// Removes all maintenance records and custom form field definitions.
  Future<void> clearAllUserData() async {
    final formId = await getCustomFormId();
    await _raw.transaction((txn) async {
      final records = await txn.query(
        'maintenance_records',
        columns: ['id'],
        where: 'form_id = ?',
        whereArgs: [formId],
      );
      for (final r in records) {
        await txn.delete(
          'record_field_values',
          where: 'record_id = ?',
          whereArgs: [r['id']],
        );
      }
      await txn.delete(
        'maintenance_records',
        where: 'form_id = ?',
        whereArgs: [formId],
      );
      await txn.delete(
        'form_fields',
        where: 'form_id = ?',
        whereArgs: [formId],
      );
    });
    await _settings.clearHomeColumnFieldIds();
    await _settings.clearUserFieldLibrary();
    await _settings.saveExcelColumnMapping({});
    await clearAllAiAnswers();
  }

  Future<List<FieldDefinition>> getUserCreatedFieldLibrary() {
    return _settings.loadUserFieldLibrary();
  }

  Future<int> addDefaultFieldTemplates(
    List<DefaultFieldTemplate> templates,
  ) async {
    final existing = await getCustomFormFields();
    final existingLabels = {
      for (final f in existing) f.label.toLowerCase(),
    };
    var added = 0;
    for (final template in templates) {
      if (existingLabels.contains(template.label.toLowerCase())) continue;
      await addCustomFormField(
        label: template.label,
        type: template.type,
        defaultValue: template.defaultValue,
      );
      existingLabels.add(template.label.toLowerCase());
      added++;
    }
    return added;
  }

  Future<int> generateRandomRecords(
    int count, {
    List<String>? fieldIds,
  }) async {
    if (count < 1) return 0;
    final formId = await getCustomFormId();
    var fields = await getCustomFormFields();
    if (fieldIds != null && fieldIds.isNotEmpty) {
      final idSet = fieldIds.toSet();
      fields = fields.where((f) => idSet.contains(f.id)).toList();
    }
    if (fields.isEmpty) {
      throw StateError('Save at least one field in Settings first.');
    }
    final generator = RandomRecordGenerator();
    final now = DateTime.now();
    await _raw.transaction((txn) async {
      for (var i = 0; i < count; i++) {
        final createdAt = generator.randomCreatedAt(now);
        final values = generator.generateValues(fields, referenceDate: now);
        final recordId = await txn.insert('maintenance_records', {
          'form_id': formId,
          'created_at': createdAt.toUtc().toIso8601String(),
          'updated_at': createdAt.toUtc().toIso8601String(),
        });
        for (final entry in values.entries) {
          final v = entry.value;
          if (v == null) continue;
          if (v is String && v.trim().isEmpty) continue;
          await txn.insert('record_field_values', {
            'record_id': recordId,
            'field_id': entry.key,
            ...recordValueColumns(v),
          });
        }
      }
    });
    return count;
  }

  Future<void> addCustomFormField({
    required String label,
    required FieldType type,
    String? defaultValue,
  }) async {
    final formId = await getCustomFormId();
    var id = fieldIdFromLabel(label);
    var suffix = 1;
    while (await _fieldExists(formId, id)) {
      id = '${fieldIdFromLabel(label)}_$suffix';
      suffix++;
    }
    final orderRow = await _raw.rawQuery(
      'SELECT COALESCE(MAX(display_order), 0) + 1 AS n FROM form_fields WHERE form_id = ?',
      [formId],
    );
    final order = orderRow.first['n'] as int? ?? 1;
    await _raw.insert('form_fields', {
      'form_id': formId,
      'id': id,
      'label': label.trim(),
      'field_type': _dbTypeForSettings(type),
      'display_order': order,
      'options_json': null,
      'default_value': defaultValue?.trim().isEmpty ?? true ? null : defaultValue!.trim(),
    });
  }

  Future<void> updateCustomFormField({
    required String fieldId,
    required String label,
    required FieldType type,
    String? defaultValue,
  }) async {
    final formId = await getCustomFormId();
    await _raw.update(
      'form_fields',
      {
        'label': label.trim(),
        'field_type': _dbTypeForSettings(type),
        'default_value':
            defaultValue?.trim().isEmpty ?? true ? null : defaultValue!.trim(),
      },
      where: 'form_id = ? AND id = ?',
      whereArgs: [formId, fieldId],
    );
  }

  Future<void> deleteCustomFormField(String fieldId) async {
    final formId = await getCustomFormId();
    await _raw.delete(
      'form_fields',
      where: 'form_id = ? AND id = ?',
      whereArgs: [formId, fieldId],
    );
  }

  Future<bool> _fieldExists(int formId, String fieldId) async {
    final rows = await _raw.query(
      'form_fields',
      columns: ['id'],
      where: 'form_id = ? AND id = ?',
      whereArgs: [formId, fieldId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  String _dbTypeForSettings(FieldType type) {
    switch (type) {
      case FieldType.number:
        return 'number';
      case FieldType.date:
        return 'date';
      case FieldType.text:
        return 'text';
      default:
        return 'text';
    }
  }

  Future<int> importRecordsBatch(
    List<Map<String, dynamic>> rows, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (rows.isEmpty) return 0;
    final formId = await getCustomFormId();
    var imported = 0;
    await _raw.transaction((txn) async {
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final values = row['values'] as Map<String, dynamic>? ?? {};
        final createdAt = row['createdAt'] as DateTime? ?? DateTime.now();
        final recordId = await txn.insert('maintenance_records', {
          'form_id': formId,
          'created_at': createdAt.toUtc().toIso8601String(),
          'updated_at': createdAt.toUtc().toIso8601String(),
        });
        for (final entry in values.entries) {
          final v = entry.value;
          if (v == null) continue;
          if (v is String && v.trim().isEmpty) continue;
          await txn.insert('record_field_values', {
            'record_id': recordId,
            'field_id': entry.key,
            ...recordValueColumns(v),
          });
        }
        imported++;
        onProgress?.call(i + 1, rows.length);
      }
    });
    return imported;
  }

  Future<void> saveExcelColumnMapping(Map<String, String> mapping) {
    return _settings.saveExcelColumnMapping(mapping);
  }

  Future<Map<String, String>> loadExcelColumnMapping() {
    return _settings.loadExcelColumnMapping();
  }

  Future<String> resolveExcelImportDirectory() async {
    final projectDir = ProjectPaths.ensureImportDirectory().path;
    final saved = await _settings.loadExcelImportDirectory();
    if (saved != null && saved.isNotEmpty && Directory(saved).existsSync()) {
      // Legacy default was .../maintenance/sample; open project root instead.
      if (p.normalize(saved) == p.normalize(p.join(projectDir, 'sample'))) {
        return projectDir;
      }
      return saved;
    }
    return projectDir;
  }

  Future<void> saveExcelImportDirectory(String directory) {
    return _settings.saveExcelImportDirectory(directory);
  }

  Future<String?> loadLastImportFilePath() {
    return _settings.loadLastImportFilePath();
  }

  Future<void> saveLastImportFilePath(String path) {
    return _settings.saveLastImportFilePath(path);
  }

  Future<int> createRecord({
    required int formId,
    required Map<String, dynamic> values,
    DateTime? createdAt,
  }) async {
    final now = (createdAt ?? DateTime.now()).toUtc();
    final recordId = await _raw.insert('maintenance_records', {
      'form_id': formId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await _saveFieldValues(recordId, values);
    return recordId;
  }

  Future<void> updateRecord({
    required int recordId,
    required Map<String, dynamic> values,
  }) async {
    await _raw.update(
      'maintenance_records',
      {'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [recordId],
    );
    await _raw.delete(
      'record_field_values',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    await _saveFieldValues(recordId, values);
  }

  Future<void> _saveFieldValues(int recordId, Map<String, dynamic> values) async {
    for (final entry in values.entries) {
      final v = entry.value;
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      await _raw.insert('record_field_values', {
        'record_id': recordId,
        'field_id': entry.key,
        ...recordValueColumns(v),
      });
    }
  }

  Future<Map<String, dynamic>> getRecordRawValues(int recordId) async {
    final rows = await _raw.query(
      'record_field_values',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    final out = <String, dynamic>{};
    for (final row in rows) {
      final fieldId = row['field_id'] as String;
      final dateIso = row['value_date_iso'] as String?;
      if (dateIso != null && dateIso.isNotEmpty) {
        out[fieldId] = DateTime.parse(dateIso);
        continue;
      }
      final real = row['value_real'];
      if (real != null) {
        out[fieldId] = real;
        continue;
      }
      out[fieldId] = row['value_text'] as String? ?? '';
    }
    return out;
  }

  String _displayFromRow(Map<String, Object?> row) {
    final dateIso = row['value_date_iso'] as String?;
    if (dateIso != null && dateIso.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateIso).toLocal();
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        return '$day/$month/${dt.year}';
      } catch (_) {
        return dateIso;
      }
    }
    final real = row['value_real'];
    if (real != null) return real.toString();
    final text = row['value_text'] as String?;
    if (text != null && text.isNotEmpty) return text;
    final intVal = row['value_int'];
    if (intVal != null) return intVal == 1 ? 'Yes' : 'No';
    return '';
  }
}
