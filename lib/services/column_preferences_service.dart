import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ColumnPreferencesService {
  static const _visibilityKey = 'columns.visibility';
  static const _widthsKey = 'columns.widths';
  static const _defaultHidden = <String>{};

  Future<Set<String>> loadHiddenColumnIds(List<String> allColumnIds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_visibilityKey);
    if (raw == null) {
      return allColumnIds.where(_defaultHidden.contains).toSet();
    }
    final decoded = (jsonDecode(raw) as Map<String, dynamic>);
    final hidden = decoded['hidden'] as List<dynamic>? ?? [];
    return hidden.cast<String>().toSet();
  }

  Future<void> saveHiddenColumnIds(Set<String> hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _visibilityKey,
      jsonEncode({'hidden': hidden.toList()}),
    );
  }

  Future<Map<String, double>> loadWidths() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_widthsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
  }

  Future<void> saveWidths(Map<String, double> widths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widthsKey, jsonEncode(widths));
  }

  Future<void> resetVisibility(List<String> allColumnIds) async {
    await saveHiddenColumnIds(
      allColumnIds.where(_defaultHidden.contains).toSet(),
    );
  }
}
