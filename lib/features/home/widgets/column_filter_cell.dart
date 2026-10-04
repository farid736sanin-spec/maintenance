import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/filters.dart';
import '../../../models/field_definition.dart';
import '../date_filter_helpers.dart';
import '../maintenance_home_controller.dart';

class ColumnFilterCell extends StatefulWidget {
  const ColumnFilterCell({
    super.key,
    required this.column,
    required this.controller,
  });

  final FieldDefinition column;
  final MaintenanceHomeController controller;

  @override
  State<ColumnFilterCell> createState() => _ColumnFilterCellState();
}

class _ColumnFilterCellState extends State<ColumnFilterCell> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.center,
        child: _buildForType(context),
      ),
    );
  }

  Widget _buildForType(BuildContext context) {
    switch (widget.column.type) {
      case FieldType.text:
        return SizedBox(
          height: 36,
          child: TextField(
            controller: _textController,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search…',
              hintStyle: Theme.of(context).textTheme.bodySmall,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              suffixIcon: _textController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _textController.clear();
                        widget.controller.removeFilter(widget.column.id);
                        setState(() {});
                      },
                    ),
            ),
            onSubmitted: (v) {
              if (v.trim().isEmpty) {
                widget.controller.removeFilter(widget.column.id);
              } else {
                widget.controller.setColumnFilter(
                  RecordFilter(
                    fieldId: widget.column.id,
                    operator: FilterOperator.contains,
                    value: v.trim(),
                  ),
                );
              }
            },
            onChanged: (_) => setState(() {}),
          ),
        );
      case FieldType.number:
        return _FilterTriggerButton(
          label: 'Filter…',
          icon: Icons.filter_alt_outlined,
          onPressed: () => _openNumberFilterDialog(context),
        );
      case FieldType.date:
        return _FilterTriggerButton(
          label: 'Dates…',
          icon: Icons.date_range_outlined,
          onPressed: () => showDateColumnFilterDialog(
            context: context,
            columnLabel: widget.column.label,
            columnId: widget.column.id,
            controller: widget.controller,
          ),
        );
      case FieldType.dropdown:
        return _FilterTriggerButton(
          label: 'Select…',
          icon: Icons.arrow_drop_down,
          onPressed: () => _openDropdownFilter(context),
        );
      case FieldType.boolean:
        return SizedBox(
          height: 36,
          child: DropdownButtonFormField<bool?>(
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            initialValue: null,
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: true, child: Text('Yes')),
              DropdownMenuItem(value: false, child: Text('No')),
            ],
            onChanged: (value) {
              if (value == null) {
                widget.controller.removeFilter(widget.column.id);
              } else {
                widget.controller.setColumnFilter(
                  RecordFilter(
                    fieldId: widget.column.id,
                    operator: FilterOperator.equals,
                    value: value,
                  ),
                );
              }
            },
          ),
        );
    }
  }

  Future<void> _openNumberFilterDialog(BuildContext context) async {
    var op = FilterOperator.greaterThan;
    final valueController = TextEditingController();
    final valueToController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${widget.column.label} filter'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<FilterOperator>(
                      value: op,
                      decoration: const InputDecoration(labelText: 'Operator'),
                      items: const [
                        DropdownMenuItem(value: FilterOperator.equals, child: Text('=')),
                        DropdownMenuItem(value: FilterOperator.greaterThan, child: Text('>')),
                        DropdownMenuItem(value: FilterOperator.lessThan, child: Text('<')),
                        DropdownMenuItem(
                          value: FilterOperator.greaterThanOrEqual,
                          child: Text('≥'),
                        ),
                        DropdownMenuItem(
                          value: FilterOperator.lessThanOrEqual,
                          child: Text('≤'),
                        ),
                        DropdownMenuItem(
                          value: FilterOperator.between,
                          child: Text('Between'),
                        ),
                      ],
                      onChanged: (v) => setState(() => op = v ?? op),
                    ),
                    TextField(
                      controller: valueController,
                      decoration: const InputDecoration(labelText: 'Value'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (op == FilterOperator.between)
                      TextField(
                        controller: valueToController,
                        decoration: const InputDecoration(labelText: 'To'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.controller.removeFilter(widget.column.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () {
                    final raw = valueController.text.trim();
                    if (raw.isEmpty) {
                      widget.controller.removeFilter(widget.column.id);
                    } else if (op == FilterOperator.between) {
                      widget.controller.setColumnFilter(
                        RecordFilter(
                          fieldId: widget.column.id,
                          operator: op,
                          value: double.tryParse(raw),
                          valueTo: double.tryParse(valueToController.text.trim()),
                        ),
                      );
                    } else {
                      widget.controller.setColumnFilter(
                        RecordFilter(
                          fieldId: widget.column.id,
                          operator: op,
                          value: double.tryParse(raw),
                        ),
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    valueController.dispose();
    valueToController.dispose();
  }

  Future<void> _openDropdownFilter(BuildContext context) async {
    final options = widget.column.options.isNotEmpty
        ? widget.column.options
        : await widget.controller.distinctValuesFor(widget.column.id);
    if (!context.mounted) return;
    final selected = <String>{};
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(widget.column.label),
              content: SizedBox(
                width: 280,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final opt in options)
                      CheckboxListTile(
                        value: selected.contains(opt),
                        title: Text(opt),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(opt);
                            } else {
                              selected.remove(opt);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.controller.removeFilter(widget.column.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.controller.setColumnFilter(
                      RecordFilter(
                        fieldId: widget.column.id,
                        operator: FilterOperator.inList,
                        value: selected.toList(),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FilterTriggerButton extends StatelessWidget {
  const _FilterTriggerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

Future<void> showDateColumnFilterDialog({
  required BuildContext context,
  required String columnLabel,
  required String columnId,
  required MaintenanceHomeController controller,
}) async {
  DateTime? from;
  DateTime? to;
  final presets = datePresets(DateTime.now());

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('$columnLabel filter'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Preset'),
                    initialValue: null,
                    items: [
                      for (final p in presets)
                        DropdownMenuItem(value: p.label, child: Text(p.label)),
                    ],
                    onChanged: (label) {
                      if (label == null) return;
                      final preset = presets.firstWhere((p) => p.label == label);
                      setState(() {
                        from = preset.from;
                        to = preset.to;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: from ?? DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => from = picked);
                            }
                          },
                          child: Text(
                            from == null
                                ? 'From'
                                : DateFormat('dd/MM/yyyy').format(from!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: to ?? DateTime.now(),
                            );
                            if (picked != null) {
                              setState(
                                () => to = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  23,
                                  59,
                                  59,
                                  999,
                                ),
                              );
                            }
                          },
                          child: Text(
                            to == null ? 'To' : DateFormat('dd/MM/yyyy').format(to!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.removeFilter(columnId);
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: () {
                  controller.setColumnFilter(
                    dateRangeFilter(columnId, from, to),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    },
  );
}
