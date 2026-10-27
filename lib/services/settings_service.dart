import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_backend.dart';
import '../models/app_theme.dart';
import '../models/field_definition.dart';
import '../models/field_definition_codec.dart';

class SettingsService {
  static const defaultPageSizes = [25, 50, 100, 250, 500, 1000];
  static const _pageSizesKey = 'settings.page_sizes';
  static const _defaultPageSizeKey = 'settings.default_page_size';
  static const _homeColumnIdsKey = 'settings.home_column_field_ids';
  static const _userFieldLibraryKey = 'settings.user_field_library';
  static const _excelColumnMappingKey = 'settings.excel_column_mapping';
  static const _excelImportDirectoryKey = 'settings.excel_import_directory';
  static const _excelLastImportFileKey = 'settings.excel_last_import_file';
  static const _lmStudioBaseUrlKey = 'settings.lm_studio_base_url';
  static const _lmStudioApiTokenKey = 'settings.lm_studio_api_token';
  static const _lmStudioSelectedModelKey = 'settings.lm_studio_selected_model';
  static const _aiBackendKey = 'settings.ai_backend';
  static const _liteRtModelFolderKey = 'settings.litert_model_folder';
  static const _liteRtModelPathKey = 'settings.litert_model_path';
  static const _themeKey = 'settings.theme';

  static const defaultLmStudioBaseUrl = 'http://127.0.0.1:1234';

  Future<AppTheme> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return AppTheme.fromStorage(prefs.getString(_themeKey));
  }

  Future<void> saveTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_themeKey, theme.name)) {
      throw StateError('Could not save theme preference');
    }
  }

  Future<List<int>> getPageSizeOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pageSizesKey);
    if (raw == null || raw.isEmpty) return List.of(defaultPageSizes);
    return raw.map(int.parse).toList();
  }

  Future<void> setPageSizeOptions(List<int> sizes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _pageSizesKey,
      sizes.map((e) => e.toString()).toList(),
    );
  }

  Future<int> getDefaultPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultPageSizeKey) ?? 50;
  }

  Future<List<String>> loadHomeColumnFieldIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_homeColumnIdsKey) ?? [];
  }

  Future<void> saveHomeColumnFieldIds(List<String> fieldIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_homeColumnIdsKey, fieldIds);
  }

  Future<List<FieldDefinition>> loadUserFieldLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeFieldLibrary(prefs.getString(_userFieldLibraryKey));
  }

  Future<void> mergeUserFieldLibrary(List<FieldDefinition> fields) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadUserFieldLibrary();
    final byId = {for (final f in existing) f.id: f};
    for (final f in fields) {
      byId[f.id] = f;
    }
    await prefs.setString(
      _userFieldLibraryKey,
      encodeFieldLibrary(byId.values.toList()),
    );
  }

  Future<void> clearUserFieldLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userFieldLibraryKey);
  }

  Future<void> clearHomeColumnFieldIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeColumnIdsKey);
  }

  Future<Map<String, String>> loadExcelColumnMapping() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_excelColumnMappingKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveExcelColumnMapping(Map<String, String> mapping) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_excelColumnMappingKey, jsonEncode(mapping));
  }

  Future<String?> loadExcelImportDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_excelImportDirectoryKey);
  }

  Future<void> saveExcelImportDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_excelImportDirectoryKey, path);
  }

  Future<String?> loadLastImportFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_excelLastImportFileKey);
  }

  Future<void> saveLastImportFilePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_excelLastImportFileKey, path);
  }

  Future<String?> loadLmStudioBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lmStudioBaseUrlKey);
  }

  Future<void> saveLmStudioBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lmStudioBaseUrlKey, url);
  }

  Future<String?> loadLmStudioApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lmStudioApiTokenKey);
  }

  Future<void> saveLmStudioApiToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_lmStudioApiTokenKey);
    } else {
      await prefs.setString(_lmStudioApiTokenKey, token);
    }
  }

  Future<String?> loadLmStudioSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lmStudioSelectedModelKey);
  }

  Future<void> saveLmStudioSelectedModel(String modelKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lmStudioSelectedModelKey, modelKey);
  }

  Future<AiBackend> loadAiBackend() async {
    final prefs = await SharedPreferences.getInstance();
    return AiBackend.fromStorage(prefs.getString(_aiBackendKey));
  }

  Future<void> saveAiBackend(AiBackend backend) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiBackendKey, backend.storageValue);
  }

  Future<String?> loadLiteRtModelFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_liteRtModelFolderKey);
  }

  Future<void> saveLiteRtModelFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_liteRtModelFolderKey, path);
  }

  Future<String?> loadLiteRtModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_liteRtModelPathKey);
  }

  Future<void> saveLiteRtModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_liteRtModelPathKey, path);
  }
}
