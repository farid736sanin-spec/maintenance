import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../models/ai_backend.dart';
import '../../models/lm_studio_model.dart';
import '../../services/litert_lm_service.dart';
import '../../services/lm_studio_service.dart';
import '../../services/settings_service.dart';
import 'model_folder_browser.dart';

class LmStudioSettingsSection extends StatefulWidget {
  const LmStudioSettingsSection({super.key});

  @override
  State<LmStudioSettingsSection> createState() =>
      _LmStudioSettingsSectionState();
}

class _LmStudioSettingsSectionState extends State<LmStudioSettingsSection> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tokenController;
  List<LmStudioModelInfo> _models = [];
  String? _selectedModelKey;
  bool _loadingModels = false;
  bool _loadingModel = false;
  String? _status;

  AiBackend _backend = AiBackend.lmStudio;
  String? _modelFolder;
  String? _modelPath;
  bool _loadingLocalModel = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _tokenController = TextEditingController();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final settings = context.read<SettingsService>();
    final baseUrl =
        await settings.loadLmStudioBaseUrl() ??
        SettingsService.defaultLmStudioBaseUrl;
    final token = await settings.loadLmStudioApiToken() ?? '';
    final selected = await settings.loadLmStudioSelectedModel();
    final backend = await settings.loadAiBackend();
    final folder = await settings.loadLiteRtModelFolder();
    final modelPath = await settings.loadLiteRtModelPath();
    if (!mounted) return;
    setState(() {
      _baseUrlController.text = baseUrl;
      _tokenController.text = token;
      _selectedModelKey = selected;
      _backend = backend;
      _modelFolder = folder;
      _modelPath = modelPath;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _setBackend(AiBackend backend) async {
    setState(() {
      _backend = backend;
      _status = null;
    });
    await context.read<SettingsService>().saveAiBackend(backend);
  }

  Future<void> _saveConnection({bool notify = true}) async {
    final settings = context.read<SettingsService>();
    await settings.saveLmStudioBaseUrl(_baseUrlController.text.trim());
    await settings.saveLmStudioApiToken(_tokenController.text.trim());
    if (!notify || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('LM Studio connection saved')));
  }

  Future<void> _refreshModels() async {
    setState(() {
      _loadingModels = true;
      _status = null;
    });
    try {
      final lmStudio = context.read<LmStudioService>();
      await _saveConnection(notify: false);
      final models = await lmStudio.listModels();
      final llms = models.where((m) => m.isLlm).toList();
      if (!mounted) return;
      setState(() {
        _models = llms;
        if (_selectedModelKey != null &&
            !llms.any((m) => m.key == _selectedModelKey)) {
          _selectedModelKey = null;
        }
        _status = 'Found ${llms.length} LLM model(s)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _connectionMessage(e));
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  String _connectionMessage(Object error) {
    final text = error.toString();
    if (text.contains('Connection refused') ||
        text.contains('Connection timed out') ||
        text.contains('Failed host lookup') ||
        text.contains('SocketException') ||
        text.contains('ClientException')) {
      final url = _baseUrlController.text.trim();
      return 'Cannot reach LM Studio${url.isEmpty ? '' : ' at $url'}. '
          'Start LM Studio and enable the local server, then try again.';
    }
    return text;
  }

  Future<void> _loadSelectedModel() async {
    final key = _selectedModelKey;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a model first')));
      return;
    }
    setState(() {
      _loadingModel = true;
      _status = 'Loading model…';
    });
    try {
      await context.read<LmStudioService>().loadModel(key);
      await _refreshModels();
      if (!mounted) return;
      setState(() => _status = 'Model loaded: $key');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Loaded $key')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _connectionMessage(e));
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  Future<void> _selectFolder() async {
    final picked = await pickModelFolder(
      context,
      start: _modelFolder ?? _modelPath,
    );
    if (picked == null || !mounted) return;
    final settings = context.read<SettingsService>();
    if (isLitertModelFile(picked)) {
      final folder = File(picked).parent.path;
      setState(() {
        _modelFolder = folder;
        _modelPath = picked;
        _status = null;
      });
      await settings.saveLiteRtModelFolder(folder);
      await settings.saveLiteRtModelPath(picked);
      await _loadLocalModel(picked);
      return;
    }
    setState(() {
      _modelFolder = picked;
      _status = null;
    });
    await settings.saveLiteRtModelFolder(picked);
  }

  Future<void> _chooseLocalModel(String path) async {
    setState(() => _modelPath = path);
    await context.read<SettingsService>().saveLiteRtModelPath(path);
    await _loadLocalModel(path);
  }

  Future<void> _loadLocalModel(String path) async {
    setState(() {
      _loadingLocalModel = true;
      _status = 'Loading ${p.basename(path)}…';
    });
    try {
      await context.read<LiteRtLmService>().load(path);
      if (!mounted) return;
      setState(() => _status = 'Model ready: ${p.basename(path)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _loadingLocalModel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localModels = _modelFolder == null
        ? null
        : modelsInFolder(_modelFolder!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose how the AI Answer column is filled: connect to LM Studio '
          'on this PC, or run a local LiteRT-LM model.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<AiBackend>(
          segments: const [
            ButtonSegment(
              value: AiBackend.lmStudio,
              label: Text('Connect to LM'),
              icon: Icon(Icons.cloud_outlined),
            ),
            ButtonSegment(
              value: AiBackend.liteRtLm,
              label: Text('Local LiteRT-LM'),
              icon: Icon(Icons.memory),
            ),
          ],
          selected: {_backend},
          onSelectionChanged: (selection) {
            _setBackend(selection.first);
          },
        ),
        const SizedBox(height: 16),
        if (_backend == AiBackend.lmStudio)
          ..._lmStudioFields()
        else
          ..._liteRtFields(localModels),
      ],
    );
  }

  List<Widget> _lmStudioFields() {
    return [
      const Text(
        'Connect to LM Studio on this PC to analyze maintenance problems.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _baseUrlController,
        decoration: const InputDecoration(
          labelText: 'Server URL',
          hintText: 'http://127.0.0.1:1234',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tokenController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'API token (optional)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _loadingModels ? null : _refreshModels,
            icon: _loadingModels
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Refresh models'),
          ),
          FilledButton.tonalIcon(
            onPressed: _loadingModel || _selectedModelKey == null
                ? null
                : _loadSelectedModel,
            icon: _loadingModel
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.memory),
            label: const Text('Load selected model'),
          ),
        ],
      ),
      if (_status != null) ...[
        const SizedBox(height: 8),
        Text(_status!, style: Theme.of(context).textTheme.bodySmall),
      ],
      if (_models.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Models', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _selectedModelKey,
          onChanged: (value) {
            setState(() => _selectedModelKey = value);
            if (value != null) {
              context.read<SettingsService>().saveLmStudioSelectedModel(value);
            }
          },
          child: Column(
            children: [
              for (final model in _models)
                RadioListTile<String>(
                  value: model.key,
                  title: Text(model.displayName),
                  subtitle: Text(
                    model.isLoaded ? '${model.key} · loaded' : model.key,
                  ),
                  dense: true,
                ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _liteRtFields(({List<File> models, String? error})? listed) {
    return [
      const Text(
        'Select a folder, then choose a .litertlm model in it. '
        'The file stays where it is.',
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _loadingLocalModel ? null : _selectFolder,
          icon: const Icon(Icons.folder_open),
          label: const Text('Select folder'),
        ),
      ),
      if (_modelFolder != null) ...[
        const SizedBox(height: 8),
        Text(_modelFolder!, style: Theme.of(context).textTheme.bodySmall),
      ],
      if (_status != null) ...[
        const SizedBox(height: 8),
        Text(_status!, style: Theme.of(context).textTheme.bodySmall),
      ],
      if (listed != null) ...[
        const SizedBox(height: 12),
        if (listed.error != null)
          Text(listed.error!)
        else if (listed.models.isEmpty)
          const Text('No .litertlm models in this folder.')
        else
          ...listed.models.map((model) {
            final selected = model.path == _modelPath;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _loadingLocalModel && selected
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.description_outlined,
                    ),
              title: Text(p.basename(model.path)),
              subtitle: Text(model.path),
              enabled: !_loadingLocalModel,
              onTap: _loadingLocalModel
                  ? null
                  : () => _chooseLocalModel(model.path),
            );
          }),
      ],
    ];
  }
}
