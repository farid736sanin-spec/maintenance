import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/maintenance_repository.dart';
import '../../models/default_field_templates.dart';
import '../../models/field_definition.dart';
import '../../utils/field_id.dart';
import '../../widgets/kernel_build_button.dart';
import 'appearance_settings_section.dart';
import 'field_editor_dialog.dart';
import 'generate_random_data_dialog.dart';
import 'lm_studio_settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<FieldDefinition> _draftFields = [];
  List<FieldDefinition> _userLibrary = [];
  final Set<String> _selectedTemplateLabels = {};
  final Set<String> _selectedUserFieldIds = {};
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<MaintenanceRepository>();
    _draftFields = await repo.getCustomFormFields();
    _userLibrary = await repo.getUserCreatedFieldLibrary();
    _dirty = false;
    if (mounted) setState(() => _loading = false);
  }

  bool _templateInDraft(DefaultFieldTemplate template) {
    return _draftFields.any(
      (f) => f.label.toLowerCase() == template.label.toLowerCase(),
    );
  }

  bool _userFieldInDraft(FieldDefinition field) {
    return _draftFields.any(
      (f) => f.label.toLowerCase() == field.label.toLowerCase(),
    );
  }

  void _addFieldDefinitionToDraft(FieldDefinition source) {
    var id = source.id;
    var suffix = 1;
    while (_draftFields.any((f) => f.id == id)) {
      id = '${source.id}_$suffix';
      suffix++;
    }
    _draftFields.add(
      FieldDefinition(
        id: id,
        label: source.label,
        type: source.type,
        defaultValue: source.defaultValue,
      ),
    );
  }

  void _addSelectedTemplatesToDraft() {
    final toAdd = DefaultFieldTemplate.catalog
        .where((t) => _selectedTemplateLabels.contains(t.label))
        .where((t) => !_templateInDraft(t))
        .toList();
    if (toAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select fields not already in your list')),
      );
      return;
    }
    setState(() {
      for (final template in toAdd) {
        var id = fieldIdFromLabel(template.label);
        var suffix = 1;
        while (_draftFields.any((f) => f.id == id)) {
          id = '${fieldIdFromLabel(template.label)}_$suffix';
          suffix++;
        }
        _draftFields.add(
          FieldDefinition(
            id: id,
            label: template.label,
            type: template.type,
            defaultValue: template.defaultValue,
          ),
        );
      }
      _selectedTemplateLabels.clear();
      _dirty = true;
    });
  }

  void _addSelectedUserFieldsToDraft() {
    final toAdd = _userLibrary
        .where((f) => _selectedUserFieldIds.contains(f.id))
        .where((f) => !_userFieldInDraft(f))
        .toList();
    if (toAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select fields you created that are not already in the list',
          ),
        ),
      );
      return;
    }
    setState(() {
      for (final field in toAdd) {
        _addFieldDefinitionToDraft(field);
      }
      _selectedUserFieldIds.clear();
      _dirty = true;
    });
  }

  Future<void> _addCustomField() async {
    final saved = await showFieldEditorDialog(
      context,
      userCreatedFields: _userLibrary,
    );
    if (saved == null || !mounted) return;
    setState(() {
      _addFieldDefinitionToDraft(
        FieldDefinition(
          id: fieldIdFromLabel(saved.label),
          label: saved.label,
          type: saved.type,
          defaultValue: saved.defaultValue,
        ),
      );
      _dirty = true;
    });
  }

  Future<void> _pickUserFieldOnly() async {
    if (_userLibrary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No saved fields yet. Create a custom field and press Save first.',
          ),
        ),
      );
      return;
    }
    final picked = await showDialog<FieldDefinition>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select from fields you created'),
        children: [
          SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in _userLibrary)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, f),
                    child: Text(
                      '${f.label} (${_typeLabel(f.type)})'
                      '${f.defaultValue != null ? ' · ${f.defaultValue}' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (_userFieldInDraft(picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${picked.label}" is already in your list')),
      );
      return;
    }
    setState(() {
      _addFieldDefinitionToDraft(picked);
      _dirty = true;
    });
  }

  Future<void> _editField(int index) async {
    final field = _draftFields[index];
    final saved = await showFieldEditorDialog(
      context,
      existing: field,
      userCreatedFields: _userLibrary,
    );
    if (saved == null || !mounted) return;
    setState(() {
      _draftFields[index] = FieldDefinition(
        id: field.id,
        label: saved.label,
        type: saved.type,
        defaultValue: saved.defaultValue,
      );
      _dirty = true;
    });
  }

  void _removeField(int index) {
    setState(() {
      _draftFields.removeAt(index);
      _dirty = true;
    });
  }

  void _flushPendingSelectionsIntoDraft() {
    final templates = DefaultFieldTemplate.catalog
        .where((t) => _selectedTemplateLabels.contains(t.label))
        .where((t) => !_templateInDraft(t));
    for (final template in templates) {
      _addFieldDefinitionToDraft(
        FieldDefinition(
          id: fieldIdFromLabel(template.label),
          label: template.label,
          type: template.type,
          defaultValue: template.defaultValue,
        ),
      );
    }
    _selectedTemplateLabels.clear();

    final fromLibrary = _userLibrary
        .where((f) => _selectedUserFieldIds.contains(f.id))
        .where((f) => !_userFieldInDraft(f));
    for (final field in fromLibrary) {
      _addFieldDefinitionToDraft(field);
    }
    _selectedUserFieldIds.clear();
  }

  Future<void> _save() async {
    setState(_flushPendingSelectionsIntoDraft);
    if (_draftFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select fields and use "Add selected to list", or add a custom field, then Save.',
          ),
        ),
      );
      return;
    }
    final repo = context.read<MaintenanceRepository>();
    try {
      await repo.syncCustomFormFields(_draftFields);
      _userLibrary = await repo.getUserCreatedFieldLibrary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${_draftFields.length} field(s). Home page updated.',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _clearAllData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'Deletes all your maintenance records and saved field definitions. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<MaintenanceRepository>().clearAllUserData();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All data cleared')));
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your field changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _generateRandom() async {
    if (_draftFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add and save fields first')),
      );
      return;
    }
    if (_dirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save settings before generating data')),
      );
      return;
    }
    final count = await showGenerateRandomDataDialog(
      context,
      availableFields: _draftFields,
    );
    if (count != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated $count random record(s)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            if (_dirty)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: Text('Unsaved')),
              ),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: const Text('Save'),
            ),
            const KernelBuildButton(),
            const SizedBox(width: 12),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const _SettingsSection(
                    title: 'Appearance',
                    icon: Icons.palette_outlined,
                    children: [AppearanceSettingsSection()],
                  ),
                  const SizedBox(height: 12),
                  const _SettingsSection(
                    title: 'AI',
                    icon: Icons.smart_toy_outlined,
                    children: [LmStudioSettingsSection()],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: 'Add from default fields',
                    icon: Icons.playlist_add,
                    children: [
                      const Text(
                        'Check fields below, then press Save (checked items are added automatically). '
                        'Or use "Add selected to list" first, then Save.',
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i < DefaultFieldTemplate.catalog.length;
                              i++
                            ) ...[
                              if (i > 0) const Divider(height: 1),
                              _templateTile(DefaultFieldTemplate.catalog[i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: _addSelectedTemplatesToDraft,
                          child: const Text('Add selected to list'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: 'Fields you created',
                    icon: Icons.library_books_outlined,
                    children: [
                      const Text(
                        'Re-use fields from your library (saved when you press Save). '
                        'Select and add them to the list below.',
                      ),
                      const SizedBox(height: 12),
                      if (_userLibrary.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No saved fields yet. Add a custom field and Save once.',
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < _userLibrary.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _userLibraryTile(_userLibrary[i]),
                              ],
                            ],
                          ),
                        ),
                      if (_userLibrary.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonal(
                            onPressed: _addSelectedUserFieldsToDraft,
                            child: const Text('Add selected to list'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: 'Fields for home page & new records',
                    icon: Icons.view_column_outlined,
                    children: [
                      if (_draftFields.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No fields in your list yet. Add defaults or a custom field, then Save.',
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < _draftFields.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  title: Text(_draftFields[i].label),
                                  subtitle: Text(
                                    '${_typeLabel(_draftFields[i].type)}'
                                    '${_draftFields[i].defaultValue != null ? ' · default: ${_draftFields[i].defaultValue}' : ''}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _editField(i),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _removeField(i),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addCustomField,
                            icon: const Icon(Icons.add),
                            label: const Text('Add custom field'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickUserFieldOnly,
                            icon: const Icon(Icons.library_add_outlined),
                            label: const Text('Select from my fields'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: 'Test data',
                    icon: Icons.auto_awesome,
                    children: [
                      const Text(
                        'Generate random rows only for saved fields you select in the dialog.',
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _generateRandom,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate random records…'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsSection(
                    title: 'Reset',
                    icon: Icons.restart_alt,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _clearAllData,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Clear all data'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _userLibraryTile(FieldDefinition field) {
    final inDraft = _userFieldInDraft(field);
    return CheckboxListTile(
      value: inDraft || _selectedUserFieldIds.contains(field.id),
      title: Text(field.label),
      subtitle: Text(
        '${_typeLabel(field.type)}'
        '${field.defaultValue != null ? ' · default: ${field.defaultValue}' : ''}',
      ),
      enabled: !inDraft,
      secondary: inDraft
          ? const Icon(Icons.check_circle_outline, color: Colors.green)
          : null,
      onChanged: inDraft
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  _selectedUserFieldIds.add(field.id);
                } else {
                  _selectedUserFieldIds.remove(field.id);
                }
              });
            },
    );
  }

  Widget _templateTile(DefaultFieldTemplate template) {
    final inDraft = _templateInDraft(template);
    final subtitle = StringBuffer(_typeLabel(template.type));
    if (template.defaultValue != null) {
      subtitle.write(' · default: ${template.defaultValue}');
    }
    return CheckboxListTile(
      value: inDraft || _selectedTemplateLabels.contains(template.label),
      title: Text(template.label),
      subtitle: Text(subtitle.toString()),
      enabled: !inDraft,
      secondary: inDraft
          ? const Icon(Icons.check_circle_outline, color: Colors.green)
          : null,
      onChanged: inDraft
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  _selectedTemplateLabels.add(template.label);
                } else {
                  _selectedTemplateLabels.remove(template.label);
                }
              });
            },
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
}

/// Collapsible accordion card used for each settings group.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(icon),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }
}
