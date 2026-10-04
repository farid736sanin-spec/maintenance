import 'package:flutter/material.dart';

import '../../models/default_field_templates.dart';
import '../../models/field_definition.dart';
import '../../utils/field_defaults.dart';

class FieldEditorResult {
  const FieldEditorResult({
    required this.label,
    required this.type,
    this.defaultValue,
  });

  final String label;
  final FieldType type;
  final String? defaultValue;
}

Future<FieldEditorResult?> showFieldEditorDialog(
  BuildContext context, {
  FieldDefinition? existing,
  List<FieldDefinition> userCreatedFields = const [],
}) {
  return showDialog<FieldEditorResult>(
    context: context,
    builder: (context) => _FieldEditorDialog(
      existing: existing,
      userCreatedFields: userCreatedFields,
    ),
  );
}

class _FieldEditorDialog extends StatefulWidget {
  const _FieldEditorDialog({
    this.existing,
    this.userCreatedFields = const [],
  });

  final FieldDefinition? existing;
  final List<FieldDefinition> userCreatedFields;

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _defaultController;
  late FieldType _type;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label ?? '');
    _defaultController = TextEditingController(
      text: widget.existing?.defaultValue ?? '',
    );
    _type = widget.existing?.type ?? FieldType.text;
    if (_type != FieldType.text &&
        _type != FieldType.number &&
        _type != FieldType.date) {
      _type = FieldType.text;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _defaultController.dispose();
    super.dispose();
  }

  void _applyTemplate(DefaultFieldTemplate? template) {
    if (template == null) return;
    setState(() {
      _labelController.text = template.label;
      _type = template.type;
      _defaultController.text = template.defaultValue ?? '';
    });
  }

  void _applyUserField(FieldDefinition? field) {
    if (field == null) return;
    setState(() {
      _labelController.text = field.label;
      _type = field.type;
      if (_type != FieldType.text &&
          _type != FieldType.number &&
          _type != FieldType.date) {
        _type = FieldType.text;
      }
      _defaultController.text = field.defaultValue ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add field' : 'Edit field'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.existing == null) ...[
              DropdownButtonFormField<DefaultFieldTemplate?>(
                decoration: const InputDecoration(
                  labelText: 'Start from default (optional)',
                  border: OutlineInputBorder(),
                ),
                initialValue: null,
                items: [
                  const DropdownMenuItem<DefaultFieldTemplate?>(
                    value: null,
                    child: Text('Custom field'),
                  ),
                  for (final t in DefaultFieldTemplate.catalog)
                    DropdownMenuItem(
                      value: t,
                      child: Text('${t.label} (${_typeName(t.type)})'),
                    ),
                ],
                onChanged: _applyTemplate,
              ),
              const SizedBox(height: 16),
              if (widget.userCreatedFields.isNotEmpty)
                DropdownButtonFormField<FieldDefinition?>(
                  decoration: const InputDecoration(
                    labelText: 'Select from fields you created',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: null,
                  items: [
                    const DropdownMenuItem<FieldDefinition?>(
                      value: null,
                      child: Text('—'),
                    ),
                    for (final f in widget.userCreatedFields)
                      DropdownMenuItem(
                        value: f,
                        child: Text('${f.label} (${_typeName(f.type)})'),
                      ),
                  ],
                  onChanged: _applyUserField,
                ),
              if (widget.userCreatedFields.isNotEmpty)
                const SizedBox(height: 16),
            ],
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Field name',
                border: OutlineInputBorder(),
              ),
              autofocus: widget.existing == null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FieldType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: FieldType.text, child: Text('String')),
                DropdownMenuItem(value: FieldType.number, child: Text('Number')),
                DropdownMenuItem(value: FieldType.date, child: Text('Date')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _defaultController,
              decoration: InputDecoration(
                labelText: 'Default value',
                hintText: defaultValueHint(_type),
                border: const OutlineInputBorder(),
              ),
              keyboardType: _type == FieldType.number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _typeName(FieldType type) {
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

  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a field name')),
      );
      return;
    }
    final defaultRaw = _defaultController.text.trim();
    if (defaultRaw.isNotEmpty) {
      final parsed = parseDefaultValue(_type, defaultRaw);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == FieldType.date
                  ? 'Use a valid date (dd/MM/yyyy)'
                  : 'Enter a valid number',
            ),
          ),
        );
        return;
      }
    }
    Navigator.pop(
      context,
      FieldEditorResult(
        label: label,
        type: _type,
        defaultValue: defaultRaw.isEmpty ? null : defaultRaw,
      ),
    );
  }
}
