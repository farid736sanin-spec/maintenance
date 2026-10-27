import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'data/maintenance_repository.dart';
import 'features/home/maintenance_home_controller.dart';
import 'features/home/maintenance_home_page.dart';
import 'models/app_theme.dart';
import 'services/column_preferences_service.dart';
import 'services/litert_lm_service.dart';
import 'services/lm_studio_service.dart';
import 'services/settings_service.dart';
import 'services/theme_controller.dart';

class MaintenanceApp extends StatelessWidget {
  const MaintenanceApp({
    super.key,
    required this.repository,
    required this.settings,
    this.initialTheme = AppTheme.white,
  });

  final MaintenanceRepository repository;
  final SettingsService settings;
  final AppTheme initialTheme;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: repository),
        Provider.value(value: settings),
        ChangeNotifierProvider(
          create: (_) => ThemeController(settings, initialTheme: initialTheme),
        ),
        Provider(create: (_) => LmStudioService(settings)),
        Provider(create: (_) => LiteRtLmService(settings)),
        ChangeNotifierProvider(
          create: (context) => MaintenanceHomeController(
            repository: repository,
            columnPrefs: ColumnPreferencesService(),
            settings: settings,
            lmStudio: context.read<LmStudioService>(),
            liteRtLm: context.read<LiteRtLmService>(),
          ),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, appearance, child) => MaterialApp(
          title: 'Maintenance Records',
          debugShowCheckedModeBanner: false,
          theme: appearance.theme.data,
          home: child,
        ),
        child: const MaintenanceHomePage(),
      ),
    );
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final settings = SettingsService();
  final initialTheme = await settings.loadTheme();
  final repository = MaintenanceRepository(db, settings);
  runApp(
    MaintenanceApp(
      repository: repository,
      settings: settings,
      initialTheme: initialTheme,
    ),
  );
}
