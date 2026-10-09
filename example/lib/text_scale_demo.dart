import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Inspector for text scaling, without a phone or an emulator.
///
/// Shows the same Markdown twice — once at 1x as a reference, once at the
/// chosen scale — inside a phone-width frame, and reports the measured height
/// of each. The ratio is the number that matters: at a 2x setting a component
/// should be about twice as tall, not four times.
///
/// Run it with:
/// ```
/// flutter run -d macos -t lib/text_scale_demo.dart
/// flutter run -d chrome -t lib/text_scale_demo.dart
/// ```
void main() => runApp(const TextScaleApp());

/// Widths of common phones, in logical pixels.
const _devices = <String, double>{
  'iPhone SE': 375,
  'iPhone 15': 393,
  'Pixel 7': 412,
  'iPad mini': 744,
  // Wide enough that nothing rewraps, which is the only width where comparing
  // heights says anything about reserved space.
  'Wide (no wrap)': 1400,
};

/// The height ratio only says something about reserved space when nothing
/// rewraps between the two renders. Any width can rewrap at a high enough
/// scale, so the demo reports the numbers and names the caveat rather than
/// passing judgement on them.

/// Steps a real user can pick in the OS accessibility settings.
const _scaleSteps = <double>[0.85, 1.0, 1.15, 1.3, 1.5, 2.0, 2.5, 3.0];

/// One sample per construct, so each can be judged on its own.
/// Every component the package renders, one sample each.
const textScaleSamples = <String, String>{
  'Paragraph': 'The quick brown fox jumps over the lazy dog, twice.',
  'Headings': '# Heading one\n\n## Heading two\n\n### Heading three',
  'Links': 'See [the docs](https://example.com) and https://example.com here.',
  'Inline code': 'Run `flutter test` and then `flutter run` to start.',
  'Bullet list': '- first item\n- second item\n- third item',
  'Ordered list': '1. first item\n2. second item\n3. third item',
  'Checkboxes': '- [x] done already\n- [ ] still to do',
  'Radio buttons': '(x) selected option\n( ) unselected option',
  'Emphasis':
      '**Bold**, *italic*, ~~struck through~~ and <u>underlined</u>, plus '
          '**bold with *italic* inside** and `code in **bold**`.',
  'Nested lists':
      '- top level\n  - nested\n    - deeper\n- another top level\n\n'
          '1. first\n  1. nested first\n  2. nested second\n2. second',
  'Horizontal rule': 'Above the rule.\n\n---\n\nBelow the rule.',
  'Images':
      'Before the image.\n\n![alt text](https://example.com/missing.png)\n\n'
          'After it, and inline ![tiny](https://example.com/t.png) too.',
  'Wide table': '| Component | Scales | Notes |\n|---|:---:|---|\n'
      '| Heading | yes | draws its own rule |\n'
      '| List | yes | marker and label together |\n'
      '| Code block | yes | content does not wrap |',
  'Source tags': 'A claim with a citation [1] and another one [2].',
  'Autolinks': 'Bare: https://pub.dev/packages/gpt_markdown\n\n'
      'Host: www.example.com and address ada@example.com\n\n'
      'Trailing punctuation stays out: see https://example.com.\n\n'
      'Balanced parens stay in: '
      'https://en.wikipedia.org/wiki/Curry_(programming)\n\n'
      'Angle form: <https://example.com> and <ada@example.com>\n\n'
      'Allowlisted scheme: myapp://open?id=7\n\n'
      'Emphasis does not leak: **https://example.com**',
  'Inline patterns':
      'Hey @ada, the mock is ready :tada: — see #design for the thread.\n\n'
          'Unknown tokens stay text: #2959, @nobody, ada@example.com\n\n'
          'Inside a link they do not fire: '
          '[#design](https://example.com/design)\n\n'
          'A long line with a @grace mention and a #general channel that wraps '
          'onto another line on a phone.',
  'Right to left':
      '# عنوان\n\nنص عربي مع [رابط](https://example.com) و `code`.\n\n'
          '- عنصر أول\n- عنصر ثانٍ',
  'Blockquote': '> A quoted line, with `code` and a [link](https://x.com).',
  'Table': '| Name | Value |\n|---|---|\n| one | 1 |\n| two | 2 |',
  'Code block': '```dart\nvoid main() {\n  print("hi");\n}\n```',
  // Raw strings keep the LaTeX backslashes; the line breaks have to come from
  // a normal string, or `\n\n` stays two literal characters and the block
  // maths never starts a new block.
  'Math': 'Inline '
      r'\( a^2 + b^2 = c^2 \)'
      ' and a block:\n\n'
      r'\[ \int_0^1 x\,dx \]',
  'Dollar maths': r'Inline $x^2 + y^2$, a price that stays text: $5 and $10.'
      '\n\n'
      r'$$ \sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6} $$',
  'Underscore emphasis':
      '__Bold__, _italic_ and ___both___ with underscores, while '
          'snake_case_name stays plain.',
  'Setext headings': 'Heading one\n===========\n\nHeading two\n-----------',
  'Code spans and fences': 'Double backticks hold a backtick: '
      '`` a `tick` inside ``.\n\n'
      '~~~python\nprint("tilde fence")\n~~~\n\n'
      '````md\n```dart\nvoid main() {}\n```\n````',
  'Reference links':
      'Read [the guide][guide], the [pub page][], or [guide].\n\n'
          '[guide]: https://example.com/guide "The guide"\n'
          '[pub page]: https://pub.dev',
  'Footnotes': 'A claim that needs a note[^1], and a second one[^2].\n\n'
      '[^1]: The first footnote, long enough to wrap onto a second line on '
      'a phone.\n'
      '[^2]: The second footnote.',
  'Citations with URLs': 'A claim [1] and another [2], each chip opening '
      'its URL.\n\n'
      '[1]: https://example.com/one\n'
      '[2]: https://example.com/two',
  'Escapes and entities': r'\*not italic\*, \_not italic\_, \# not a heading.'
      '\n\n'
      'Entities: &amp; &copy; &mdash; &rarr; &alpha;&beta;&gamma; &#x1F680;',
  'Everything': '''# Release notes

Body text with **bold**, *italic*, ~~struck through~~, <u>underlined</u> and
`inline code`, long enough to wrap on a phone. The same with underscores:
__bold__ and _italic_, while snake_case_name stays plain. Escapes \\*stay\\*
literal, and entities decode: &copy; &mdash; &rarr;.

Setext heading
--------------

## Links and tokens

An explicit [link to the docs](https://example.com), a bare URL
https://pub.dev/packages/gpt_markdown, a host www.example.com and an address
ada@example.com. An angle autolink <https://example.com>, an allowlisted
scheme myapp://open?id=7, and a citation after the claim [1]. A reference
link to [the guide][guide], and a footnote[^note].

[1]: https://example.com/source
[guide]: https://example.com/guide

[^note]: A footnote, rendered where it is written.

App tokens: @ada shipped it :tada: — discuss in #design. Unknown ones stay
plain text: #2959 and @nobody.

### Lists

- first bullet item
- second bullet item with `code`
  - a nested bullet
    - and a deeper one
- third bullet item

1. first numbered item
2. second numbered item
  1. nested numbered
  2. nested again

### Tasks and options

- [x] shipped already
- [ ] still to do

(x) selected option
( ) unselected option

---

### A table

| Component | Scales | Notes |
|---|:---:|---|
| Heading | yes | draws its own rule |
| List | yes | marker and label together |
| Checkbox | yes | marker is a Material widget |
| Code block | yes | content does not wrap |

### Code

```dart
void main() {
  runApp(const App());
}
```

~~~python
print("a tilde fence")
~~~

### Maths

Inline \\( a^2 + b^2 = c^2 \\) inside a sentence, then a block:

\\[ \\int_0^1 x^2\\,dx = \\frac{1}{3} \\]

And a dollar block:

\$\$ e^{i\\pi} + 1 = 0 \$\$

### An image

![alt text](https://example.com/missing.png)

> A blockquote to finish, with `code`, **bold** and
> [a link](https://example.com) inside it.

###### The smallest heading
''',
};

/// `@mention`, `#channel` and `:emoji:` — the inline syntaxes an app layers on
/// top of Markdown. Only known names become chips, so `#2959` stays text.
List<InlinePattern> _demoPatterns(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return [
    InlinePattern.prefixed(
      prefix: '#',
      knownNames: const ['design', 'general'],
      builder: (context, match, style) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _Pill(
          label: match.group(0)!,
          style: style,
          background: colors.primaryContainer,
          foreground: colors.onPrimaryContainer,
        ),
      ),
    ),
    InlinePattern.prefixed(
      prefix: '@',
      knownNames: const ['ada', 'grace'],
      builder: (context, match, style) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _Pill(
          label: match.group(0)!,
          style: style,
          background: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
        ),
      ),
    ),
    InlinePattern(
      pattern: RegExp(':(tada|rocket|fire):'),
      builder: (context, match, style) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Text(
          const {'tada': '🎉', 'rocket': '🚀', 'fire': '🔥'}[match.group(1)]!,
          style: TextStyle(fontSize: (style.fontSize ?? 14) * 1.15),
        ),
      ),
    ),
  ];
}

/// A rounded token, used by the inline-pattern sample.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.style,
    required this.background,
    required this.foreground,
  });

  final String label;
  final TextStyle style;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: style.copyWith(color: foreground, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// The demo app shell.
class TextScaleApp extends StatelessWidget {
  /// Creates the demo app.
  const TextScaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — text scaling',
      pageBuilder: (toggleTheme) => TextScalePage(onToggleTheme: toggleTheme),
    );
  }
}

/// Side-by-side reference and scaled render, with the measured ratio.
class TextScalePage extends StatefulWidget {
  /// Creates the demo page.
  const TextScalePage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<TextScalePage> createState() => _TextScalePageState();
}

class _TextScalePageState extends State<TextScalePage> {
  final _referenceKey = GlobalKey();
  final _scaledKey = GlobalKey();
  final _explicitKey = GlobalKey();

  String _sample = 'Everything';
  double _scale = 2.0;
  double _width = 393;
  bool _showReference = true;

  double? _referenceHeight;
  double? _scaledHeight;
  double? _explicitHeight;
  int? _referenceLines;
  int? _scaledLines;

  /// Lines in the first paragraph under [key], and its height.
  ///
  /// Total height is a poor measure on its own: doubling the font makes a
  /// sentence need more lines, so the height can grow 5x while every line is
  /// exactly 2x taller. Line count separates the two.
  ({double height, int lines})? _measurePane(GlobalKey key) {
    final root = key.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize) {
      return null;
    }
    RenderParagraph? paragraph;
    void find(RenderObject node) {
      if (paragraph != null) {
        return;
      }
      if (node is RenderParagraph) {
        paragraph = node;
        return;
      }
      node.visitChildren(find);
    }

    find(root);
    final found = paragraph;
    if (found == null) {
      return (height: root.size.height, lines: 0);
    }
    final text = found.text.toPlainText();
    final boxes = found.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final lines = boxes.map((b) => b.top.round()).toSet().length;
    return (height: root.size.height, lines: lines);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Reads both rendered heights after layout. Only calls [setState] when a
  /// number actually changed, so this cannot loop.
  void _measure() {
    if (!mounted) {
      return;
    }
    final referencePane = _measurePane(_referenceKey);
    final scaledPane = _measurePane(_scaledKey);
    final explicit = _explicitKey.currentContext?.size?.height;
    if (referencePane?.height == _referenceHeight &&
        scaledPane?.height == _scaledHeight &&
        explicit == _explicitHeight &&
        referencePane?.lines == _referenceLines &&
        scaledPane?.lines == _scaledLines) {
      return;
    }
    setState(() {
      _referenceHeight = referencePane?.height;
      _scaledHeight = scaledPane?.height;
      _explicitHeight = explicit;
      _referenceLines = referencePane?.lines;
      _scaledLines = scaledPane?.lines;
    });
  }

  void _afterBuild() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  /// One phone-shaped pane.
  ///
  /// [scale] is applied through [MediaQuery], the way a platform font setting
  /// arrives. When [viaParameter] is true it is passed to
  /// [GptMarkdown.textScaler] instead and the platform stays at 1x, so the two
  /// routes can be compared side by side — an app that scales text itself uses
  /// that path, and it has to end up in the same place.
  Widget _phone({
    required Key key,
    required double scale,
    required String label,
    bool viaParameter = false,
  }) {
    final theme = Theme.of(context);
    final ratio = scale.toStringAsFixed(2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$label — ${ratio}x',
            style: theme.textTheme.labelLarge,
          ),
        ),
        Container(
          width: _width,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline, width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(12),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: viaParameter
                  ? TextScaler.noScaling
                  : TextScaler.linear(scale),
            ),
            child: SingleChildScrollView(
              child: KeyedSubtree(
                key: key,
                child: GptMarkdown(
                  textScaleSamples[_sample]!,
                  textScaler: viaParameter ? TextScaler.linear(scale) : null,
                  // Everything added in 2.0 is exercised here too. Pattern
                  // chips are `WidgetSpan`s, exactly the shape that used to
                  // scale badly.
                  inlinePatterns: _demoPatterns(context),
                  autolinkSchemes: const {'myapp'},
                  useDollarSignsForLatex: true,
                  textDirection: _sample == 'Right to left'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  onLinkTap: (url, title) {},
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _afterBuild();
    final theme = Theme.of(context);
    final reference = _referenceHeight;
    final scaled = _scaledHeight;
    final ratio = (reference != null && scaled != null && reference > 0)
        ? scaled / reference
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text scaling'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
      ),
      body: Column(
        children: [
          _controls(theme),
          if (ratio != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _banner(reference!, scaled!, ratio),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  if (_showReference)
                    _phone(
                      key: _referenceKey,
                      scale: 1.0,
                      label: 'Reference',
                    ),
                  _phone(
                    key: _scaledKey,
                    scale: _scale,
                    label: 'Platform setting',
                  ),
                  _phone(
                    key: _explicitKey,
                    scale: _scale,
                    label: 'textScaler parameter',
                    viaParameter: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Explains the two numbers that matter and keeps them apart.
  String _banner(double reference, double scaled, double ratio) {
    final parameter = _explicitHeight;
    final matches = parameter != null && (parameter - scaled).abs() < 1;
    final lines = _referenceLines ?? 0;
    final scaledLines = _scaledLines ?? 0;

    final perLine = (lines > 0 && scaledLines > 0)
        ? (scaled / scaledLines) / (reference / lines)
        : null;

    return 'text ${_scale.toStringAsFixed(2)}x'
        '${perLine != null ? '   ·   line height ${perLine.toStringAsFixed(2)}x' : ''}'
        '   ·   lines $lines → $scaledLines'
        '   ·   height ${reference.toStringAsFixed(0)} → '
        '${scaled.toStringAsFixed(0)} (${ratio.toStringAsFixed(2)}x)'
        '   ·   parameter pane ${matches ? 'matches' : 'DIFFERS'}'
        '\n'
        'Line height is the number to watch — it should equal the set scale. '
        'Total height grows faster because bigger text needs more lines; pick '
        '"Wide (no wrap)" to remove that effect.';
  }

  Widget _controls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final name in textScaleSamples.keys)
                ChoiceChip(
                  label: Text(name),
                  selected: _sample == name,
                  onSelected: (_) => setState(() => _sample = name),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Scale'),
              for (final step in _scaleSteps)
                ChoiceChip(
                  label: Text('${step}x'),
                  selected: (_scale - step).abs() < 0.001,
                  onSelected: (_) => setState(() => _scale = step),
                ),
              SizedBox(
                width: 220,
                child: Slider(
                  value: _scale,
                  min: 0.8,
                  max: 3.0,
                  onChanged: (v) => setState(() => _scale = v),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Device'),
              for (final device in _devices.entries)
                ChoiceChip(
                  label: Text(device.key),
                  selected: _width == device.value,
                  onSelected: (_) => setState(() => _width = device.value),
                ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _showReference,
                    onChanged: (v) => setState(() => _showReference = v),
                  ),
                  const Text('show 1x reference'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
