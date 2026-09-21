import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';
import 'streaming_reply.dart';

// The reply moved to its own file as it grew; re-exported so anything
// importing it from here keeps working.
export 'streaming_reply.dart';

/// Streaming reveal demo — a simulated LLM reply.
///
/// Run it with:
/// ```
/// flutter run -d macos  -t lib/streaming_demo.dart
/// flutter run -d chrome -t lib/streaming_demo.dart
/// ```
void main() => runApp(const StreamingApp());

/// The demo app shell.
class StreamingApp extends StatelessWidget {
  /// Creates the demo app.
  const StreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — streaming',
      pageBuilder: (toggleTheme) => StreamingPage(onToggleTheme: toggleTheme),
    );
  }
}

/// Replays the reply token by token so the reveal can be watched and tuned.
class StreamingPage extends StatefulWidget {
  /// Creates the demo page.
  const StreamingPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage> {
  Timer? _timer;

  /// Characters delivered so far — the "reply" as the app has received it.
  int _delivered = 0;
  bool _running = false;

  GptMarkdownAnimation _animation = GptMarkdownAnimation.fade;

  /// How a table, fence or rule enters once it is complete.
  GptMarkdownBlockAnimation _blockAnimation = GptMarkdownBlockAnimation.growIn;

  /// How long one character takes to finish arriving, independent of how fast
  /// the head moves.
  double _fadeSeconds = 0.25;

  /// How fast the model emits, in characters per second.
  double _tokensPerSecond = 120;

  /// How fast the reveal draws, independent of the model.
  double _charactersPerSecond = 300;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _delivered = 0;
      _running = true;
    });
    // Deliver in chunks, the way tokens actually arrive — not a character at
    // a time.
    const tick = Duration(milliseconds: 50);
    _timer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final perTick = (_tokensPerSecond * tick.inMilliseconds / 1000).round();
      setState(() {
        _delivered = (_delivered + perTick).clamp(0, streamingReply.length);
        if (_delivered >= streamingReply.length) {
          _running = false;
          timer.cancel();
        }
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _showAll() {
    _timer?.cancel();
    setState(() {
      _delivered = streamingReply.length;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final received = streamingReply.substring(0, _delivered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
      ),
      body: Column(
        children: [
          _controls(theme),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'delivered ${received.length} of ${streamingReply.length} '
              'characters   ·   ${_running ? 'streaming' : 'idle'}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                // A chat-column width, so wrapping behaves like a real app.
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: GptMarkdown(
                    received,
                    // Pinned so the animation control changes only the
                    // animation. Without it `GptMarkdownAnimation.none` falls
                    // to the regex pipeline while every other value forces the
                    // incremental one, and switching between them re-wraps the
                    // text and adds a line after a fenced block — a parser
                    // difference wearing an animation's clothes.
                    animation: _animation,
                    blockAnimation: _blockAnimation,
                    isStreaming: _running,
                    charactersPerSecond: _charactersPerSecond,
                    revealFadeSeconds: _fadeSeconds,
                    onLinkTap: (url, title) {},
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _running ? _stop : _start,
            icon:
                Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(_running ? 'Stop' : 'Stream'),
          ),
          OutlinedButton(onPressed: _showAll, child: const Text('Show all')),
          const SizedBox(width: 8),
          const Text('Characters'),
          for (final option in GptMarkdownAnimation.values)
            ChoiceChip(
              label: Text(option.name),
              selected: _animation == option,
              onSelected: (_) => setState(() => _animation = option),
            ),
          const SizedBox(width: 8),
          const Text('Blocks'),
          for (final option in GptMarkdownBlockAnimation.values)
            ChoiceChip(
              label: Text(option.name),
              selected: _blockAnimation == option,
              onSelected: (_) => setState(() => _blockAnimation = option),
            ),
          _slider(
            'model',
            _tokensPerSecond,
            10,
            600,
            (v) => _tokensPerSecond = v,
            'chars/s emitted',
          ),
          _slider(
            'reveal',
            _charactersPerSecond,
            20,
            1200,
            (v) => _charactersPerSecond = v,
            'chars/s drawn',
          ),
          _slider(
            'fade',
            _fadeSeconds,
            0,
            1.2,
            (v) => _fadeSeconds = v,
            'seconds per character',
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 240,
        child: Row(
          children: [
            SizedBox(width: 48, child: Text(label)),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (v) => setState(() => onChanged(v)),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                // Sub-second ranges need decimals; rates do not.
                max <= 2 ? value.toStringAsFixed(2) : value.round().toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
