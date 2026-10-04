import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'data/maintenance_repository.dart';
import 'features/home/maintenance_home_controller.dart';
import 'features/home/maintenance_home_page.dart';
import 'services/column_preferences_service.dart';
import 'services/lm_studio_service.dart';
import 'services/settings_service.dart';

class MaintenanceApp extends StatelessWidget {
  const MaintenanceApp({
    super.key,
    required this.repository,
    required this.settings,
  });

  final MaintenanceRepository repository;
  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: repository),
        Provider.value(value: settings),
        Provider(create: (_) => LmStudioService(settings)),
        ChangeNotifierProvider(
          create: (context) => MaintenanceHomeController(
            repository: repository,
            columnPrefs: ColumnPreferencesService(),
            settings: settings,
            lmStudio: context.read<LmStudioService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Maintenance Records',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          useMaterial3: true,
        ),
        home: const MaintenanceHomePage(),
      ),
    );
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final settings = SettingsService();
  final repository = MaintenanceRepository(db, settings);
  runApp(MaintenanceApp(repository: repository, settings: settings));
}
