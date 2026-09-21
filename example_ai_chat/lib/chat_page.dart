import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'chat_config.dart';
import 'error_report.dart';
import 'metrics_bar.dart';
import 'openai_client.dart';
import 'render_metrics.dart';
import 'settings_sheet.dart';
import 'tracker/issues_page.dart';
import 'tracker/new_issue_page.dart';
import 'tracker/requests_page.dart';
import 'tracker/tracker_api.dart';

/// The harness screen: one full-screen `GptMarkdown` fed by a live model, and
/// a prompt box at the bottom.
///
/// Only the current reply is rendered — the conversation is still kept so
/// follow-up turns have context, but the surface under test stays a single
/// widget rendering a single growing string, which is what the streaming path
/// is designed around.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.initialConfig});

  /// Overrides the endpoint the screen starts with. Only the tests pass this;
  /// the app uses [ChatConfig.fromEnvironment].
  final ChatConfig? initialConfig;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _client = OpenAiClient();
  final _recorder = RenderMetricsRecorder();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  late ChatConfig _config =
      widget.initialConfig ?? ChatConfig.fromEnvironment();
  final List<ChatMessage> _history = [];

  /// The id the proxy recorded this exchange under, so an issue filed from
  /// the reply can point at it. Null when talking to a provider directly.
  int? _requestId;

  StreamSubscription<String>? _subscription;
  final StringBuffer _buffer = StringBuffer();
  String _reply = '';
  String? _error;
  bool _isStreaming = false;

  RenderMetrics _metrics = const RenderMetrics.empty();
  Timer? _liveTicker;

  // Renderer switches — the reason this app exists.
  bool _incremental = true;
  bool _fadeReveal = true;
  bool _showMetrics = true;

  /// Turns off follow-the-tail once the reader scrolls up, so reading while
  /// the answer streams is possible.
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    _subscription?.cancel();
    _client.cancel();
    _recorder.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
    if (atBottom != _stickToBottom) {
      setState(() => _stickToBottom = atBottom);
    }
  }

  void _send() {
    final prompt = _input.text.trim();
    if (prompt.isEmpty || _isStreaming) return;
    if (!_config.isConfigured) {
      _openSettings();
      return;
    }

    _input.clear();
    _inputFocus.requestFocus();
    _history.add(ChatMessage.user(prompt));
    _buffer.clear();

    setState(() {
      _reply = '';
      _error = null;
      _isStreaming = true;
      _stickToBottom = true;
      _requestId = null;
      _metrics = const RenderMetrics.empty();
    });

    _recorder.start();
    // The live readout must not drive a rebuild per chunk on its own — the
    // Markdown surface already rebuilds then. Four updates a second is
    // enough to watch, and cheap.
    _liveTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _isStreaming) setState(() => _metrics = _recorder.live);
    });

    _subscription = _client
        .stream(
          config: _config,
          history: List.of(_history),
          onRequestId: (id) {
            if (mounted) setState(() => _requestId = id);
          },
        )
        .listen(
          _onDelta,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: true,
        );
  }

  void _onDelta(String delta) {
    _buffer.write(delta);
    _recorder.onChunk(delta, _buffer.length);
    setState(() => _reply = _buffer.toString());
    _followTail();
  }

  void _onError(Object error) {
    setState(() => _error = error.toString());
    _finish();
  }

  void _onDone() {
    if (_buffer.isNotEmpty) {
      _history.add(ChatMessage.assistant(_buffer.toString()));
    }
    _finish();
  }

  Future<void> _finish() async {
    _liveTicker?.cancel();
    _liveTicker = null;
    _subscription = null;
    final metrics = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isStreaming = false;
      _metrics = metrics;
    });
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _client.cancel();
    if (_buffer.isNotEmpty) {
      _history.add(ChatMessage.assistant(_buffer.toString()));
    }
    _finish();
  }

  void _followTail() {
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || !_stickToBottom) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _clear() {
    _stop();
    _history.clear();
    _buffer.clear();
    setState(() {
      _reply = '';
      _error = null;
      _metrics = const RenderMetrics.empty();
    });
  }

  Future<void> _openSettings() async {
    final updated = await showModalBottomSheet<ChatConfig>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(config: _config),
    );
    if (updated != null) setState(() => _config = updated);
  }

  /// The tracker lives on the same server as the proxy, so it is built from
  /// the current endpoint rather than configured separately.
  TrackerApi get _tracker => TrackerApi(_config);

  Future<void> _openIssues() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => IssuesPage(api: _tracker)));

  Future<void> _openHistory() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => RequestsPage(api: _tracker)));

  /// Files an issue against the reply currently on screen, carrying the exact
  /// Markdown that produced it.
  Future<void> _reportCurrentReply() async {
    if (_reply.trim().isEmpty) return;
    final prompt = _history.lastWhere(
      (message) => message.role == 'user',
      orElse: () => const ChatMessage.user(''),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => NewIssuePage(
              api: _tracker,
              initialTitle: '',
              initialBody:
                  prompt.content.isEmpty
                      ? ''
                      : '**Prompt**\n\n> ${prompt.content.replaceAll('\n', '\n> ')}\n\n'
                          '**What looks wrong**\n\n',
              markdown: _reply,
              requestId: _requestId,
              initialLabels: const {'bug'},
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('gpt_markdown', style: TextStyle(fontSize: 16)),
            Text(
              _config.model.isEmpty ? 'no model set' : _config.model,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Report an issue with this reply',
            onPressed: _reply.trim().isEmpty ? null : _reportCurrentReply,
            icon: const Icon(Icons.bug_report_outlined),
          ),
          IconButton(
            tooltip: 'Issues',
            onPressed: _openIssues,
            icon: const Icon(Icons.checklist_outlined),
          ),
          IconButton(
            tooltip: 'History',
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _reply.isEmpty && _history.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'Renderer options',
            icon: const Icon(Icons.tune),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'incremental':
                    _incremental = !_incremental;
                  case 'fade':
                    _fadeReveal = !_fadeReveal;
                  case 'metrics':
                    _showMetrics = !_showMetrics;
                }
              });
            },
            itemBuilder:
                (_) => [
                  _check('incremental', 'Incremental rendering', _incremental),
                  _check('fade', 'Fade reveal', _fadeReveal),
                  _check('metrics', 'Metrics bar', _showMetrics),
                ],
          ),
          IconButton(
            tooltip: 'Endpoint settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _surface(theme)),
          if (_showMetrics)
            MetricsBar(metrics: _metrics, isStreaming: _isStreaming),
          _composer(theme),
        ],
      ),
    );
  }

  PopupMenuItem<String> _check(String value, String label, bool on) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(on ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  /// The widget under test, filling everything above the prompt box.
  Widget _surface(ThemeData theme) {
    if (_error != null) {
      return _errorView(theme, _error!);
    }
    if (_reply.isEmpty && !_isStreaming) {
      return _centered(
        theme,
        icon: Icons.auto_awesome_outlined,
        color: theme.colorScheme.primary,
        title: 'Ask something',
        body:
            _config.isConfigured
                ? 'The reply renders here as one GptMarkdown widget.\n'
                    'Ask for tables, LaTeX and code to stress the parser.'
                : 'Set a base URL and model in settings first.',
      );
    }

    return SelectionArea(
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SizedBox(
              width: double.infinity,
              child: GptMarkdown(
                _reply,
                // ignore: deprecated_member_use
                incremental: _incremental,
                animation:
                    _fadeReveal
                        ? GptMarkdownAnimation.fade
                        : GptMarkdownAnimation.none,
                isStreaming: _isStreaming,
                charactersPerSecond: 300,
                style: theme.textTheme.bodyLarge,
                onLinkTap: (url, title) => _toast('Link: $url'),
                onImageTap: (url) => _toast('Image: $url'),
                onSourceTagTap: (source) => _toast('Source: $source'),
                onCodeCopy: (code) {
                  Clipboard.setData(ClipboardData(text: code));
                  _toast('Code copied');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A failure the reader can select, copy and paste into a bug report.
  Widget _errorView(ThemeData theme, String message) {
    return ErrorReportView(
      report: buildErrorReport(
        message: message,
        config: _config,
        incremental: _incremental,
        fadeReveal: _fadeReveal,
      ),
      onRetry: _retry,
      onSettings: _openSettings,
    );
  }

  /// Re-sends the last prompt, so a fixed setting can be tried immediately.
  void _retry() {
    final lastUser = _history.lastWhere(
      (message) => message.role == 'user',
      orElse: () => const ChatMessage.user(''),
    );
    if (lastUser.content.isEmpty) {
      setState(() => _error = null);
      return;
    }
    // The failed turn is already in the history; drop it, and anything after
    // it, so the resend does not duplicate the prompt.
    while (_history.isNotEmpty && _history.last.role != 'user') {
      _history.removeLast();
    }
    if (_history.isNotEmpty) _history.removeLast();
    _input.text = lastUser.content;
    _send();
  }

  Widget _centered(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask the model something…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _isStreaming
                ? IconButton.filled(
                  tooltip: 'Stop',
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded),
                )
                : IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}
