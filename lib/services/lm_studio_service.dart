import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lm_studio_model.dart';
import 'settings_service.dart';

class LmStudioException implements Exception {
  LmStudioException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LmStudioService {
  LmStudioService(this._settings);

  final SettingsService _settings;

  Future<String> getBaseUrl() async {
    final saved = await _settings.loadLmStudioBaseUrl();
    return saved ?? SettingsService.defaultLmStudioBaseUrl;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _settings.loadLmStudioApiToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String baseUrl, String path) {
    final normalized = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse('$normalized${path.startsWith('/') ? path.substring(1) : path}');
  }

  Future<List<LmStudioModelInfo>> listModels() async {
    final baseUrl = await getBaseUrl();
    final response = await http
        .get(_uri(baseUrl, 'api/v1/models'), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw LmStudioException(
        'List models failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawModels = decoded['models'] as List<dynamic>? ?? [];
    return rawModels.map((m) {
      final map = m as Map<String, dynamic>;
      final key = (map['key'] ?? map['id'] ?? '').toString();
      final display =
          (map['display_name'] ?? map['name'] ?? key).toString();
      final type = (map['type'] ?? 'llm').toString();
      final loaded = map['loaded_instances'] as List<dynamic>? ?? [];
      return LmStudioModelInfo(
        key: key,
        displayName: display,
        type: type,
        isLoaded: loaded.isNotEmpty,
      );
    }).where((m) => m.key.isNotEmpty).toList();
  }

  Future<void> loadModel(String modelKey) async {
    final baseUrl = await getBaseUrl();
    final response = await http
        .post(
          _uri(baseUrl, 'api/v1/models/load'),
          headers: await _headers(),
          body: jsonEncode({'model': modelKey}),
        )
        .timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw LmStudioException(
        'Load model failed (${response.statusCode}): ${response.body}',
      );
    }
    await _settings.saveLmStudioSelectedModel(modelKey);
  }

  Future<String> askMaintenanceAssistant({
    required String prompt,
    String? modelOverride,
  }) async {
    final baseUrl = await getBaseUrl();
    final model =
        modelOverride ?? await _settings.loadLmStudioSelectedModel();
    if (model == null || model.isEmpty) {
      throw LmStudioException(
        'No LM Studio model selected. Open Settings and load a model.',
      );
    }

    final response = await http
        .post(
          _uri(baseUrl, 'v1/chat/completions'),
          headers: await _headers(),
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are an expert industrial maintenance assistant. '
                    'Help diagnose problems and suggest practical solutions.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.35,
            'stream': false,
          }),
        )
        .timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw LmStudioException(
        'Chat failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw LmStudioException('Empty response from LM Studio');
    }
    final message = choices.first['message'] as Map<String, dynamic>? ?? {};
    final content = message['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw LmStudioException('No text in LM Studio response');
    }
    return content;
  }
}
