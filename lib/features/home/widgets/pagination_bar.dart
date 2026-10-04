import 'package:flutter/material.dart';

import '../maintenance_home_controller.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.controller});

  final MaintenanceHomeController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.pageResult;
    if (result == null) return const SizedBox.shrink();

    final totalPages = result.totalPages;
    final current = result.currentPage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const Text('Rows per page:'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: controller.pageSize,
            items: controller.pageSizeOptions
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (v) {
              if (v != null) controller.setPageSize(v);
            },
          ),
          const Spacer(),
          Text(
            result.totalRecords == 0
                ? 'Showing 0 of 0'
                : 'Showing ${result.startIndex}–${result.endIndex} of ${result.totalRecords}',
          ),
          const SizedBox(width: 8),
          _navIcon(
            context,
            tooltip: 'First page',
            icon: Icons.first_page,
            enabled: current > 1,
            onPressed: () => controller.setPage(1),
          ),
          _navIcon(
            context,
            tooltip: 'Previous page',
            icon: Icons.chevron_left,
            enabled: current > 1,
            onPressed: () => controller.setPage(current - 1),
          ),
          ..._pageNumbers(current, totalPages),
          _navIcon(
            context,
            tooltip: 'Next page',
            icon: Icons.chevron_right,
            enabled: current < totalPages,
            onPressed: () => controller.setPage(current + 1),
          ),
          _navIcon(
            context,
            tooltip: 'Last page',
            icon: Icons.last_page,
            enabled: current < totalPages && totalPages > 0,
            onPressed: () => controller.setPage(totalPages),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
      ),
    );
  }

  List<Widget> _pageNumbers(int current, int totalPages) {
    if (totalPages <= 1) return [];
    final start = (current - 2).clamp(1, totalPages);
    final end = (current + 2).clamp(1, totalPages);
    final pages = <Widget>[];
    for (var p = start; p <= end; p++) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextButton(
            onPressed: p == current ? null : () => controller.setPage(p),
            child: Text(
              '$p',
              style: TextStyle(
                fontWeight: p == current ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }
    return pages;
  }
}
