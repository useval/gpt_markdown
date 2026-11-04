# Getting started

## Install

```yaml
dependencies:
  gpt_markdown: ^1.4.1
```

```dart
import 'package:gpt_markdown/gpt_markdown.dart';
```

One import brings in the widget, the style classes, the builder typedefs and
`GptMarkdownConfig`.

---

## Render something

```dart
GptMarkdown('# Hello\n\nSome **bold** text and `inline code`.')
```

That is the whole minimum.

> [!IMPORTANT]
> The widget sizes itself to its content and does not scroll. For anything
> longer than a sentence, put it in something scrollable — otherwise a long
> reply overflows.

```dart
SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: GptMarkdown(reply),
)
```

In a chat list, one per bubble:

```dart
ListView.builder(
  itemCount: messages.length,
  itemBuilder: (context, i) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: GptMarkdown(messages[i].text),
  ),
)
```

---

## What is supported

| | Syntax |
|---|---|
| Headings | `#` to `######` (closing `#`s optional), and `Title` underlined with `===` or `---` |
| Emphasis | `**bold**`, `*italic*`, `__bold__`, `_italic_`, `~~strike~~`, `<u>underline</u>` |
| Code | `` `inline` ``, ``` `` with ` inside `` ```, highlighted ```` ``` ```` and `~~~` fences |
| Lists | `-`, `1.`, nested |
| Tasks | `- [x]`, `- [ ]` |
| Options | `(x)`, `( )` |
| Tables | with `:---:` alignment |
| Quotes | `>` |
| Rules | `---` |
| Links | `[label](url "title")`, `[label](<url with spaces>)`, `[label][ref]` with `[ref]: url`, and bare URLs |
| Images | `![alt](url)`, `![alt][ref]`, and as a link: `[![alt](src)](url)` — PNG, JPEG, GIF, WebP and SVG |
| Maths | `\( inline \)`, `\[ block \]`, and `$…$` / `$$…$$` with `useDollarSignsForLatex` |
| Citations | `[1]` — with a `[1]: url` line, a tap opens the URL |
| Footnotes | `text[^1]` with `[^1]: note` |
| Escapes | `\*`, `\_`, `\#`, `\$`, … show the character itself |
| Entities | `&amp;`, `&nbsp;`, `&#169;`, `&#x1F600;` |
| Comments | `<!-- hidden -->` |
| HTML | `<b>`, `<i>`, `<code>`, `<br>`, `<a href>`, `<img src>`, `<div>` wrappers — [the full list](commonmark.md#html); add your own with [`htmlTags`](custom-components.md#html-tags) |

Bare URLs, `www.` hosts, email addresses and `<https://…>` are linked
automatically — see [inline syntax](inline-syntax.md).

The parser passes 530 of the 652 CommonMark 0.31.2 spec examples; the rest
are raw HTML and indented code blocks, which are not supported, and three
leniencies for model output. See [CommonMark conformance](commonmark.md).

A few rules follow CommonMark and are worth knowing, because they decide
what stays plain text:

- An underscore inside a word is never emphasis: `snake_case_name` stays as
  written. Outside a word it is, so an unquoted `__init__` renders as bold
  `init` — put identifiers in backticks.
- `*` or `_` followed by a space opens nothing, so `2 * 3 * 4` is arithmetic.
- With `useDollarSignsForLatex`, maths comes first: a `$` pairs with the
  next `$` on its line, and the pair is maths unless both dollars are prices
  — `$5 and $10`, `$5M to $10M`, `5$ and 10$` stay prose. `$ x $`,
  `$2 + 3$` and `$1 \theta $2a` are maths. A `$` with no partner on its line
  is prose, and dollars inside code are never maths. Write `\$` for a dollar
  that must stay text, such as a price on the same line as a formula.
- `---` directly under a line of text makes that line a heading. Leave a
  blank line before `---` for a horizontal rule.
- Only a list starting at `1.` can begin inside a paragraph, so prose that
  wraps onto a line starting `14. ` stays prose. A line directly after a list
  item continues that item; leave a blank line to end the list.
- `**` is lenient — `**Note:**text` is bold — but a single `*` is not:
  `a*"b"*` stays as written.
- Footnotes render where their definitions are written, numbered in the
  order they are first referenced, as on GitHub. A definition nothing refers
  to is not shown.

Fenced code is highlighted automatically when it carries a language tag:

````markdown
```dart
final greeting = 'Hello';
```
````

Unknown or omitted languages remain readable as plain code. See
[code-block customization](customization.md#syntax-highlighting).

---

## Handling taps

Links do nothing on their own. The package does not depend on a URL launcher,
so opening one is your decision.

```dart
GptMarkdown(
  reply,
  onLinkTap: (url, title) => launchUrlString(url),
)
```

> [!TIP]
> LLM output can contain any URL. Validate before launching:

```dart
onLinkTap: (url, title) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (uri.scheme != 'https' && uri.scheme != 'mailto') return;
  launchUrl(uri);
},
```

The other callbacks follow the same shape:

```dart
GptMarkdown(
  reply,
  onImageTap: (url) => openLightbox(url),
  onCodeCopy: (code) => analytics.log('code_copied'),
  onSourceTagTap: (content) => showSource(content),
)
```

---

## Text style

The surrounding style comes from `style`; inline code size and list marker size
derive from it. Heading sizes do not: each level takes its style from
`GptMarkdownThemeData`'s `h1` to `h6`, which default to the Material text theme.

```dart
GptMarkdown(
  reply,
  style: Theme.of(context).textTheme.bodyMedium,
)
```

```dart
GptMarkdown(
  reply,
  style: const TextStyle(fontSize: 16, height: 1.5),  // roomier line spacing
)
```

> [!TIP]
> Set the body size **once**, here. Inline code and list bullets are sized as
> factors of it rather than in absolute units, so they follow it.

To restyle a component, see [customization](customization.md).

---

## LaTeX

Maths renders with no configuration.
[`val_latex_flutter`](https://pub.dev/packages/val_latex_flutter) is a
dependency of the package, and the built-in renderer uses it — falling back to
the raw TeX as text when a formula will not parse. A formula that is still
streaming in (`\frac{a`) renders what exists so far instead of failing.

**Tapping a formula.** `onLatexTap` is called with the formula and the part of
it under the finger:

```dart
GptMarkdown(
  reply,
  onLatexTap: (tap) => showFormula(context, tap.source, part: tap.tappedTex),
)
```

**Your own renderer.** `inlineLatexBuilder` builds an inline formula
(`\( … \)`) as a span, and `blockLatexBuilder` builds a block formula
(`\[ … \]`) as a widget. Each is handed one details object: the formula
(`tex`, after `latexWorkaround`; `source`, as written), the resolved `style`,
an `onTap` already bound to `onLatexTap`, and the stock formula
(`defaultSpan()` / `defaultWidget()`) to keep or wrap.

```dart
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math, MathSpan;

GptMarkdown(
  reply,
  // A span: sits on the baseline and joins text selection.
  inlineLatexBuilder: (latex) => MathSpan(
    latex.tex,
    style: latex.style,
    onTap: (tap) => explain(tap.tex),
  ),
  // The stock formula, with a tooltip.
  blockLatexBuilder: (latex) =>
      Tooltip(message: latex.source, child: latex.defaultWidget()),
)
```

`latexBuilder`, the single widget builder both replace, is deprecated and
still works where neither is set.

> [!WARNING]
> The built-in renderer does not wrap. A wide block formula overflows on a
> phone.

A display formula can wrap to the width, and scroll what cannot break:

```dart
blockLatexBuilder: (latex) => Math.tex(
  latex.tex,
  displayMode: true,
  textStyle: latex.style,
  onError: (context, result) => Text(latex.tex, style: latex.style),
),
```

Wrapping needs the available width, so a wrapping formula has no intrinsic
size: inside `IntrinsicWidth` — a common way to shrink-wrap a chat bubble — it
throws. That is why the built-in renderer does not wrap.

Or let the package do it:

```dart
styleSheet: const GptMarkdownStyleSheet(
  latex: LatexStyle(scrollBlockHorizontally: true),
),
```

**Dollar-sign maths.** If your model emits `$…$` and `$$…$$`:

```dart
GptMarkdown(reply, useDollarSignsForLatex: true)
```

> [!NOTE]
> Two prices on one line (`$5 and $10`) stay text, but a single price before
> a formula pairs with it: in `costs $5, so $x^2$`, `5, so ` becomes maths.
> Escape the price (`\$5`), or use `\(…\)` for the formula.

---

## Right to left

```dart
GptMarkdown(reply, textDirection: TextDirection.rtl)
```

`textDirection` defaults to `TextDirection.ltr` and nothing reads the ambient
`Directionality`, so an RTL app passes it here. It governs block layout as well
as text — the document is wrapped in a `Directionality`, so lists, headings and
quotes take their leading edge from it even inside a page running the other
way. Fenced code keeps its LTR reading order and scroll origin.

Inline widgets — maths, images, links — are placed in the correct visual order
in mixed-direction paragraphs, which the framework does not do on its own
([flutter#54400](https://github.com/flutter/flutter/issues/54400)).

---

## Selection

Wrap it, the way you would any text:

```dart
SelectionArea(child: GptMarkdown(reply))
```

> [!NOTE]
> Copying across a block boundary currently yields the text run together, with
> no separators. Every block — a paragraph, a list item, a table cell — is its
> own text widget, and the framework concatenates what it selected from each
> with nothing in between. Text inside one block copies as it reads.

---

## Common mistakes

> [!WARNING]
> **Rebuilding with a new builder closure on every frame.** Builders are not
> compared when deciding whether to re-render, so a changed closure is ignored
> until the widget remounts. Define them once, outside `build`, or key the
> widget.

> [!WARNING]
> **Wrapping in `Expanded` without a scroll view.** The widget reports its
> content height; constraining it without scrolling clips the reply.

> [!TIP]
> **Rendering a reply while it generates?** Rebuild only the active message
> with the complete text received so far. The renderer caches the segments that
> have settled, so append cost stays roughly flat as the reply grows. See
> [streaming and performance](streaming.md#performance).

---

## Next

* Make it look like your app → [customization](customization.md)
* Render a reply as it generates → [streaming](streaming.md)
* `@mention`, `#channel`, autolinks → [inline syntax](inline-syntax.md)
* Look up every constructor option → [`GptMarkdown` options](api-options.md)
