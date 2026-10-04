import 'package:flutter/material.dart';

import '../../../models/field_definition.dart';
import '../maintenance_home_controller.dart';

Future<void> showColumnVisibilityDialog(
  BuildContext context,
  MaintenanceHomeController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return AlertDialog(
            title: const Text('Columns'),
            content: SizedBox(
              width: 320,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final col in controller.allColumns)
                    CheckboxListTile(
                      value: !controller.hiddenColumnIds.contains(col.id),
                      title: Text(col.label),
                      enabled: col.id != SystemFields.aiAnswer,
                      subtitle: col.id == SystemFields.aiAnswer
                          ? const Text('Always shown')
                          : null,
                      onChanged: col.id == SystemFields.aiAnswer
                          ? null
                          : (v) {
                              controller.toggleColumnVisibility(
                                col.id,
                                v ?? false,
                              );
                            },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await controller.resetColumns();
                },
                child: const Text('Reset Columns'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    },
  );
}
