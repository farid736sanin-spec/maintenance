import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:path/path.dart' as p;

import 'settings_service.dart';

class LiteRtLmException implements Exception {
  LiteRtLmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// On-device answers from a `.litertlm` file, using the same LiteRT-LM
/// engine as the friends app.
class LiteRtLmService {
  LiteRtLmService(this._settings);

  final SettingsService _settings;

  static const _systemInstruction =
      'You are an expert industrial maintenance assistant. '
      'Help diagnose problems and suggest practical solutions.';

  InferenceModel? _model;
  String? _loadedPath;
  Future<void>? _engineInit;
  Future<void> _queue = Future<void>.value();

  bool get isReady => _model != null;

  String? get loadedPath => _loadedPath;

  Future<void> load(String modelPath) {
    return _serialized(() => _load(modelPath, force: true));
  }

  Future<String> askMaintenanceAssistant({required String prompt}) {
    return _serialized(() async {
      final path = await _settings.loadLiteRtModelPath();
      if (path == null || path.trim().isEmpty) {
        throw LiteRtLmException(
          'No LiteRT-LM model selected. Open Settings, choose Local LiteRT-LM, '
          'and pick a .litertlm file from a folder.',
        );
      }
      await _load(path.trim(), force: false);
      return _generate(prompt);
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _ensureEngine() async {
    if (_engineInit != null) {
      await _engineInit;
      return;
    }
    final init = _initializeEngine();
    _engineInit = init;
    try {
      await init;
    } catch (error) {
      if (identical(_engineInit, init)) _engineInit = null;
      rethrow;
    }
  }

  Future<void> _initializeEngine() async {
    try {
      await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
    } catch (error, stack) {
      debugPrint('LiteRT-LM failed to initialize: $error\n$stack');
      throw LiteRtLmException(
        'LiteRT-LM failed to load. On-device answers are unavailable. $error',
      );
    }
  }

  Future<void> _load(String modelPath, {required bool force}) async {
    if (!force && _loadedPath == modelPath && _model != null) return;
    await _ensureEngine();
    if (!File(modelPath).existsSync()) {
      throw LiteRtLmException('Model file not found: $modelPath');
    }
    try {
      await FlutterGemma.installModel(
        modelType: modelTypeForLitertPath(modelPath),
        fileType: ModelFileType.litertlm,
      ).fromFile(modelPath).install();
      await _model?.close();
      _model = null;
      _loadedPath = null;
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
        maxConcurrentSessions: 1,
      );
      _loadedPath = modelPath;
    } catch (error, stack) {
      _model = null;
      _loadedPath = null;
      debugPrint('Failed to load LiteRT-LM model: $error\n$stack');
      if (error is LiteRtLmException) rethrow;
      throw LiteRtLmException('Failed to load the LiteRT-LM model. $error');
    }
  }

  Future<String> _generate(String prompt) async {
    final model = _model;
    if (model == null) {
      throw LiteRtLmException('Load a .litertlm model before asking.');
    }
    final session = await model.createSession(
      temperature: 0.35,
      topK: 40,
      randomSeed: DateTime.now().millisecondsSinceEpoch,
      maxOutputTokens: 512,
      systemInstruction: _systemInstruction,
    );
    try {
      await session.addQueryChunk(Message(text: prompt, isUser: true));
      final buffer = StringBuffer();
      await for (final chunk in session.getResponseAsync()) {
        buffer.write(chunk);
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) {
        throw LiteRtLmException('The local model returned an empty answer.');
      }
      return text;
    } finally {
      await session.close();
    }
  }
}

ModelType modelTypeForLitertPath(String path) {
  final name = p.basename(path).toLowerCase();
  if (name.contains('functiongemma')) return ModelType.functionGemma;
  if (name.contains('gemma-4') || name.contains('gemma4')) {
    return ModelType.gemma4;
  }
  if (name.contains('gemma')) return ModelType.gemmaIt;
  if (name.contains('qwen3')) return ModelType.qwen3;
  if (name.contains('qwen')) return ModelType.qwen;
  if (name.contains('deepseek')) return ModelType.deepSeek;
  if (name.contains('phi')) return ModelType.phi;
  if (name.contains('llama')) return ModelType.llama;
  return ModelType.general;
}
