import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Inspector for `maxLines`, the clamped-preview case.
///
/// A chat list shows the first line or two of a reply; a notification shows
/// three. That is `maxLines` plus `overflow`, and it is the one setting whose
/// whole job is to be a lie about how much content there is — so the only way
/// to check it is to measure the rendered height and count the lines against
/// what was asked for.
///
/// Both parsers render side by side, because that is where this went wrong:
/// the incremental parser splits a document at blank lines and gives each
/// segment its own paragraph, and `maxLines` belongs to a paragraph. Every
/// segment took the full allowance, so a two-line clamp of a five paragraph
/// reply drew ten lines — no overflow mark, no error, just the wrong height.
/// The two columns here should agree exactly.
///
/// Run it with:
/// ```
/// flutter run -d macos -t lib/max_lines_demo.dart
/// flutter run -d chrome -t lib/max_lines_demo.dart
/// ```
void main() => runApp(const MaxLinesApp());

/// Samples chosen for how they interact with a line budget, not for variety.
const maxLinesSamples = <String, String>{
  // The case that was broken: several blocks, so several segments.
  'Multi-paragraph reply':
      'The first paragraph of the answer, long enough that it wraps onto more '
          'than one line at a preview width.\n\n'
          'A second paragraph continuing the thought, also long enough to '
          'wrap more than once.\n\n'
          'A third paragraph, which a two-line preview should never reach.',
  // One block: this always worked, and is the control.
  'Single paragraph':
      'One paragraph on its own, long enough that it wraps across several '
          'lines at a preview width so that a clamp has something to cut off '
          'and an ellipsis to show.',
  // Blocks that are widgets rather than text are the interesting edge: a line
  // budget cannot slice a table in half.
  'Prose then a list':
      'An introduction line before the list, long enough to wrap.\n\n'
          '- first item\n- second item\n- third item',
  'Prose then a code block': 'Some text introducing the snippet below it.\n\n'
      '```dart\nvoid main() {\n  print("hello");\n}\n```',
  'Prose then a table': 'A sentence before the table.\n\n'
      '| Name | Value |\n|---|---|\n| alpha | 1 |\n| beta | 2 |',
  'Heading then prose':
      '## A heading\n\nProse under the heading, long enough that it wraps '
          'onto more than a single line at this width.',
};

const _lineSteps = <int?>[1, 2, 3, 5, 10, null];

const _widths = <String, double>{
  'Chat list (320)': 320,
  'iPhone 15 (393)': 393,
  'Tablet (700)': 700,
};

/// The demo app.
class MaxLinesApp extends StatelessWidget {
  /// Creates the demo app.
  const MaxLinesApp({super.key});

  @override
  Widget build(BuildContext context) => DemoApp(
        title: 'gpt_markdown — maxLines',
        pageBuilder: (toggleTheme) => MaxLinesPage(onToggleTheme: toggleTheme),
      );
}

/// The demo page.
class MaxLinesPage extends StatefulWidget {
  /// Creates the demo page.
  const MaxLinesPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<MaxLinesPage> createState() => _MaxLinesPageState();
}

class _MaxLinesPageState extends State<MaxLinesPage> {
  final _incrementalKey = GlobalKey();
  final _legacyKey = GlobalKey();

  String _sample = 'Multi-paragraph reply';
  int? _maxLines = 2;
  double _width = 320;
  bool _ellipsis = true;

  double? _incrementalHeight;
  double? _legacyHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) {
      return;
    }
    final incremental = _incrementalKey.currentContext?.size?.height;
    final legacy = _legacyKey.currentContext?.size?.height;
    if (incremental == _incrementalHeight && legacy == _legacyHeight) {
      return;
    }
    setState(() {
      _incrementalHeight = incremental;
      _legacyHeight = legacy;
    });
  }

  void _change(VoidCallback apply) {
    setState(apply);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    final source = maxLinesSamples[_sample]!;
    // Heights that differ mean the clamp depends on which parser ran, which a
    // caller has no way to predict and never asked for.
    final agree = _incrementalHeight != null &&
        _legacyHeight != null &&
        (_incrementalHeight! - _legacyHeight!).abs() < 0.5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('maxLines'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
      ),
      body: Column(
        children: [
          _controls(),
          const Divider(height: 1),
          _verdict(agree),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _preview(
                      'incremental: true (default)',
                      _incrementalKey,
                      source,
                      // ignore: deprecated_member_use
                      incremental: true,
                      height: _incrementalHeight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _preview(
                      'incremental: false',
                      _legacyKey,
                      source,
                      // ignore: deprecated_member_use
                      incremental: false,
                      height: _legacyHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _sample,
              onChanged: (v) => _change(() => _sample = v ?? _sample),
              items: [
                for (final name in maxLinesSamples.keys)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
            ),
            DropdownButton<double>(
              value: _width,
              onChanged: (v) => _change(() => _width = v ?? _width),
              items: [
                for (final entry in _widths.entries)
                  DropdownMenuItem(value: entry.value, child: Text(entry.key)),
              ],
            ),
            SegmentedButton<int?>(
              segments: [
                for (final lines in _lineSteps)
                  ButtonSegment<int?>(
                    value: lines,
                    label: Text(lines?.toString() ?? 'off'),
                  ),
              ],
              selected: {_maxLines},
              onSelectionChanged: (s) => _change(() => _maxLines = s.first),
              showSelectedIcon: false,
            ),
            FilterChip(
              label: const Text('ellipsis'),
              selected: _ellipsis,
              onSelected: (v) => _change(() => _ellipsis = v),
            ),
          ],
        ),
      );

  Widget _verdict(bool agree) {
    final scheme = Theme.of(context).colorScheme;
    final known = _incrementalHeight != null && _legacyHeight != null;
    // Flutter's own rule, not this package's: an ellipsis with no line count
    // truncates to a single line, and a plain `Text` does the same. Worth
    // saying out loud, because the preview looks broken until you know it.
    final ellipsisIsTheBudget = _maxLines == null && _ellipsis;
    final text = !known
        ? 'Measuring…'
        : !agree
            ? 'Parsers disagree — incremental '
                '${_incrementalHeight!.toStringAsFixed(1)} px against legacy '
                '${_legacyHeight!.toStringAsFixed(1)} px'
            : ellipsisIsTheBudget
                ? "One line, by Flutter's rule: an ellipsis with no maxLines "
                    'truncates to a single line. Both parsers agree at '
                    '${_incrementalHeight!.toStringAsFixed(1)} px.'
                : 'Both parsers clamp to the same height: '
                    '${_incrementalHeight!.toStringAsFixed(1)} px';
    return Container(
      width: double.infinity,
      color: agree || !known ? scheme.surfaceContainer : scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: agree || !known ? scheme.onSurface : scheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _preview(
    String label,
    GlobalKey key,
    String source, {
    required bool incremental,
    required double? height,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Text(
          height == null ? '—' : '${height.toStringAsFixed(1)} px',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        // The frame is the preview slot a chat list would give it. A clamp
        // that works keeps the content inside it whatever the sample.
        Container(
          width: _width,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: _width - 24,
            child: GptMarkdown(
              source,
              key: key,
              // ignore: deprecated_member_use
              incremental: incremental,
              maxLines: _maxLines,
              overflow: _ellipsis ? TextOverflow.ellipsis : TextOverflow.clip,
            ),
          ),
        ),
      ],
    );
  }
}
