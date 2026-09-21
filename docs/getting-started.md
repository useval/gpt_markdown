# Getting started

## Install

```yaml
dependencies:
  gpt_markdown: ^1.3.0
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
| Headings | `#` to `######` |
| Emphasis | `**bold**`, `*italic*`, `~~strike~~`, `<u>underline</u>` |
| Code | `` `inline` ``, language-tagged highlighted fences |
| Lists | `-`, `1.`, nested |
| Tasks | `- [x]`, `- [ ]` |
| Options | `(x)`, `( )` |
| Tables | with `:---:` alignment |
| Quotes | `>` |
| Rules | `---` |
| Links | `[label](url)`, and bare URLs |
| Images | `![alt](url)` |
| Maths | `\( inline \)`, `\[ block \]` |
| Citations | `[1]` |

Bare URLs, `www.` hosts and email addresses are linked automatically — see
[inline syntax](inline-syntax.md).

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
[`flutter_math_fork`](https://pub.dev/packages/flutter_math_fork) is a
dependency of the package, and the built-in renderer uses it — falling back to
the raw TeX as text when a formula will not parse.

`latexBuilder` replaces that renderer when you want a different engine, a
different fallback, or a wrapper around the same one. The `inline` flag
separates `\( … \)` from `\[ … \]`.

```dart
GptMarkdown(
  reply,
  latexBuilder: (context, tex, style, inline) => Math.tex(
    tex,
    textStyle: style,
    onErrorFallback: (err) => Text(tex, style: style),
  ),
)
```

> [!WARNING]
> Rendered maths cannot wrap. A wide block formula overflows on a phone.

Either give it somewhere to go:

```dart
latexBuilder: (context, tex, style, inline) {
  final math = Math.tex(tex, textStyle: style,
      onErrorFallback: (err) => Text(tex, style: style));
  if (inline) return math;
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: math,
  );
},
```

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
> Leave that off if your content contains prices. `$5 and $10` would be read as
> maths.

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
