import 'package:material_ui/material_ui.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math, MathSpan;
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

/// Renders [markdown] the way an app would, inside a scroll view so a raised
/// text scale does not simply overflow the frame.
Widget _page(String markdown, {InlineCodeStyle? inlineCodeStyle}) {
  return Builder(
    builder: (context) => Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GptMarkdown(
            markdown,
            inlineCodeStyle: inlineCodeStyle,
            onLinkTap: (url, title) {},
            inlineLatexBuilder: (latex) =>
                MathSpan(latex.tex, style: latex.style),
            // A display formula wraps to the frame and scrolls what cannot
            // break, so a narrow frame at a raised scale still fits.
            blockLatexBuilder: (latex) => Math.tex(
              latex.tex,
              displayMode: true,
              textStyle: latex.style,
              onError: (context, result) => Text(latex.tex, style: latex.style),
            ),
          ),
        ),
      ),
    ),
  );
}

@UseCase(name: 'Paragraph', type: GptMarkdown, path: '[Text]')
Widget paragraph(BuildContext context) => _page(
  'The quick brown fox jumps over the lazy dog. **Bold**, *italic*, '
  '~~struck through~~ and <u>underlined</u> all in one sentence, long '
  'enough to wrap onto a second line on a phone.',
);

@UseCase(name: 'Headings', type: GptMarkdown, path: '[Text]')
Widget headings(BuildContext context) => _page(
  '# Heading one\n\n'
  'Body text under the first heading.\n\n'
  '## Heading two\n\n### Heading three\n\n#### Heading four\n\n'
  '##### Heading five\n\n###### Heading six',
);

@UseCase(name: 'Inline code', type: GptMarkdown, path: '[Text]')
Widget inlineCode(BuildContext context) => _page(
  'Install with `flutter pub add gpt_markdown`, then call '
  '`GptMarkdown(text)`. A long run wraps: '
  '`final controller = TextEditingController(text: initialValue);`',
  inlineCodeStyle: InlineCodeStyle(
    fontSizeFactor: context.knobs.double.slider(
      label: 'fontSizeFactor',
      initialValue: 0.94,
      min: 0.7,
      max: 1.2,
    ),
    borderWidth: context.knobs.double.slider(
      label: 'borderWidth',
      initialValue: 1,
      max: 3,
    ),
    borderRadius: Radius.circular(
      context.knobs.double.slider(
        label: 'borderRadius',
        initialValue: 4,
        max: 12,
      ),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: context.knobs.double.slider(
        label: 'horizontal padding',
        max: 12,
      ),
      vertical: context.knobs.double.slider(
        label: 'vertical padding',
        initialValue: 1,
        max: 8,
      ),
    ),
  ),
);

@UseCase(name: 'Links and autolinks', type: GptMarkdown, path: '[Text]')
Widget links(BuildContext context) => _page(
  'See [the setup docs](https://example.com/setup) for details.\n\n'
  'Bare URLs are linked too: https://pub.dev/packages/gpt_markdown\n\n'
  'So are hosts and addresses: www.example.com and ada@example.com\n\n'
  'A long link wraps across lines: '
  '[a very long link label that will not fit on one line of a phone]'
  '(https://example.com)',
);

@UseCase(name: 'Bullet list', type: GptMarkdown, path: '[Blocks]')
Widget bulletList(BuildContext context) => _page(
  '- first item\n'
  '- second item, long enough that it wraps onto another line on a phone\n'
  '- third item with `code` and [a link](https://example.com)\n'
  '  - a nested item',
);

@UseCase(name: 'Ordered list', type: GptMarkdown, path: '[Blocks]')
Widget orderedList(BuildContext context) => _page(
  '1. Install the package\n'
  '2. Import it\n'
  '3. Render some Markdown, which is the step that takes the most words '
  'and therefore wraps',
);

@UseCase(name: 'Checkboxes', type: GptMarkdown, path: '[Blocks]')
Widget checkboxes(BuildContext context) => _page(
  '- [x] shipped already\n'
  '- [ ] still to do, with a longer label that wraps\n'
  '- [x] done, containing [a link](https://example.com)',
);

@UseCase(name: 'Blockquote', type: GptMarkdown, path: '[Blocks]')
Widget blockquote(BuildContext context) => _page(
  '> A quoted paragraph with `code`, **bold** and '
  '[a link](https://example.com) inside it, long enough to wrap.',
);

@UseCase(name: 'Table', type: GptMarkdown, path: '[Blocks]')
Widget table(BuildContext context) => _page(
  '| Feature | State | Notes |\n'
  '|---|:---:|---|\n'
  '| Inline code | done | chip per line |\n'
  '| Autolinks | done | GFM rules |\n'
  '| Selection | open | block separators |',
);

@UseCase(name: 'Code block', type: GptMarkdown, path: '[Blocks]')
Widget codeBlock(BuildContext context) => _page(
  'Before the block.\n\n'
  '```dart\n'
  'void main() {\n'
  '  runApp(const App());\n'
  '}\n'
  '```\n\n'
  'After the block.',
);

@UseCase(name: 'Maths', type: GptMarkdown, path: '[Blocks]')
Widget maths(BuildContext context) => _page(
  r'Inline \( e^{i\pi} + 1 = 0 \) sits in the sentence.'
  '\n\n'
  r'\[ \int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi} \]',
);

@UseCase(name: 'AI response', type: GptMarkdown, path: '[Pages]')
Widget aiResponse(BuildContext context) => _page('''
# Reversing a linked list

Here is the **iterative** approach, which runs in \\( O(n) \\) time:

```dart
ListNode? reverse(ListNode? head) {
  ListNode? prev;
  var curr = head;
  while (curr != null) {
    final next = curr.next;
    curr.next = prev;
    prev = curr;
    curr = next;
  }
  return prev;
}
```

## Steps

1. Keep a `prev` pointer, starting at null
2. Save `curr.next` before overwriting it
3. Point `curr.next` backwards

| Approach | Time | Space |
|---|:---:|:---:|
| Iterative | O(n) | O(1) |
| Recursive | O(n) | O(n) |

- [x] handles the empty list
- [ ] handles a cycle

> See [the docs](https://example.com) or https://pub.dev for more.
''');

@UseCase(name: 'Right to left', type: GptMarkdown, path: '[Pages]')
Widget rightToLeft(BuildContext context) => Builder(
  builder: (context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GptMarkdown(
            '# عنوان\n\n'
            r'واحد $one^1$ ثلاثة أربعة five $two^2$ سبعة'
            '\n\n- عنصر أول\n- عنصر ثانٍ\n\n'
            'رابط: [الوثائق](https://example.com)',
            textDirection: TextDirection.rtl,
            useDollarSignsForLatex: true,
            inlineLatexBuilder: (latex) =>
                MathSpan(latex.tex, style: latex.style),
          ),
        ),
      ),
    ),
  ),
);

@UseCase(name: 'Emphasis', type: GptMarkdown, path: '[Text]')
Widget emphasis(BuildContext context) => _page(
  '**Bold text**, *italic text*, ~~struck through~~ and <u>underlined</u>.\n\n'
  'Combined: **bold with *italic* inside** and `code in **bold**`.\n\n'
  'A long emphasised run wraps: *the quick brown fox jumps over the lazy '
  'dog and keeps going past the end of the line*.',
);

@UseCase(name: 'Radio buttons', type: GptMarkdown, path: '[Blocks]')
Widget radioButtons(BuildContext context) => _page(
  '(x) selected option\n'
  '( ) unselected option\n'
  '( ) another option with a longer label that wraps on a phone',
);

@UseCase(name: 'Horizontal rule', type: GptMarkdown, path: '[Blocks]')
Widget horizontalRule(BuildContext context) => _page(
  'Text above the rule.\n\n---\n\nText below the rule.\n\n'
  '# A heading, which draws its own rule\n\nAnd body text after it.',
);

@UseCase(name: 'Nested lists', type: GptMarkdown, path: '[Blocks]')
Widget nestedLists(BuildContext context) => _page(
  '- top level item\n'
  '  - nested item\n'
  '    - deeper item\n'
  '- another top level item\n\n'
  '1. first\n'
  '  1. nested first\n'
  '  2. nested second\n'
  '2. second',
);

@UseCase(name: 'Wide table', type: GptMarkdown, path: '[Blocks]')
Widget wideTable(BuildContext context) => _page(
  '| Component | Scales | Notes on the behaviour |\n'
  '|---|:---:|---|\n'
  '| Heading | yes | draws a rule under h1 |\n'
  '| List | yes | marker and label scale together |\n'
  '| Checkbox | yes | marker is a Material widget |\n'
  '| Code block | yes | content does not wrap |',
);

@UseCase(name: 'Images', type: GptMarkdown, path: '[Blocks]')
Widget images(BuildContext context) => _page(
  'An image between two paragraphs.\n\n'
  '![a placeholder](https://example.com/missing.png)\n\n'
  'Text after the image. Inline '
  '![tiny](https://example.com/tiny.png) inside a sentence.',
);

@UseCase(name: 'Inline patterns', type: GptMarkdown, path: '[Text]')
Widget inlinePatterns(BuildContext context) => Builder(
  builder: (context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GptMarkdown(
            'Hey @ada, the mock is ready — see #design for the thread.\n\n'
            'Unknown tokens stay text: #2959 and @nobody and '
            'ada@example.com\n\n'
            'Inside a link they do not fire: '
            '[#design](https://example.com/design)',
            onLinkTap: (url, title) {},
            inlinePatterns: [
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
            ],
          ),
        ),
      ),
    );
  },
);

/// A rounded token used by the inline-pattern use case.
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

@UseCase(name: 'Long AI answer', type: GptMarkdown, path: '[Pages]')
Widget longAnswer(BuildContext context) => _page('''
# Migrating to 2.0

Three things changed. Read the [changelog](https://example.com) first.

## 1. Inline code

`highlightBuilder` is gone. Use `inlineCodeStyle`:

```dart
GptMarkdown(text, inlineCodeStyle: InlineCodeStyle(fontFamily: 'GeistMono'));
```

## 2. Autolinks

Bare URLs like https://pub.dev are linked now. Turn it off with
`autolink: false`.

## 3. Scopes

| Was | Now |
|---|---|
| every component everywhere | `scopes` per component |
| `#chip` inside `[...]` | skipped by default |

- [x] read the changelog
- [ ] update the call sites
- [ ] run the tests

> Inline maths still works: \\( a^2 + b^2 = c^2 \\)

---

That is everything.
''');
