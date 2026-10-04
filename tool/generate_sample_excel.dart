import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

void main() {
  final home = Platform.environment['HOME'] ?? '';
  final projectDir = p.normalize(p.join(home, 'code', 'maintenance'));
  Directory(projectDir).createSync(recursive: true);
  final outPath = p.join(projectDir, 'maintenance_import_sample.xlsx');

  final excel = Excel.createExcel();
  final sheet = excel['Maintenance Records'];
  if (excel.sheets.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }

  const headers = [
    'Date',
    'Problem',
    'Solution',
    'Machine',
    'Technician',
    'Priority',
  ];
  for (var c = 0; c < headers.length; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .value = TextCellValue(headers[c]);
  }

  const rows = [
    ['30/09/2026', 'Motor stopped', 'Replaced fuse', 'M-100', 'Ahmed', 'High'],
    ['29/09/2026', 'Abnormal noise', 'Bearing replaced', 'M-205', 'Ali', 'Medium'],
    ['28/09/2026', 'Oil leak', 'Tightened seal', 'CNC-04', 'Sara', 'Low'],
    ['27/09/2026', 'Sensor fault', 'Recalibrated', 'M-100', 'Ahmed', 'High'],
    ['26/09/2026', 'Belt slipping', 'Adjusted tension', 'PUMP-12', 'Omar', 'Medium'],
  ];

  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
          .value = TextCellValue(rows[r][c]);
    }
  }

  final bytes = excel.encode();
  File(outPath).writeAsBytesSync(bytes!);
  stdout.writeln('Wrote $outPath (${rows.length} rows)');
}
