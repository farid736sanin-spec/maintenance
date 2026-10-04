import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const databaseFileName = 'maintenance.db';
const databaseFolderName = 'database';

/// SQLite file beside the app executable: `{exeDir}/database/maintenance.db`.
Future<String> resolveDatabaseFilePath() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    final dir = await Directory.systemTemp.createTemp('maintenance_test_db_');
    return p.join(dir.path, databaseFileName);
  }

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final dbDir = Directory(p.join(exeDir, databaseFolderName));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final path = p.join(dbDir.path, databaseFileName);
    await _migrateFromApplicationSupportIfNeeded(path);
    return path;
  }

  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, databaseFileName);
}

Future<void> _migrateFromApplicationSupportIfNeeded(String newPath) async {
  if (File(newPath).existsSync()) return;
  try {
    final support = await getApplicationSupportDirectory();
    final legacy = File(p.join(support.path, databaseFileName));
    if (legacy.existsSync()) {
      await legacy.copy(newPath);
    }
  } catch (_) {
    // Ignore migration failures; a fresh database will be created.
  }
}
