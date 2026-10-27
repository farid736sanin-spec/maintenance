import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../widgets/kernel_build_button.dart';

/// Picks a folder, or a `.litertlm` file inside one.
Future<String?> pickModelFolder(BuildContext context, {String? start}) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (context) => _ModelFolderBrowser(start: startDirectory(start)),
    ),
  );
}

/// `.litertlm` files in [folder] and in folders inside it.
({List<File> models, String? error}) modelsInFolder(String folder) {
  final directory = Directory(folder);
  if (!directory.existsSync()) {
    return (models: const <File>[], error: 'That folder is not there.');
  }
  try {
    final models = <File>[];
    void walk(Directory dir, int depth) {
      if (depth > 4) return;
      for (final entity in dir.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          walk(entity, depth + 1);
        } else if (entity is File && isLitertModelFile(name)) {
          models.add(entity);
        }
      }
    }

    walk(directory, 0);
    models.sort(
      (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
    );
    return (models: models, error: null);
  } on Object catch (error) {
    return (models: const <File>[], error: 'Cannot open this folder. $error');
  }
}

bool isLitertModelFile(String name) => name.toLowerCase().endsWith('.litertlm');

String startDirectory(String? start) {
  if (start != null && start.isNotEmpty) {
    final type = FileSystemEntity.typeSync(start, followLinks: false);
    if (type == FileSystemEntityType.directory) return start;
    final parent = p.dirname(start);
    if (Directory(parent).existsSync()) return parent;
  }
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && Directory(home).existsSync()) return home;
  return Directory.current.path;
}

class _ModelFolderBrowser extends StatefulWidget {
  const _ModelFolderBrowser({required this.start});

  final String start;

  @override
  State<_ModelFolderBrowser> createState() => _ModelFolderBrowserState();
}

class _ModelFolderBrowserState extends State<_ModelFolderBrowser> {
  late Directory _directory;

  @override
  void initState() {
    super.initState();
    _directory = Directory(widget.start);
  }

  void _open(Directory directory) {
    setState(() => _directory = directory);
  }

  @override
  Widget build(BuildContext context) {
    final listed = _list();
    final parent = _directory.parent;
    final canGoUp = parent.path != _directory.path;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select model folder'),
        actions: const [KernelBuildButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _directory.path,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (canGoUp)
                  ListTile(
                    leading: const Icon(Icons.drive_folder_upload),
                    title: const Text('Up'),
                    onTap: () => _open(parent),
                  ),
                if (listed.error != null)
                  ListTile(title: Text(listed.error!))
                else if (listed.entries.isEmpty)
                  const ListTile(title: Text('No folders or models here'))
                else
                  for (final entity in listed.entries)
                    if (entity is Directory)
                      ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(p.basename(entity.path)),
                        onTap: () => _open(entity),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(p.basename(entity.path)),
                        subtitle: const Text('Tap to use this model'),
                        onTap: () => Navigator.pop(context, entity.path),
                      ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _directory.path),
                icon: const Icon(Icons.folder_open),
                label: const Text('Use this folder'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({List<FileSystemEntity> entries, String? error}) _list() {
    try {
      final items = _directory.listSync(followLinks: false).where((entity) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) return false;
        if (entity is Directory) return true;
        return entity is File && isLitertModelFile(name);
      }).toList();
      items.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
      return (entries: items, error: null);
    } on Object catch (error) {
      return (
        entries: const <FileSystemEntity>[],
        error: 'Cannot open this folder. $error',
      );
    }
  }
}
