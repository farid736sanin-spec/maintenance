import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/features/settings/lm_studio_settings_section.dart';
import 'package:maintenance/models/ai_backend.dart';
import 'package:maintenance/services/litert_lm_service.dart';
import 'package:maintenance/services/lm_studio_service.dart';
import 'package:maintenance/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI settings switch between LM Studio and LiteRT-LM', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: settings),
          Provider(create: (_) => LmStudioService(settings)),
          Provider(create: (_) => LiteRtLmService(settings)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LmStudioSettingsSection()),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Select folder'), findsNothing);

    await tester.tap(find.text('Local LiteRT-LM'));
    await _settle(tester);

    expect(find.text('Select folder'), findsOneWidget);
    expect(find.text('Server URL'), findsNothing);
    expect(await settings.loadAiBackend(), AiBackend.liteRtLm);

    await tester.tap(find.text('Connect to LM'));
    await _settle(tester);

    expect(find.text('Server URL'), findsOneWidget);
    expect(await settings.loadAiBackend(), AiBackend.lmStudio);
  });

  testWidgets('saved LiteRT-LM choice opens on the folder picker', (
    tester,
  ) async {
    const folder = '/tmp/maintenance-no-such-litert-folder';
    SharedPreferences.setMockInitialValues({
      'settings.ai_backend': 'litert_lm',
      'settings.litert_model_folder': folder,
    });
    final settings = SettingsService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: settings),
          Provider(create: (_) => LmStudioService(settings)),
          Provider(create: (_) => LiteRtLmService(settings)),
        ],
        child: const MaterialApp(home: Scaffold(body: LmStudioSettingsSection())),
      ),
    );
    await _settle(tester);

    expect(find.text('Select folder'), findsOneWidget);
    expect(find.text(folder), findsOneWidget);
    expect(find.text('That folder is not there.'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
