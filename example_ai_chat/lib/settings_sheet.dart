import 'package:flutter/material.dart';

import 'chat_config.dart';

/// Endpoint settings, edited at runtime so one build can be pointed at
/// OpenAI, a gateway, or a local server without a rebuild.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.config});

  final ChatConfig config;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final _baseUrl = TextEditingController(text: widget.config.baseUrl);
  late final _apiKey = TextEditingController(text: widget.config.apiKey);
  late final _model = TextEditingController(text: widget.config.model);
  late final _system = TextEditingController(text: widget.config.systemPrompt);
  bool _obscureKey = true;

  static final _presets = <String, String>{
    'ai-testing proxy': ChatConfig.defaultProxyBaseUrl,
    'OpenAI': 'https://api.openai.com/v1',
    'Groq': 'https://api.groq.com/openai/v1',
    'OpenRouter': 'https://openrouter.ai/api/v1',
    'Ollama': 'http://localhost:11434/v1',
    'LM Studio': 'http://localhost:1234/v1',
  };

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _system.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Endpoint', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Any OpenAI-protocol server. Nothing here is written to disk.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _presets.entries)
                  ActionChip(
                    label: Text(entry.key),
                    onPressed: () => _baseUrl.text = entry.value,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                helperText: '/chat/completions is appended automatically',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKey,
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API key / proxy token',
                helperText:
                    'Empty for the local proxy; the provider key when '
                    'calling a provider directly',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _system,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'System prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed:
                      () => Navigator.of(context).pop(
                        widget.config.copyWith(
                          baseUrl: _baseUrl.text,
                          apiKey: _apiKey.text,
                          model: _model.text,
                          systemPrompt: _system.text,
                        ),
                      ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
