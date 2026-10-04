import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../config/project_paths.dart';
import '../../data/maintenance_repository.dart';
import '../../models/field_definition.dart';
import 'desktop_excel_file_picker.dart';
import 'excel_import_service.dart';

String _seedExcelPath({
  required String initialDir,
  required String? lastImportPath,
}) {
  if (lastImportPath != null && File(lastImportPath).existsSync()) {
    return lastImportPath;
  }
  final sample = ProjectPaths.sampleExcelFile;
  if (File(sample).existsSync()) return sample;
  return p.join(initialDir, 'maintenance_import_sample.xlsx');
}

Future<int?> showExcelImportFlow(BuildContext context) async {
  final repo = context.read<MaintenanceRepository>();
  final fields = await repo.getCustomFormFields();
  if (!context.mounted) return null;
  if (fields.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save fields in Settings before importing')),
    );
    return null;
  }

  ProjectPaths.ensureImportDirectory();
  final initialDir = await repo.resolveExcelImportDirectory();
  final lastPath = await repo.loadLastImportFilePath();
  final seedPath = _seedExcelPath(
    initialDir: initialDir,
    lastImportPath: lastPath,
  );

  if (!context.mounted) return null;

  final path = await pickExcelFilePath(
    initialDirectory: initialDir,
    seedFilePath: seedPath,
    dialogTitle: 'Import Excel — $initialDir',
  );
  if (path == null || !context.mounted) return null;

  final file = File(path);
  await repo.saveExcelImportDirectory(file.parent.path);
  await repo.saveLastImportFilePath(path);

  if (!context.mounted) return null;

  return showDialog<int>(
    context: context,
    builder: (context) => ExcelImportDialog(
      file: file,
      appFields: fields,
    ),
  );
}

class ExcelImportDialog extends StatefulWidget {
  const ExcelImportDialog({
    super.key,
    required this.file,
    required this.appFields,
  });

  final File file;
  final List<FieldDefinition> appFields;

  @override
  State<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends State<ExcelImportDialog> {
  final _service = ExcelImportService();
  ExcelParseResult? _parsed;
  String? _error;
  bool _importing = false;
  final Map<String, String?> _mapping = {};
  int _progress = 0;
  int _progressTotal = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final parsed = _service.parseFile(widget.file);
      final repo = context.read<MaintenanceRepository>();
      final saved = await repo.loadExcelColumnMapping();
      final suggested = _service.suggestMapping(
        excelHeaders: parsed.headers,
        appFields: widget.appFields,
      );
      setState(() {
        _parsed = parsed;
        for (final field in widget.appFields) {
          _mapping[field.id] = saved[field.id] ?? suggested[field.id];
        }
        _mapping[recordDateMappingKey] =
            saved[recordDateMappingKey] ?? suggested[recordDateMappingKey];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _persistMappingDraft() async {
    final active = <String, String>{};
    _mapping.forEach((key, header) {
      if (header != null && header.isNotEmpty) active[key] = header;
    });
    await context.read<MaintenanceRepository>().saveExcelColumnMapping(active);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Excel'),
      content: SizedBox(
        width: 520,
        child: _error != null
            ? Text(_error!)
            : _parsed == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'File: ${widget.file.path.split('/').last}\n'
                          'Folder: ${widget.file.parent.path}\n'
                          'Sheet: ${_parsed!.sheetName} · ${_parsed!.rows.length} data rows',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Map each home page column to an Excel column:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _mapRow(
                          label: 'Date (record)',
                          mapKey: recordDateMappingKey,
                        ),
                        for (final field in widget.appFields)
                          _mapRow(label: field.label, mapKey: field.id),
                        if (_importing) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _progressTotal == 0
                                ? null
                                : _progress / _progressTotal,
                          ),
                          Text('Importing $_progress / $_progressTotal'),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _parsed == null || _importing
              ? null
              : () async {
                  await _persistMappingDraft();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Column mapping saved')),
                    );
                  }
                },
          child: const Text('Save mapping'),
        ),
        FilledButton(
          onPressed: _parsed == null || _importing ? null : _import,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _mapRow({required String label, required String mapKey}) {
    final headers = _parsed!.headers;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _mapping[mapKey],
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Skip —'),
                ),
                for (final h in headers)
                  DropdownMenuItem(value: h, child: Text(h)),
              ],
              onChanged: (v) async {
                setState(() => _mapping[mapKey] = v);
                await _persistMappingDraft();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final active = <String, String>{};
    _mapping.forEach((key, header) {
      if (header != null && header.isNotEmpty) active[key] = header;
    });
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map at least one column')),
      );
      return;
    }

    setState(() {
      _importing = true;
      _progress = 0;
      _progressTotal = _parsed!.rows.length;
    });

    try {
      final records = _service.buildRecords(
        parsed: _parsed!,
        mapping: active,
        appFields: widget.appFields,
      );
      final repo = context.read<MaintenanceRepository>();
      final count = await repo.importRecordsBatch(
        records,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _progress = done;
              _progressTotal = total;
            });
          }
        },
      );
      await repo.saveExcelColumnMapping(active);
      await repo.saveExcelImportDirectory(widget.file.parent.path);
      await repo.saveLastImportFilePath(widget.file.path);
      if (!mounted) return;
      Navigator.pop(context, count);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = e.toString();
      });
    }
  }
}
