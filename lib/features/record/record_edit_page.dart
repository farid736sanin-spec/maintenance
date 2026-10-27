import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/maintenance_repository.dart';
import '../../models/field_definition.dart';
import '../../utils/field_defaults.dart';
import '../../widgets/kernel_build_button.dart';

class RecordEditPage extends StatefulWidget {
  const RecordEditPage({super.key, this.recordId});

  /// When null, creates a new record using Settings → custom form fields.
  final int? recordId;

  @override
  State<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends State<RecordEditPage> {
  final _formKey = GlobalKey<FormState>();
  List<FieldDefinition> _fields = [];
  int? _formId;
  bool _loading = true;
  String? _error;
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, DateTime?> _dates = {};

  bool get _isNew => widget.recordId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<MaintenanceRepository>();
    try {
      if (_isNew) {
        _formId = await repo.getCustomFormId();
        _fields = await repo.getCustomFormFields();
        _initControllers({});
      } else {
        final record = await repo.getRecordById(widget.recordId!);
        if (record == null) {
          _error = 'Record not found';
        } else {
          _formId = record.formId;
          _fields = await repo.getFieldsForRecord(widget.recordId!);
          final raw = await repo.getRecordRawValues(widget.recordId!);
          _initControllers(raw);
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _initControllers(Map<String, dynamic> existing) {
    for (final field in _fields) {
      if (field.type == FieldType.date) {
        final v = existing[field.id];
        _dates[field.id] = v is DateTime
            ? v
            : parseDefaultValue(field.type, field.defaultValue) as DateTime?;
        continue;
      }
      final existingVal = existing[field.id];
      String text;
      if (existingVal != null) {
        text = existingVal.toString();
      } else {
        text = field.defaultValue ?? '';
      }
      _textControllers[field.id] = TextEditingController(text: text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New maintenance record' : 'Edit record'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save'),
          ),
          const KernelBuildButton(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_fields.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No fields configured.'),
            const SizedBox(height: 8),
            const Text('Add fields in Settings first.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final field in _fields) ...[
            _fieldInput(field),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: Text(_isNew ? 'Create record' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _fieldInput(FieldDefinition field) {
    switch (field.type) {
      case FieldType.date:
        final date = _dates[field.id];
        return InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  date == null
                      ? 'No date selected'
                      : DateFormat('dd/MM/yyyy').format(date),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: date ?? DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _dates[field.id] = picked);
                  }
                },
                child: const Text('Pick date'),
              ),
              if (date != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dates[field.id] = null),
                ),
            ],
          ),
        );
      case FieldType.number:
        return TextFormField(
          controller: _textControllers[field.id],
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
            return null;
          },
        );
      case FieldType.text:
      default:
        return TextFormField(
          controller: _textControllers[field.id],
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          maxLines: field.label.toLowerCase().contains('problem') ? 3 : 1,
        );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.read<MaintenanceRepository>();
    final values = <String, dynamic>{};

    for (final field in _fields) {
      switch (field.type) {
        case FieldType.date:
          final d = _dates[field.id];
          if (d != null) values[field.id] = d;
        case FieldType.number:
          final raw = _textControllers[field.id]?.text.trim() ?? '';
          if (raw.isNotEmpty) {
            values[field.id] = double.parse(raw);
          }
        default:
          final raw = _textControllers[field.id]?.text.trim() ?? '';
          if (raw.isNotEmpty) values[field.id] = raw;
      }
    }

    try {
      if (_isNew) {
        await repo.createRecord(formId: _formId!, values: values);
      } else {
        await repo.updateRecord(recordId: widget.recordId!, values: values);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}
