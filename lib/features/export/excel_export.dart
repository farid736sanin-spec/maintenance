import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/field_definition.dart';
import '../../models/maintenance_record.dart';

Future<File> exportRecordsToExcel({
  required List<FieldDefinition> columns,
  required List<MaintenanceRecordRow> rows,
}) async {
  final excel = Excel.createExcel();
  final sheet = excel['Maintenance Records'];
  if (excel.sheets.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }

  for (var c = 0; c < columns.length; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
        TextCellValue(columns[c].label);
  }

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < columns.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
          .value = TextCellValue(row.displayValue(columns[c].id));
    }
  }

  final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final path =
      '${dir.path}/maintenance_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
  final bytes = excel.encode();
  final file = File(path);
  await file.writeAsBytes(bytes!, flush: true);
  return file;
}
