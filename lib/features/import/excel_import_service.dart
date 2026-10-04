import 'dart:io';

import 'package:excel/excel.dart';

import '../../models/field_definition.dart';

const recordDateMappingKey = '__record_date__';

class ExcelParseResult {
  ExcelParseResult({
    required this.headers,
    required this.rows,
    required this.sheetName,
  });

  final List<String> headers;
  final List<List<String?>> rows;
  final String sheetName;
}

class ExcelImportService {
  ExcelParseResult parseFile(File file) {
    final bytes = file.readAsBytesSync();
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw FormatException('Excel file has no sheets');
    }
    final sheetName = workbook.tables.keys.first;
    final sheet = workbook.tables[sheetName]!;
    if (sheet.rows.isEmpty) {
      throw FormatException('Sheet is empty');
    }

    final headerRow = sheet.rows.first;
    final headers = <String>[];
    for (var i = 0; i < headerRow.length; i++) {
      final text = _cellToString(headerRow[i]?.value)?.trim() ?? '';
      headers.add(text.isEmpty ? 'Column ${i + 1}' : text);
    }

    final dataRows = <List<String?>>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final cells = <String?>[];
      var hasData = false;
      for (var c = 0; c < headers.length; c++) {
        final text = c < row.length ? _cellToString(row[c]?.value) : null;
        if (text != null && text.trim().isNotEmpty) hasData = true;
        cells.add(text);
      }
      if (hasData) dataRows.add(cells);
    }

    return ExcelParseResult(
      headers: headers,
      rows: dataRows,
      sheetName: sheetName,
    );
  }

  /// fieldId (or [recordDateMappingKey]) -> excel header name
  Map<String, String> suggestMapping({
    required List<String> excelHeaders,
    required List<FieldDefinition> appFields,
  }) {
    final mapping = <String, String>{};
    final used = <String>{};

    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final field in appFields) {
      final fieldNorm = norm(field.label);
      for (final header in excelHeaders) {
        if (used.contains(header)) continue;
        if (norm(header) == fieldNorm ||
            norm(header).contains(fieldNorm) ||
            fieldNorm.contains(norm(header))) {
          mapping[field.id] = header;
          used.add(header);
          break;
        }
      }
    }

    for (final header in excelHeaders) {
      if (used.contains(header)) continue;
      final h = norm(header);
      if (h == 'date' || h.contains('recorddate') || h == 'created') {
        mapping[recordDateMappingKey] = header;
        used.add(header);
      }
    }
    return mapping;
  }

  List<Map<String, dynamic>> buildRecords({
    required ExcelParseResult parsed,
    required Map<String, String> mapping,
    required List<FieldDefinition> appFields,
  }) {
    final fieldById = {for (final f in appFields) f.id: f};
    final headerIndex = {
      for (var i = 0; i < parsed.headers.length; i++) parsed.headers[i]: i,
    };

    final out = <Map<String, dynamic>>[];
    for (final row in parsed.rows) {
      final values = <String, dynamic>{};
      DateTime? createdAt;

      mapping.forEach((fieldId, header) {
        final idx = headerIndex[header];
        if (idx == null || idx >= row.length) return;
        final raw = row[idx]?.trim();
        if (raw == null || raw.isEmpty) return;

        if (fieldId == recordDateMappingKey) {
          createdAt = _parseDate(raw);
          return;
        }
        final field = fieldById[fieldId];
        if (field == null) return;
        values[fieldId] = _coerce(raw, field.type);
      });

      if (values.isEmpty && createdAt == null) continue;
      out.add({
        'values': values,
        if (createdAt != null) 'createdAt': createdAt,
      });
    }
    return out;
  }

  dynamic _coerce(String raw, FieldType type) {
    switch (type) {
      case FieldType.number:
        return double.tryParse(raw.replaceAll(',', '.')) ?? raw;
      case FieldType.date:
        return _parseDate(raw) ?? raw;
      default:
        return raw;
    }
  }

  DateTime? _parseDate(String raw) {
    final parts = raw.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(raw);
  }

  String? _cellToString(CellValue? value) {
    if (value == null) return null;
    if (value is TextCellValue) return value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'Yes' : 'No';
    if (value is DateCellValue) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    }
    if (value is DateTimeCellValue) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    }
    if (value is TimeCellValue) return '${value.hour}:${value.minute}';
    if (value is FormulaCellValue) return value.formula.toString();
    return null;
  }
}
