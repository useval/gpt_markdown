import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'alerts_demo.dart';
import 'autolink_demo.dart';
import 'demo_theme.dart';
import 'inline_code_demo.dart';
import 'inline_patterns_demo.dart';
import 'math_demo.dart';
import 'max_lines_demo.dart';
import 'selection_demo.dart';
import 'rtl_demo.dart';
import 'streaming_demo.dart';
import 'text_scale_demo.dart';

/// Minimal example for gpt_markdown — Markdown & LaTeX renderer for Flutter.
///
/// For the full interactive playground visit https://gptmarkdown.com/playground
void main() => runApp(const App());

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

/// Sample content showing every syntax gpt_markdown renders.
///
/// Rendered with the `$…$ math` switch on, which is the default here so the
/// dollar examples work.
const _markdown = r'''
# GPT Markdown

Every syntax the renderer understands, one section each. Edit anything on
the left and watch it render.

## Headings

# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6

### Closing hashes are optional ###

Setext heading 1
================

Setext heading 2
----------------

## Emphasis

**Bold**, *italic*, ***bold italic***, ~~strikethrough~~ and <u>underline</u>.

__Bold__, _italic_ and ___bold italic___ with underscores.

Mixed: **bold with _italic_ inside** and *italic with **bold** inside*.

An underscore inside a word is never emphasis: snake_case_name, MAX_VALUE.

A star with a space after it is arithmetic: 2 * 3 * 4 = 24.

## Inline code

Single backticks: `flutter pub add gpt_markdown`.

Double backticks hold a backtick: `` Use `code` here ``.

Markup is not parsed in code: `**not bold** _not italic_ &amp;`.

## Escapes and entities

Backslash escapes show the character: \*not italic\*, \_not italic\_,
\# not a heading, \`not code\`, price \$5.

Entities decode: &amp; &lt;tag&gt; &copy; &reg; &trade; &mdash; &hellip;
&rarr; &le; &ne; &infin; &alpha;&beta;&gamma; &#169; &#x1F680;

Line one ends with a backslash\
so this is a new line. Line three ends with two spaces  
and so does this break.

<!-- This comment is hidden. Open the editor to see it. -->

## Links

Inline [link](https://gptmarkdown.com), with a
[title](https://gptmarkdown.com "gpt_markdown home"), and to a
[path with spaces](<docs/getting started.md>).

Reference links: [full form][home], [collapsed][], and [shortcut].

Autolinks: https://pub.dev/packages/gpt_markdown, www.flutter.dev,
<https://dart.dev>, and hello@example.com.

[home]: https://gptmarkdown.com "gpt_markdown"
[collapsed]: https://pub.dev
[shortcut]: https://github.com/useval/gpt_markdown

## Images

![120x](https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/math.png)

## Citations and footnotes

Large language models cite sources [1] [2], and the chip opens the
URL defined below it.

Footnotes add notes at the end[^note], numbered in order[^2].

[1]: https://en.wikipedia.org/wiki/Large_language_model
[2]: https://en.wikipedia.org/wiki/Markdown

[^note]: A footnote can hold **Markdown** and [links](https://commonmark.org).
[^2]: The second footnote.

## LaTeX math

Inline with \( E = mc^2 \) and \( x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \).

Block with brackets:

\[
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
\]

Block with dollars:

$$
\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}
$$

Inline with dollars too: $a^2 + b^2 = c^2$, in the same reply as the
`\( \)` formulas above. Prices stay prose: it costs $5 and $10.

## Code blocks

```dart
GptMarkdown(
  r'**Hello** from _gpt_markdown_! Inline LaTeX: \( E = mc^2 \)',
)
```

~~~python
for epoch in range(100):
    theta -= alpha * compute_gradient(X, y, theta)
~~~

````markdown
A longer fence can show a fence:
```bash
echo $HOME
```
````

## Lists

- Bullet with `-`
* Bullet with `*`
+ Bullet with `+`
  - Nested bullet
    - Deeper bullet

1. First
2. Second
   1. Nested ordered
   2. Items

A list can start at any number:

5. Starts at five
6. And keeps counting

Or use parenthesis markers:

1) First
2) Second

- [x] Task done
- [ ] Task to do

(x) Selected option
( ) Other option

- Block maths in a list: \[ a^2 + b^2 = c^2 \]

## Tables

| Left | Center | Right |
|:-----|:------:|------:|
| a    | b      | c     |
| **bold** | `code` | \( x^2 \) |

A `|` inside maths or code belongs to the cell:

| Complex Number | Modulus (\(|z|\)) | Code   |
|----------------|--------------------|--------|
| \(3 + 4i\)     | 5                  | `a|b`  |
| \(1 - 2i\)     | \(\sqrt{5}\)       | x \| y |

## Quotes

> A block quote.
>
> > A nested quote.

## Alerts

> [!NOTE]
> Highlights information that users should take into account, even when skimming.

> [!TIP]
> Optional information to help a user be more successful.

> [!IMPORTANT]
> Crucial information necessary for users to succeed.

> [!WARNING]
> Critical content demanding immediate user attention due to potential risks.

> [!CAUTION]
> Negative potential consequences of an action.

## Horizontal rules

---

***

___

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

  /// Lets `$…$` and `$$…$$` open maths. On by default so the sample's dollar
  /// examples render.
  bool _useDollar = true;

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
          DemoThemeButton(onToggle: widget.onToggleTheme),
          IconButton(
            tooltip: 'Maths & LaTeX demo',
            icon: const Icon(Icons.functions_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MathPage()),
            ),
          ),
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
            tooltip: 'Alerts demo',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AlertsPage()),
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
