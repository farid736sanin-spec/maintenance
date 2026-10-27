import 'package:flutter/material.dart';

enum AppTheme {
  dark(
    label: 'Dark',
    icon: Icons.dark_mode_outlined,
    seedColor: Color(0xFF1565C0),
    brightness: Brightness.dark,
  ),
  white(
    label: 'White',
    icon: Icons.light_mode_outlined,
    seedColor: Color(0xFF1565C0),
    brightness: Brightness.light,
    surface: Colors.white,
  ),
  colorful(
    label: 'Colorful',
    icon: Icons.palette_outlined,
    seedColor: Color(0xFF7C3AED),
    brightness: Brightness.light,
    secondary: Color(0xFF006B5E),
    tertiary: Color(0xFF9C4300),
    vivid: true,
  ),
  forest(
    label: 'Forest',
    icon: Icons.forest_outlined,
    seedColor: Color(0xFF2E7D32),
    brightness: Brightness.light,
    secondary: Color(0xFF00695C),
    tertiary: Color(0xFF6D4C41),
    vivid: true,
  ),
  ocean(
    label: 'Ocean',
    icon: Icons.water_outlined,
    seedColor: Color(0xFF0277BD),
    brightness: Brightness.light,
    secondary: Color(0xFF00838F),
    tertiary: Color(0xFF4527A0),
    vivid: true,
  ),
  sunset(
    label: 'Sunset',
    icon: Icons.wb_twilight_outlined,
    seedColor: Color(0xFFE65100),
    brightness: Brightness.light,
    secondary: Color(0xFFC2185B),
    tertiary: Color(0xFFF9A825),
    vivid: true,
  );

  const AppTheme({
    required this.label,
    required this.icon,
    required this.seedColor,
    required this.brightness,
    this.secondary,
    this.tertiary,
    this.surface,
    this.vivid = false,
  });

  final String label;
  final IconData icon;
  final Color seedColor;
  final Brightness brightness;
  final Color? secondary;
  final Color? tertiary;
  final Color? surface;
  final bool vivid;

  static AppTheme fromStorage(String? value) {
    return AppTheme.values.firstWhere(
      (theme) => theme.name == value,
      orElse: () => AppTheme.white,
    );
  }

  ThemeData get data {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: vivid ? scheme.primaryContainer : scheme.surface,
        foregroundColor: vivid ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: vivid ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      ),
    );
  }
}
