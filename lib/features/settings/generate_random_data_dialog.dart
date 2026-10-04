import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/maintenance_repository.dart';
import '../../models/field_definition.dart';

Future<int?> showGenerateRandomDataDialog(
  BuildContext context, {
  List<FieldDefinition>? availableFields,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _GenerateRandomDataDialog(
      availableFields: availableFields,
    ),
  );
}

class _GenerateRandomDataDialog extends StatefulWidget {
  const _GenerateRandomDataDialog({this.availableFields});

  final List<FieldDefinition>? availableFields;

  @override
  State<_GenerateRandomDataDialog> createState() =>
      _GenerateRandomDataDialogState();
}

class _GenerateRandomDataDialogState extends State<_GenerateRandomDataDialog> {
  final _controller = TextEditingController(text: '50');
  bool _working = false;
  String? _error;
  List<FieldDefinition> _fields = [];
  final Set<String> _selectedFieldIds = {};
  bool _loadingFields = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    if (widget.availableFields != null) {
      _fields = widget.availableFields!;
    } else {
      _fields = await context.read<MaintenanceRepository>().getCustomFormFields();
    }
    _selectedFieldIds.addAll(_fields.map((f) => f.id));
    if (mounted) {
      setState(() => _loadingFields = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate random records'),
      content: SizedBox(
        width: 400,
        child: _loadingFields
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose which saved fields get random values, then enter row count.',
                    ),
                    const SizedBox(height: 12),
                    if (_fields.isEmpty)
                      const Text('No saved fields. Save Settings first.')
                    else ...[
                      for (final field in _fields)
                        CheckboxListTile(
                          value: _selectedFieldIds.contains(field.id),
                          title: Text(field.label),
                          subtitle: Text(_typeLabel(field.type)),
                          onChanged: _working
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedFieldIds.add(field.id);
                                    } else {
                                      _selectedFieldIds.remove(field.id);
                                    }
                                  });
                                },
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Number of rows',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !_working,
                    ),
                    if (_working) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Generating…'),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _working || _fields.isEmpty ? null : _generate,
          child: const Text('Generate'),
        ),
      ],
    );
  }

  String _typeLabel(FieldType type) {
    switch (type) {
      case FieldType.text:
        return 'String';
      case FieldType.number:
        return 'Number';
      case FieldType.date:
        return 'Date';
      default:
        return type.name;
    }
  }

  Future<void> _generate() async {
    if (_selectedFieldIds.isEmpty) {
      setState(() => _error = 'Select at least one field');
      return;
    }
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 1) {
      setState(() => _error = 'Enter a number greater than 0');
      return;
    }
    if (parsed > 100000) {
      setState(() => _error = 'Maximum 100,000 rows per run');
      return;
    }
    setState(() {
      _error = null;
      _working = true;
    });
    try {
      final count = await context.read<MaintenanceRepository>().generateRandomRecords(
            parsed,
            fieldIds: _selectedFieldIds.toList(),
          );
      if (!mounted) return;
      Navigator.pop(context, count);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.toString();
      });
    }
  }
}
