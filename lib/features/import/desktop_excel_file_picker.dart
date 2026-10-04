import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Opens the Excel file picker starting in [initialDirectory], not "Recent".
///
/// On Linux, `file_picker` only passes a folder to Zenity/KDialog. GTK often
/// ignores that and opens Recent. Passing an existing file path as the seed
/// anchors the dialog in the right folder.
Future<String?> pickExcelFilePath({
  required String initialDirectory,
  required String seedFilePath,
  String dialogTitle = 'Import Excel',
}) async {
  if (Platform.isLinux) {
    return _pickLinux(
      initialDirectory: initialDirectory,
      seedFilePath: seedFilePath,
      dialogTitle: dialogTitle,
    );
  }

  final pick = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls'],
    withData: false,
    initialDirectory: initialDirectory,
    dialogTitle: dialogTitle,
  );
  if (pick == null || pick.files.isEmpty) return null;
  return pick.files.single.path;
}

Future<String?> _pickLinux({
  required String initialDirectory,
  required String seedFilePath,
  required String dialogTitle,
}) async {
  final executable = await _linuxDialogExecutable();
  final seed = _resolveSeedFile(initialDirectory, seedFilePath);
  final filter =
      'Excel Files | *.xlsx *.xls *.XLSX *.XLS';

  final List<String> arguments;
  if (p.basename(executable) == 'kdialog') {
    arguments = [
      '--title',
      dialogTitle,
      '--getopenfilename',
      seed,
      filter,
    ];
  } else {
    arguments = [
      '--file-selection',
      '--title',
      dialogTitle,
      '--filename=$seed',
      '--file-filter=$filter',
    ];
  }

  final result = await Process.run(executable, arguments);
  final path = result.stdout.toString().trim();
  if (result.exitCode != 0 || path.isEmpty) return null;
  if (p.basename(executable) == 'kdialog') {
    return path.split('\n').first.trim();
  }
  return path;
}

String _resolveSeedFile(String initialDirectory, String seedFilePath) {
  final normalizedDir = p.normalize(initialDirectory);
  if (seedFilePath.isNotEmpty && File(seedFilePath).existsSync()) {
    return p.normalize(seedFilePath);
  }
  final inDir = p.join(normalizedDir, p.basename(seedFilePath));
  if (File(inDir).existsSync()) {
    return p.normalize(inDir);
  }
  final dir = Directory(normalizedDir);
  if (dir.existsSync()) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.xlsx' || ext == '.xls') {
        return p.normalize(entity.path);
      }
    }
  }
  return normalizedDir;
}

Future<String> _linuxDialogExecutable() async {
  for (final name in ['qarma', 'kdialog', 'zenity']) {
    final which = await Process.run('which', [name]);
    if (which.exitCode == 0) {
      final path = which.stdout.toString().trim();
      if (path.isNotEmpty) return path;
    }
  }
  throw StateError(
    'No file dialog found (install zenity, qarma, or kdialog).',
  );
}
