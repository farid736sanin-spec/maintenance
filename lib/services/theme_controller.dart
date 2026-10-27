import 'package:flutter/foundation.dart';

import '../models/app_theme.dart';
import 'settings_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._settings, {AppTheme initialTheme = AppTheme.white})
    : _theme = initialTheme;

  final SettingsService _settings;
  AppTheme _theme;
  bool _saving = false;

  AppTheme get theme => _theme;
  bool get saving => _saving;

  Future<void> selectTheme(AppTheme theme) async {
    if (_saving || theme == _theme) return;
    _saving = true;
    notifyListeners();
    try {
      await _settings.saveTheme(theme);
      _theme = theme;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
