import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_theme.dart';
import '../../services/theme_controller.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<ThemeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose a theme. Changes are applied and saved.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final theme in AppTheme.values)
              ChoiceChip(
                avatar: Icon(theme.icon, size: 18),
                label: Text(theme.label),
                selected: appearance.theme == theme,
                onSelected: appearance.saving
                    ? null
                    : (_) async {
                        try {
                          await appearance.selectTheme(theme);
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save theme. Please try again.',
                              ),
                            ),
                          );
                        }
                      },
              ),
          ],
        ),
      ],
    );
  }
}
