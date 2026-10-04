import 'dart:io';

import 'package:path/path.dart' as p;

/// Project root used as default folder for Excel import file picker.
class ProjectPaths {
  static String get importDirectory {
    final home = Platform.environment['HOME'] ?? '';
    return p.normalize(p.join(home, 'code', 'maintenance'));
  }

  static String get sampleExcelFile =>
      p.join(importDirectory, 'maintenance_import_sample.xlsx');

  static Directory ensureImportDirectory() {
    final dir = Directory(importDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }
}
