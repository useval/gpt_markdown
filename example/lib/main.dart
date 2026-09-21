import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'autolink_demo.dart';
import 'chat_demo.dart';
import 'demo_theme.dart';
import 'inline_code_demo.dart';
import 'inline_patterns_demo.dart';
import 'max_lines_demo.dart';
import 'selection_demo.dart';
import 'rtl_demo.dart';
import 'streaming_demo.dart';
import 'text_scale_demo.dart';

/// Minimal example for gpt_markdown — Markdown & LaTeX renderer for Flutter.
///
/// For the full interactive playground visit https://gptmarkdown.com/playground
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The gen UI 3D graphs render through val_3d. Building the renderer here
  // rather than on the first frame avoids racing the platform's Impeller (or,
  // on web, WebGL2) context. Each platform also needs the Flutter GPU flag —
  // see val_3d's SETUP.md; this app has it in its manifest and plists.
  await GenUi3D.ensureInitialized();

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown example',
      pageBuilder: (toggleTheme) => ExamplePage(onToggleTheme: toggleTheme),
    );
  }
}

/// Sample content demonstrating the key features of gpt_markdown.
const _markdown = r'''
# GPT Markdown

**Bold**, *italic*, ~~strikethrough~~, `inline code`, and <u>underline</u>.

---

## LaTeX Math

Inline: \( E = mc^2 \) and the quadratic formula \( x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \)

Block:

\[
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
\]

## Code Block

```dart
GptMarkdown(
  r'**Hello** from _gpt_markdown_! Inline LaTeX: \( E = mc^2 \)',
)
```

## Table

| Feature         | Supported |
|:----------------|:---------:|
| Markdown        | ✅        |
| LaTeX math      | ✅        |
| Code blocks     | ✅        |
| Tables          | ✅        |
| RTL support     | ✅        |
| Custom builders | ✅        |
| WASM            | ✅        |

### Pipes inside cells

A `|` inside math or a code span belongs to the cell, not to the table.

| Complex Number | Real Part (\(a\)) | Modulus (\(|z|\)) | Code     |
|----------------|--------------------|--------------------|----------|
| \(3 + 4i\)     | 3                  | 5                  | `a|b`    |
| \(1 - 2i\)     | 1                  | \(\sqrt{5}\)       | x \| y   |

## Lists

1. Install: `flutter pub add gpt_markdown`
2. Import: `package:gpt_markdown/gpt_markdown.dart`
3. Use: `GptMarkdown(yourText)`

- [x] Render Markdown
- [x] Render LaTeX math
- [ ] Ship your AI app

## AI Output (Markdown + LaTeX + Code mixed)

The **gradient descent** update rule is:

\[ \theta := \theta - \alpha \nabla J(\theta) \]

where \( \alpha \) is the learning rate.

```python
for epoch in range(100):
    grad = compute_gradient(X, y, theta)
    theta -= alpha * grad
```

> Visit [gptmarkdown.com](https://gptmarkdown.com) for the interactive playground.
''';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late final TextEditingController _controller = TextEditingController(
    text: _markdown,
  )..addListener(() => setState(() {}));

  /// True renders with plusparse (the single-pass character scanner), false
  /// with the legacy regex pipeline. Defaults to plusparse.
  bool _incremental = true;

  /// Lets `$…$` open math, so `$|z|$` can be tried alongside `\(|z|\)`.
  bool _useDollar = false;

  TextDirection _textDirection = TextDirection.ltr;

  void _toggleTextDirection() {
    setState(() {
      const values = TextDirection.values;
      final length = values.length;
      _textDirection = values[(_textDirection.index + 1) % length];
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _editor() => TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style:
            const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Type Markdown here…',
          contentPadding: EdgeInsets.all(12),
        ),
      );

  Widget _preview() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(),
          ),
          child: GptMarkdown(
            _controller.text,
            // Both parsers are reachable so the two can be compared on the same
            // input; see the "Parser" switch in the toolbar.
            textDirection: _textDirection,
            // ignore: deprecated_member_use
            incremental: _incremental,
            useDollarSignsForLatex: _useDollar,
            onLinkTap: (url, title) => debugPrint('Link tapped: $url'),
          ),
        ),
      );

  Widget _toolbar() => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              const Text('TextDirection:'),
              TextButton(
                onPressed: _toggleTextDirection,
                child: Text(
                  _textDirection.name,
                ),
              ),
              const Text('Parser:'),
              Switch(
                value: _incremental,
                onChanged: (v) => setState(() => _incremental = v),
              ),
              Text(_incremental ? 'plusparse' : 'legacy regex'),
              const SizedBox(width: 16),
              const Text(r'$…$ math:'),
              Switch(
                value: _useDollar,
                onChanged: (v) => setState(() => _useDollar = v),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset'),
                onPressed: () => setState(() => _controller.text = _markdown),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('gpt_markdown'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Gen UI preview',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const GenUiPreviewPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat demo',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (context) => const ChatDemoPage()),
            ),
          ),
          DemoThemeButton(onToggle: widget.onToggleTheme),
          IconButton(
            tooltip: 'Streaming demo',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StreamingPage()),
            ),
          ),
          IconButton(
            tooltip: 'Text scaling demo',
            icon: const Icon(Icons.format_size_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TextScalePage()),
            ),
          ),
          IconButton(
            tooltip: 'RTL block alignment demo',
            icon: const Icon(Icons.format_textdirection_r_to_l),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RtlPage()),
            ),
          ),
          IconButton(
            tooltip: 'maxLines demo',
            icon: const Icon(Icons.short_text_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MaxLinesPage()),
            ),
          ),
          IconButton(
            tooltip: 'Selection demo',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SelectionPage()),
            ),
          ),
          IconButton(
            tooltip: 'Autolinks demo',
            icon: const Icon(Icons.link_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AutolinkPage()),
            ),
          ),
          IconButton(
            tooltip: 'Inline code demo',
            icon: const Icon(Icons.code_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const InlineCodePage()),
            ),
          ),
          IconButton(
            tooltip: 'Inline patterns demo',
            icon: const Icon(Icons.alternate_email_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const InlinePatternsPage(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Side by side when there is room, stacked when there is not.
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _editor(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _preview()),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _editor(),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _preview()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
