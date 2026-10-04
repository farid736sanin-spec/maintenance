import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/filters.dart';
import '../maintenance_home_controller.dart';

class ActiveFiltersBar extends StatelessWidget {
  const ActiveFiltersBar({super.key, required this.controller});

  final MaintenanceHomeController controller;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (controller.searchText.isNotEmpty) {
      chips.add(
        _chip(
          context,
          'Search: "${controller.searchText}"',
          () => controller.setSearch(''),
        ),
      );
    }

    for (final filter in controller.columnFilters) {
      chips.add(
        _chip(
          context,
          _labelForFilter(filter, controller),
          () => controller.removeFilter(filter.fieldId),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Filters:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...chips,
                Tooltip(
                  message: 'Clear all filters',
                  child: ActionChip(
                    avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Clear'),
                    onPressed: controller.clearFilters,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
    );
  }

  String _labelForFilter(
    RecordFilter filter,
    MaintenanceHomeController controller,
  ) {
    final col = controller.columnById(filter.fieldId);
    final name = col?.label ?? filter.fieldId;
    switch (filter.operator) {
      case FilterOperator.between:
        if (filter.value is DateTime || filter.valueTo is DateTime) {
          final fmt = DateFormat('MMM d');
          final from = filter.value is DateTime
              ? fmt.format((filter.value as DateTime).toLocal())
              : '…';
          final to = filter.valueTo is DateTime
              ? fmt.format((filter.valueTo as DateTime).toLocal())
              : '…';
          return '$name: $from - $to';
        }
        return '$name: ${filter.value} - ${filter.valueTo}';
      case FilterOperator.inList:
        final list = (filter.value as List?)?.join(', ') ?? '';
        return '$name: $list';
      case FilterOperator.contains:
        return '$name ∋ ${filter.value}';
      case FilterOperator.greaterThan:
        return '$name > ${filter.value}';
      case FilterOperator.lessThan:
        return '$name < ${filter.value}';
      case FilterOperator.greaterThanOrEqual:
        return '$name ≥ ${filter.value}';
      case FilterOperator.lessThanOrEqual:
        return '$name ≤ ${filter.value}';
      case FilterOperator.equals:
        if (filter.value == true) return '$name: Yes';
        if (filter.value == false) return '$name: No';
        return '$name: ${filter.value}';
      default:
        return '$name';
    }
  }
}
