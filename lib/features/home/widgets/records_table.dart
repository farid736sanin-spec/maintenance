import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/sort.dart';
import '../../../models/field_definition.dart';
import '../../../models/maintenance_record.dart';
import '../maintenance_home_controller.dart';
import 'column_filter_cell.dart';
import 'column_resize_handle.dart';

class RecordsTable extends StatefulWidget {
  const RecordsTable({
    super.key,
    required this.controller,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenDetails,
  });

  final MaintenanceHomeController controller;
  final void Function(MaintenanceRecordRow row) onView;
  final void Function(MaintenanceRecordRow row) onEdit;
  final void Function(MaintenanceRecordRow row) onDelete;
  final void Function(MaintenanceRecordRow row) onOpenDetails;

  static const _filterRowHeight = 44.0;
  static const _headerRowHeight = 48.0;

  @override
  State<RecordsTable> createState() => _RecordsTableState();
}

class _RecordsTableState extends State<RecordsTable> {
  final ScrollController _headerScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _bodyVScroll = ScrollController();
  bool _syncingScroll = false;
  bool _columnResizeActive = false;
  String? _resizingFieldId;
  double? _resizeStartWidth;
  double _resizeDragTotal = 0;

  @override
  void initState() {
    super.initState();
    _bodyHScroll.addListener(_syncHeaderFromBody);
  }

  @override
  void dispose() {
    _bodyHScroll.removeListener(_syncHeaderFromBody);
    _headerScroll.dispose();
    _bodyHScroll.dispose();
    _bodyVScroll.dispose();
    super.dispose();
  }

  void _syncHeaderFromBody() {
    if (_syncingScroll || !_headerScroll.hasClients) return;
    _syncingScroll = true;
    _headerScroll.jumpTo(_bodyHScroll.offset);
    _syncingScroll = false;
  }

  void _syncBodyFromHeader() {
    if (_syncingScroll || !_bodyHScroll.hasClients) return;
    _syncingScroll = true;
    _bodyHScroll.jumpTo(_headerScroll.offset);
    _syncingScroll = false;
  }

  MaintenanceHomeController get controller => widget.controller;

  ScrollPhysics get _horizontalScrollPhysics => _columnResizeActive
      ? const NeverScrollableScrollPhysics()
      : const ClampingScrollPhysics();

  void _beginColumnResize(String fieldId) {
    _resizingFieldId = fieldId;
    _resizeDragTotal = 0;
    if (fieldId == SystemFields.actions) {
      _resizeStartWidth = controller.actionsColumnWidth;
    } else {
      final col = controller.columnById(fieldId);
      _resizeStartWidth = col != null ? controller.widthFor(col) : 120;
    }
  }

  void _resizeColumn(String fieldId, double delta, {bool persist = false}) {
    if (_resizingFieldId != fieldId || _resizeStartWidth == null) {
      _beginColumnResize(fieldId);
    }
    _resizeDragTotal += delta;
    controller.setColumnWidth(
      fieldId,
      _resizeStartWidth! + _resizeDragTotal,
      persist: persist,
    );
  }

  void _endColumnResize() {
    _resizingFieldId = null;
    _resizeStartWidth = null;
    _resizeDragTotal = 0;
  }

  @override
  Widget build(BuildContext context) {
    final columns = controller.visibleColumns;
    final rows = controller.pageResult?.records ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = _tableWidth(columns);
        final contentWidth = math.max(tableWidth, constraints.maxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (_columnResizeActive) return true;
                if (n is ScrollUpdateNotification &&
                    n.metrics.axis == Axis.horizontal) {
                  _syncBodyFromHeader();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _headerScroll,
                scrollDirection: Axis.horizontal,
                physics: _horizontalScrollPhysics,
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderRow(
                        controller: controller,
                        columns: columns,
                        onResizeStart: (id) {
                          _beginColumnResize(id);
                          setState(() => _columnResizeActive = true);
                        },
                        onResizeEnd: () {
                          controller.persistColumnWidths();
                          _endColumnResize();
                          setState(() => _columnResizeActive = false);
                        },
                        onResize: (id, delta) =>
                            _resizeColumn(id, delta, persist: false),
                      ),
                      _FilterRow(
                        controller: controller,
                        columns: columns,
                        height: RecordsTable._filterRowHeight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _bodyVScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _bodyVScroll,
                  child: Scrollbar(
                    controller: _bodyHScroll,
                    thumbVisibility: true,
                    notificationPredicate: (n) =>
                        n.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _bodyHScroll,
                      scrollDirection: Axis.horizontal,
                      physics: _horizontalScrollPhysics,
                      child: SizedBox(
                        width: contentWidth,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return _DataRowTile(
                              index: index,
                              row: row,
                              columns: columns,
                              controller: controller,
                              onView: () => widget.onView(row),
                              onEdit: () => widget.onEdit(row),
                              onDelete: () => widget.onDelete(row),
                              onOpenDetails: () => widget.onOpenDetails(row),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _tableWidth(List<FieldDefinition> columns) {
    var w = controller.actionsColumnWidth;
    for (final c in columns) {
      w += controller.widthFor(c);
    }
    return w;
  }
}

/// Grid cell with right and bottom borders aligned to column widths.
class _TableCellBorder extends StatelessWidget {
  const _TableCellBorder({
    required this.width,
    required this.child,
    this.height,
  });

  final double width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: child,
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.controller,
    required this.columns,
    required this.onResize,
    required this.onResizeStart,
    required this.onResizeEnd,
  });

  final MaintenanceHomeController controller;
  final List<FieldDefinition> columns;
  final void Function(String fieldId, double delta) onResize;
  final void Function(String fieldId) onResizeStart;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _actionsHeader(context),
          for (final col in columns) _headerCell(context, col),
        ],
      ),
    );
  }

  Widget _actionsHeader(BuildContext context) {
    return _HeaderCellWithResize(
      width: controller.actionsColumnWidth,
      onResizeStart: () => onResizeStart(SystemFields.actions),
      onResizeEnd: onResizeEnd,
      onResize: (dx) => onResize(SystemFields.actions, dx),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Actions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
    );
  }

  Widget _headerCell(BuildContext context, FieldDefinition col) {
    final sort = controller.sortState.primary;
    final isSorted =
        sort?.fieldId == col.id && sort!.direction != SortDirection.none;
    String suffix = '';
    if (isSorted) {
      suffix = sort.direction == SortDirection.ascending ? ' ↓' : ' ↑';
    }

    final label = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          col.id == SystemFields.aiAnswer ? col.label : '${col.label}$suffix',
          style: Theme.of(context).textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return _HeaderCellWithResize(
      width: controller.widthFor(col),
      onResizeStart: () => onResizeStart(col.id),
      onResizeEnd: onResizeEnd,
      onResize: (dx) => onResize(col.id, dx),
      child: col.id == SystemFields.aiAnswer
          ? label
          : InkWell(onTap: () => controller.toggleSort(col.id), child: label),
    );
  }
}

/// Header cell with a resize handle centered on the right grid line.
class _HeaderCellWithResize extends StatelessWidget {
  const _HeaderCellWithResize({
    required this.width,
    required this.child,
    required this.onResize,
    required this.onResizeStart,
    required this.onResizeEnd,
  });

  final double width;
  final Widget child;
  final ValueChanged<double> onResize;
  final VoidCallback onResizeStart;
  final VoidCallback onResizeEnd;

  static const _handleWidth = 14.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: RecordsTable._headerRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _TableCellBorder(
            width: width,
            height: RecordsTable._headerRowHeight,
            child: child,
          ),
          Positioned(
            right: -_handleWidth / 2,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: ColumnResizeHandle(
              width: _handleWidth,
              onResizeStart: onResizeStart,
              onResizeEnd: onResizeEnd,
              onResize: onResize,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.controller,
    required this.columns,
    required this.height,
  });

  final MaintenanceHomeController controller;
  final List<FieldDefinition> columns;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _TableCellBorder(
          width: controller.actionsColumnWidth,
          height: height,
          child: const SizedBox.shrink(),
        ),
          for (final col in columns)
            if (col.id == SystemFields.aiAnswer)
              _TableCellBorder(
                width: controller.widthFor(col),
                height: height,
                child: const SizedBox.shrink(),
              )
            else
              _TableCellBorder(
                width: controller.widthFor(col),
                height: height,
                child: ColumnFilterCell(column: col, controller: controller),
              ),
      ],
    );
  }
}

class _AiAnswerCell extends StatelessWidget {
  const _AiAnswerCell({
    required this.row,
    required this.controller,
  });

  final MaintenanceRecordRow row;
  final MaintenanceHomeController controller;

  @override
  Widget build(BuildContext context) {
    final loading = controller.isAiLoading(row.id);
    final answer = controller.aiAnswerFor(row.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: loading
                ? const LinearProgressIndicator(minHeight: 2)
                : Text(
                    answer.isEmpty ? '—' : answer,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
          Tooltip(
            message: 'AI Ask',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: loading
                  ? null
                  : () async {
                      try {
                        await controller.askAiForRecord(row);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRowTile extends StatelessWidget {
  const _DataRowTile({
    required this.index,
    required this.row,
    required this.columns,
    required this.controller,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenDetails,
  });

  final int index;
  final MaintenanceRecordRow row;
  final List<FieldDefinition> columns;
  final MaintenanceHomeController controller;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowColor = index.isEven
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    final iconButtonStyle = IconButton.styleFrom(
      padding: const EdgeInsets.all(4),
      minimumSize: const Size(36, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Material(
      color: rowColor,
      child: InkWell(
        onDoubleTap: onOpenDetails,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TableCellBorder(
              width: controller.actionsColumnWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: 'View',
                    child: IconButton(
                      style: iconButtonStyle,
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      onPressed: onView,
                    ),
                  ),
                  Tooltip(
                    message: 'Edit',
                    child: IconButton(
                      style: iconButtonStyle,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                    ),
                  ),
                  Tooltip(
                    message: 'Delete',
                    child: IconButton(
                      style: iconButtonStyle,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
            ),
            for (final col in columns)
              if (col.id == SystemFields.aiAnswer)
                _TableCellBorder(
                  width: controller.widthFor(col),
                  child: _AiAnswerCell(row: row, controller: controller),
                )
              else
                _TableCellBorder(
                  width: controller.widthFor(col),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      row.displayValue(col.id),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
