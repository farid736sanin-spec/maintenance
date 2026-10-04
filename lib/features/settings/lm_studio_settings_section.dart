import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lm_studio_model.dart';
import '../../services/lm_studio_service.dart';
import '../../services/settings_service.dart';

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
    if (!mounted) return;
    setState(() {
      _baseUrlController.text = baseUrl;
      _tokenController.text = token;
      _selectedModelKey = selected;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _saveConnection({bool notify = true}) async {
    final settings = context.read<SettingsService>();
    await settings.saveLmStudioBaseUrl(_baseUrlController.text.trim());
    await settings.saveLmStudioApiToken(_tokenController.text.trim());
    if (!notify || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LM Studio connection saved')),
    );
  }

  Future<void> _refreshModels() async {
    setState(() {
      _loadingModels = true;
      _status = null;
    });
    try {
      await _saveConnection(notify: false);
      final models = await context.read<LmStudioService>().listModels();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a model first')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded $key')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _connectionMessage(e));
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LM Studio — ربط مع LM Studio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect to LM Studio on this PC to analyze maintenance problems '
              'and fill the AI Answer column on the home table.',
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
              Text(
                'Models',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._models.map((model) {
                return RadioListTile<String>(
                  value: model.key,
                  groupValue: _selectedModelKey,
                  onChanged: (v) async {
                    setState(() => _selectedModelKey = v);
                    if (v != null) {
                      await context
                          .read<SettingsService>()
                          .saveLmStudioSelectedModel(v);
                    }
                  },
                  title: Text(model.displayName),
                  subtitle: Text(
                    model.isLoaded ? '${model.key} · loaded' : model.key,
                  ),
                  dense: true,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
