import 'package:flutter/material.dart';

import '../../widgets/kernel_build_button.dart';

import '../../data/maintenance_repository.dart';
import '../../models/field_definition.dart';
import '../../models/maintenance_record.dart';

class RecordDetailsPage extends StatelessWidget {
  const RecordDetailsPage({
    super.key,
    required this.recordId,
    required this.repository,
  });

  final int recordId;
  final MaintenanceRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Record Details'),
        actions: const [KernelBuildButton()],
      ),
      body: FutureBuilder<(MaintenanceRecordRow?, List<FieldDefinition>)>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final record = snapshot.data?.$1;
          final fields = snapshot.data?.$2 ?? [];
          if (record == null) {
            return const Center(child: Text('Record not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                record.formName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Record #${record.id}'),
              const SizedBox(height: 16),
              for (final field in fields)
                ListTile(
                  title: Text(field.label),
                  subtitle: Text(record.fieldValues[field.id] ?? '—'),
                ),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(record.displayValue('sys_date')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<(MaintenanceRecordRow?, List<FieldDefinition>)> _load() async {
    final record = await repository.getRecordById(recordId);
    if (record == null) return (null, <FieldDefinition>[]);
    final fields = await repository.getFieldsForRecord(recordId);
    return (record, fields);
  }
}
