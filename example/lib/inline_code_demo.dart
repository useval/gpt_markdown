import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Standalone demo of inline `code` styling.
///
/// Run it directly with:
/// ```
/// flutter run -t lib/inline_code_demo.dart
/// ```
void main() => runApp(const InlineCodeApp());

/// Named starting points, so the difference is one tap away.
const inlineCodePresets = <String, InlineCodeStyle>{
  'Default': InlineCodeStyle(),
  'Slack': InlineCodeStyle(
    color: Color(0xFFE01E5A),
    backgroundColor: Color(0x0A1D1C1D),
    borderColor: Color(0x221D1C1D),
    borderRadius: Radius.circular(3),
  ),
  'GitHub': InlineCodeStyle(
    backgroundColor: Color(0x14656D76),
    borderColor: Colors.transparent,
    borderRadius: Radius.circular(6),
    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  ),
  'Outline only': InlineCodeStyle(
    backgroundColor: Colors.transparent,
    borderColor: Color(0xFF6366F1),
    borderWidth: 1.2,
  ),
  'No chip': InlineCodeStyle(
    backgroundColor: Colors.transparent,
    borderWidth: 0,
    padding: EdgeInsets.zero,
  ),
};

/// Sample text covering the cases the chip has to survive.
const inlineCodeMarkdown = r'''# Inline code

Install it with `flutter pub add gpt_markdown`, then call `GptMarkdown(text)`.

## It wraps

Inline code is a plain `TextSpan`, so a long run breaks across lines like any
other text and gets one chip per line — narrow the window and watch
`final controller = TextEditingController(text: someVeryLongInitialValue);`
reflow instead of overflowing.

## It survives nesting

- inside a list item: run `flutter test`
- inside **bold text**: the call is `build(context)`
- inside a link: [`GptMarkdown`](https://pub.dev/packages/gpt_markdown)
- inside a heading — see below

### A heading with `inline code` in it

| Call | Returns |
|---|---|
| `of(context)` | the theme |
| `copyWith()` | a new config |

> Quoted code works too: `throw StateError('nope')`

## It is still selectable

Select across this line — `code` included — and the copied text has no gaps.
''';

/// The demo app shell.
class InlineCodeApp extends StatelessWidget {
  /// Creates the demo app.
  const InlineCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — inline code',
      pageBuilder: (toggleTheme) => InlineCodePage(onToggleTheme: toggleTheme),
    );
  }
}

/// Editor, live preview, and the knobs that matter.
class InlineCodePage extends StatefulWidget {
  /// Creates the demo page.
  const InlineCodePage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark, so the tint defaults can be
  /// compared on both grounds.
  final VoidCallback? onToggleTheme;

  @override
  State<InlineCodePage> createState() => _InlineCodePageState();
}

class _InlineCodePageState extends State<InlineCodePage> {
  late final TextEditingController _controller = TextEditingController(
    text: inlineCodeMarkdown,
  );
  String _preset = 'Default';
  double _radius = 4;
  double _borderWidth = 1;
  double _sizeFactor = 0.94;
  double _hPadding = 0;
  double? _fillAlpha;
  double? _lineAlpha;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The preset with every field resolved against the current scheme, so the
  /// alpha sliders always have a concrete colour to work from.
  InlineCodeStyle get _resolvedPreset =>
      inlineCodePresets[_preset]!.resolve(Theme.of(context).colorScheme);

  InlineCodeStyle get _style {
    final resolved = _resolvedPreset;
    final fill = resolved.backgroundColor!;
    final line = resolved.borderColor!;
    return resolved.copyWith(
      backgroundColor:
          _fillAlpha == null ? fill : fill.withValues(alpha: _fillAlpha),
      borderColor:
          _lineAlpha == null ? line : line.withValues(alpha: _lineAlpha),
      borderRadius: Radius.circular(_radius),
      borderWidth: _borderWidth,
      fontSizeFactor: _sizeFactor,
      padding: EdgeInsets.symmetric(horizontal: _hPadding, vertical: 1),
    );
  }

  /// Starts each preset from its own colours rather than carrying the previous
  /// preset's alphas across.
  void _selectPreset(String name) {
    setState(() {
      _preset = name;
      _fillAlpha = null;
      _lineAlpha = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    final editor = TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
        hintText: 'Type Markdown here…',
      ),
      onChanged: (_) => setState(() {}),
    );

    final preview = SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: GptMarkdown(
          _controller.text,
          inlineCodeStyle: _style,
          onLinkTap: (url, title) {},
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inline code'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
      ),
      body: Column(
        children: [
          _controls(theme),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _editorPane(theme, editor)),
                      VerticalDivider(
                        width: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      Expanded(child: preview),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(height: 200, child: _editorPane(theme, editor)),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      Expanded(child: preview),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _editorPane(ThemeData theme, Widget editor) => ColoredBox(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: editor,
      );

  Widget _controls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final name in inlineCodePresets.keys)
            ChoiceChip(
              label: Text(name),
              selected: _preset == name,
              onSelected: (_) => _selectPreset(name),
            ),
          _slider('Fill', _fillAlpha ?? _resolvedPreset.backgroundColor!.a, 0,
              0.45, (v) => _fillAlpha = v),
          _slider('Outline', _lineAlpha ?? _resolvedPreset.borderColor!.a, 0,
              0.7, (v) => _lineAlpha = v),
          _slider('Radius', _radius, 0, 12, (v) => _radius = v),
          _slider('Border', _borderWidth, 0, 3, (v) => _borderWidth = v),
          _slider('Size', _sizeFactor, 0.7, 1.2, (v) => _sizeFactor = v),
          _slider('Padding', _hPadding, 0, 12, (v) => _hPadding = v),
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
  ) {
    return SizedBox(
      width: 235,
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: (v) => setState(() => onChanged(v)),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
