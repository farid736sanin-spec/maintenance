import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/maintenance_repository.dart';
import '../../models/field_definition.dart';
import '../../models/maintenance_record.dart';
import '../../widgets/kernel_build_button.dart';
import '../export/excel_export.dart';
import '../import/excel_import_dialog.dart';
import '../record/record_details_page.dart';
import '../record/record_edit_page.dart';
import '../settings/generate_random_data_dialog.dart';
import '../settings/settings_page.dart';
import 'maintenance_home_controller.dart';
import 'widgets/active_filters_bar.dart';
import 'widgets/column_visibility_dialog.dart';
import 'widgets/pagination_bar.dart';
import 'widgets/records_table.dart';

class MaintenanceHomePage extends StatefulWidget {
  const MaintenanceHomePage({super.key});

  @override
  State<MaintenanceHomePage> createState() => _MaintenanceHomePageState();
}

class _MaintenanceHomePageState extends State<MaintenanceHomePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaintenanceHomeController>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MaintenanceHomeController>();
    final repository = context.read<MaintenanceRepository>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(context, controller),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search across all fields…',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: controller.setSearch,
                      onChanged: (v) {
                        if (v.isEmpty) controller.setSearch('');
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  _actionIcon(
                    context,
                    tooltip: 'Search',
                    icon: Icons.search,
                    onPressed: () =>
                        controller.setSearch(_searchController.text),
                    filled: true,
                  ),
                  _actionIcon(
                    context,
                    tooltip: 'Columns',
                    icon: Icons.view_column_outlined,
                    onPressed: () =>
                        showColumnVisibilityDialog(context, controller),
                  ),
                  _actionIcon(
                    context,
                    tooltip: 'Export Excel',
                    icon: Icons.download_outlined,
                    onPressed: controller.loading
                        ? null
                        : () => _export(context, controller),
                  ),
                  _actionIcon(
                    context,
                    tooltip: 'Import Excel',
                    icon: Icons.upload_file_outlined,
                    onPressed: controller.loading
                        ? null
                        : () => _importExcel(context, controller),
                  ),
                  _actionIcon(
                    context,
                    tooltip: 'Generate random data',
                    icon: Icons.auto_awesome_outlined,
                    onPressed: controller.loading
                        ? null
                        : () => _generateRandom(context, controller),
                  ),
                  _actionIcon(
                    context,
                    tooltip: 'Clear all data',
                    icon: Icons.delete_sweep_outlined,
                    onPressed: controller.loading
                        ? null
                        : () =>
                            _confirmClearAllData(context, controller, repository),
                    iconColor: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
            ActiveFiltersBar(controller: controller),
            Expanded(child: _body(context, controller, repository)),
            PaginationBar(controller: controller),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, MaintenanceHomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            'Maintenance Records',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          _actionIcon(
            context,
            tooltip: 'Settings',
            icon: Icons.settings_outlined,
            onPressed: () => _openSettings(context, controller),
          ),
          _actionIcon(
            context,
            tooltip: 'New record',
            icon: Icons.add,
            onPressed: () => _openNewRecord(context, controller),
            filled: true,
          ),
          const KernelBuildButton(),
        ],
      ),
    );
  }

  Widget _actionIcon(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool filled = false,
    Color? iconColor,
  }) {
    final style = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final child = filled
        ? IconButton.filled(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, color: iconColor),
          )
        : IconButton.outlined(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, color: iconColor),
          );
    return Tooltip(message: tooltip, child: child);
  }

  Widget _body(
    BuildContext context,
    MaintenanceHomeController controller,
    MaintenanceRepository repository,
  ) {
    if (controller.loading && controller.pageResult == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading maintenance records…'),
          ],
        ),
      );
    }

    if (controller.errorMessage != null) {
      return Center(child: Text('Error: ${controller.errorMessage}'));
    }

    final total = controller.pageResult?.totalRecords ?? 0;
    final hasSavedFields = controller.visibleColumns
        .any((c) => c.id != SystemFields.date);

    if (total == 0 && !hasSavedFields) {
      return _emptyState(context, controller);
    }

    if (total == 0 && hasSavedFields) {
      return Stack(
        children: [
          RecordsTable(
            controller: controller,
            onView: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
            onOpenDetails: (_) {},
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No records yet for your saved fields.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _openNewRecord(context, controller),
                        child: const Text('New Record'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (controller.loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );
    }

    return Stack(
      children: [
        RecordsTable(
          controller: controller,
          onView: (row) => _openDetails(context, repository, row),
          onEdit: (row) => _openEditRecord(context, controller, row.id),
          onDelete: (row) => _confirmDelete(context, controller, row),
          onOpenDetails: (row) => _openDetails(context, repository, row),
        ),
        if (controller.loading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, MaintenanceHomeController controller) {
    final noDataAtAll = controller.totalUnfiltered == 0;
    if (noDataAtAll) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No maintenance records yet.'),
            const SizedBox(height: 8),
            const Text(
              'You can create a new maintenance record\n'
              'or import your existing Excel data.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: () => _openNewRecord(context, controller),
                  child: const Text('New Record'),
                ),
                OutlinedButton(
                  onPressed: () => _importExcel(context, controller),
                  child: const Text('Import Excel'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No maintenance records found.'),
          const SizedBox(height: 8),
          const Text('Try changing your filters or search criteria.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.clearFilters,
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MaintenanceHomeController controller,
    MaintenanceRecordRow row,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          'Delete maintenance record #${row.id} (${row.displayValue('problem')})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await controller.deleteRecord(row.id);
    }
  }

  void _openDetails(
    BuildContext context,
    MaintenanceRepository repository,
    MaintenanceRecordRow row,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordDetailsPage(
          recordId: row.id,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _generateRandom(
    BuildContext context,
    MaintenanceHomeController controller,
  ) async {
    final fields = await context.read<MaintenanceRepository>().getCustomFormFields();
    if (!context.mounted) return;
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add fields in Settings and Save first')),
      );
      return;
    }
    final count = await showGenerateRandomDataDialog(
      context,
      availableFields: fields,
    );
    if (count != null && context.mounted) {
      await controller.initialize();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated $count random record(s)')),
      );
    }
  }

  Future<void> _openSettings(
    BuildContext context,
    MaintenanceHomeController controller,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (context.mounted) {
      await controller.initialize();
    }
  }

  Future<void> _openNewRecord(
    BuildContext context,
    MaintenanceHomeController controller,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecordEditPage()),
    );
    if (saved == true && context.mounted) {
      await controller.initialize();
    }
  }

  Future<void> _openEditRecord(
    BuildContext context,
    MaintenanceHomeController controller,
    int recordId,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecordEditPage(recordId: recordId)),
    );
    if (saved == true && context.mounted) {
      await controller.refresh();
    }
  }

  Future<void> _confirmClearAllData(
    BuildContext context,
    MaintenanceHomeController controller,
    MaintenanceRepository repository,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'Deletes all maintenance records and saved field definitions. '
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
    if (ok != true || !context.mounted) return;
    await repository.clearAllUserData();
    _searchController.clear();
    controller.clearFilters();
    await controller.initialize();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data cleared')),
    );
  }

  Future<void> _importExcel(
    BuildContext context,
    MaintenanceHomeController controller,
  ) async {
    final count = await showExcelImportFlow(context);
    if (count != null && context.mounted) {
      await controller.initialize();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count record(s) from Excel')),
      );
    }
  }

  Future<void> _export(
    BuildContext context,
    MaintenanceHomeController controller,
  ) async {
    final rows = await controller.exportRows();
    final file = await exportRecordsToExcel(
      columns: controller.visibleColumns,
      rows: rows,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${rows.length} rows to ${file.path}')),
    );
  }
}
