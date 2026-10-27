import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/features/settings/appearance_settings_section.dart';
import 'package:maintenance/models/app_theme.dart';
import 'package:maintenance/services/settings_service.dart';
import 'package:maintenance/services/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingSettings extends SettingsService {
  @override
  Future<void> saveTheme(AppTheme theme) async {
    throw StateError('Storage unavailable');
  }
}

Widget _app(SettingsService settings) {
  return ChangeNotifierProvider(
    create: (_) => ThemeController(settings),
    child: Consumer<ThemeController>(
      builder: (context, controller, _) => MaterialApp(
        theme: controller.theme.data,
        home: const Scaffold(body: AppearanceSettingsSection()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('theme defaults to White and tolerates unknown saved values', () async {
    final settings = SettingsService();
    expect(await settings.loadTheme(), AppTheme.white);
    SharedPreferences.setMockInitialValues({'settings.theme': 'unknown'});
    expect(await settings.loadTheme(), AppTheme.white);
  });

  test('all theme choices persist and restore', () async {
    final settings = SettingsService();
    for (final theme in AppTheme.values) {
      await settings.saveTheme(theme);
      final restored = ThemeController(
        settings,
        initialTheme: await settings.loadTheme(),
      );
      expect(restored.theme, theme);
      restored.dispose();
    }
  });

  testWidgets('theme choices update the app and save automatically', (
    tester,
  ) async {
    final settings = SettingsService();
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();

    ThemeData currentTheme() =>
        Theme.of(tester.element(find.byType(AppearanceSettingsSection)));

    expect(currentTheme().scaffoldBackgroundColor, Colors.white);
    expect(
      AppTheme.values,
      containsAll(<AppTheme>[
        AppTheme.dark,
        AppTheme.white,
        AppTheme.colorful,
        AppTheme.forest,
        AppTheme.ocean,
        AppTheme.sunset,
      ]),
    );
    for (final theme in [
      ...AppTheme.values.where((t) => t != AppTheme.white),
      AppTheme.white,
    ]) {
      await tester.tap(find.text(theme.label));
      await tester.pumpAndSettle();
      expect(await settings.loadTheme(), theme);
      expect(currentTheme().brightness, theme.data.brightness);
      expect(currentTheme().colorScheme, theme.data.colorScheme);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, theme.label))
            .selected,
        isTrue,
      );
    }
  });

  testWidgets('save failure keeps the current theme and shows an error', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FailingSettings()));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save theme. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'White'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
