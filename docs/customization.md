# Customization

Two ways to change what you see, and they never overlap:

| | Use it for | Example |
|---|---|---|
| **Style object** | Appearance — colours, sizes, padding, fonts | `BlockQuoteStyle(barWidth: 4)` |
| **Builder** | Structure — replace the widget entirely | `blockQuoteBuilder: …` |

Every component supports both.

> [!TIP]
> If you are reaching for a builder to change a colour, stop — there is a style
> field for it. Builders lose the default structure, and with it every future
> improvement to that component.

---

## Where a style goes

The same object is accepted in two places.

**One widget:**

```dart
GptMarkdown(
  text,
  styleSheet: const GptMarkdownStyleSheet(
    blockQuote: BlockQuoteStyle(barWidth: 4),
  ),
)
```

**The whole app:**

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [
      GptMarkdownThemeData(
        brightness: Brightness.light,
        styleSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barColor: Colors.indigo),
          codeBlock: CodeBlockStyle(borderRadius: Radius.circular(12)),
        ),
      ),
      // Dark needs its own — the extension is per ThemeData.
    ],
  ),
)
```

### The merge is per field

With both of the above in force, the quote gets `barWidth: 4` from the widget
**and** `barColor: Colors.indigo` from the theme.

```
widget field  →  theme field  →  package default
```

Overriding one value never discards the rest.

> [!NOTE]
> Every field is optional, and anything left unset resolves to the value the
> package used before it was configurable. **Adding a style sheet never changes
> how existing content looks.** A golden suite covering eight constructs in
> light and dark enforces that on every commit.

---

## HeadingStyle

`textStyle` · `padding` · `showDivider` · `dividerColor` · `dividerThickness` ·
`dividerPadding`

```dart
GptMarkdown(
  text,
  styleSheet: const GptMarkdownStyleSheet(
    heading: HeadingStyle(
      textStyle: TextStyle(letterSpacing: -0.5),
      padding: EdgeInsets.only(top: 8, bottom: 4),
      showDivider: false,
    ),
  ),
)
```

`textStyle` is merged **over** the per-level style, so you change one property
without restating the size. Per-level sizes still come from the theme:

```dart
GptMarkdownThemeData(
  brightness: Brightness.light,
  h1: Theme.of(context).textTheme.headlineMedium,
  h2: Theme.of(context).textTheme.titleLarge,
)
```

`showDivider: false` removes the rule an `h1` draws by default. Leave it null
to keep following `autoAddDividerLineAfterH1`.

**Restructure with a builder** — for example, anchors on every heading:

```dart
GptMarkdown(
  text,
  headingBuilder: (context, level, content, style) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Flexible(child: content),
      IconButton(icon: const Icon(Icons.link), onPressed: () {}),
    ],
  ),
)
```

`level` is 1–6, so one builder handles all six.

---

## LinkStyle

`color` · `hoverColor` · `decoration` · `decorationThickness` · `fontWeight`

```dart
styleSheet: const GptMarkdownStyleSheet(
  link: LinkStyle(
    color: Color(0xFF0B57D0),
    hoverColor: Color(0xFF0842A0),
    decoration: TextDecoration.none,
    fontWeight: FontWeight.w500,
  ),
),
```

> [!IMPORTANT]
> Links do nothing on tap unless you handle them. The package deliberately does
> not depend on a URL launcher.

```dart
GptMarkdown(text, onLinkTap: (url, title) => launchUrlString(url))
```

`title` is the label text, which is useful for confirmation dialogs:

```dart
onLinkTap: (url, title) async {
  final ok = await confirm('Open "$title"?\n$url');
  if (ok) await launchUrlString(url);
},
```

---

## InlineCodeStyle

`fontFamily` · `fontFamilyPackage` · `fontFamilyFallback` · `fontSizeFactor` ·
`fontWeight` · `color` · `backgroundColor` · `borderColor` · `borderWidth` ·
`borderRadius` · `padding` · `boxHeightStyle`

**Your app's mono font:**

```dart
styleSheet: const GptMarkdownStyleSheet(
  inlineCode: InlineCodeStyle(fontFamily: 'GeistMono'),
),
```

**A GitHub-ish chip:**

```dart
inlineCode: InlineCodeStyle(
  backgroundColor: const Color(0x14656D76),
  borderColor: Colors.transparent,
  borderRadius: const Radius.circular(6),
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
),
```

**No chip at all, just monospace:**

```dart
inlineCode: InlineCodeStyle(
  backgroundColor: Colors.transparent,
  borderWidth: 0,
  padding: EdgeInsets.zero,
),
```

> [!TIP]
> `fontSizeFactor` is a factor, not a size, so inline code scales with whatever
> it sits in — a heading, a table cell, body text. Setting an absolute size
> breaks that.

Inline code is a real `TextSpan` with the chip painted underneath, once per
line fragment. It wraps across lines, stays selectable, sits on the baseline,
and works inside a link label — none of which a widget-based chip can do.

**Per-code styling** needs the builder:

```dart
GptMarkdown(
  text,
  inlineCodeBuilder: (context, code, style, codeStyle) => CodeTextSpan(
    text: code,
    style: style,
    codeStyle: codeStyle.copyWith(
      backgroundColor: code.startsWith('TODO') ? Colors.amber : null,
    ),
  ),
)
```

Returning `CodeTextSpan` keeps the painted chip. Return a plain `TextSpan` to
drop it.

---

## ListStyle

`bulletSize` · `bulletColor` · `bulletShape` · `markerTextStyle` · `indent` ·
`gapAfterMarker`

```dart
styleSheet: const GptMarkdownStyleSheet(
  list: ListStyle(
    bulletSize: 5,
    bulletColor: Colors.indigo,
    bulletShape: BoxShape.rectangle,
    indent: 12,
    gapAfterMarker: 12,
    markerTextStyle: TextStyle(fontWeight: FontWeight.w600),
  ),
),
```

`markerTextStyle` is the `1.` on an ordered list. `bulletSize` and
`bulletColor` default to values derived from the surrounding text, so they
track your font size unless you pin them.

> [!NOTE]
> Bullets and numbers keep separate spacing defaults — 7/10 for bullets, 6/6
> for numbers. Setting `indent` or `gapAfterMarker` applies to both.

---

## CheckboxStyle

`size` · `checkedColor` · `uncheckedColor` · `checkColor` · `borderRadius` ·
`gapAfterBox` · `interactive`

Applies to both `- [x]` task lists and `(x)` radio options.

```dart
styleSheet: const GptMarkdownStyleSheet(
  checkbox: CheckboxStyle(
    size: 18,
    checkedColor: Colors.green,
    borderRadius: Radius.circular(4),
    gapAfterBox: 8,
  ),
),
```

> [!WARNING]
> Checkboxes are **read-only by default**. A Markdown checkbox renders the
> source text — ticking it does not change the text, so the change would be
> lost on the next rebuild.

To make them interactive you must opt in *and* persist the result yourself:

```dart
GptMarkdown(
  markdown,
  styleSheet: const GptMarkdownStyleSheet(
    checkbox: CheckboxStyle(interactive: true),
  ),
  onCheckboxChanged: (value) {
    // Rewrite the source, or the tick reverts on the next build.
    setState(() => markdown = toggleFirstUnchecked(markdown));
  },
)
```

---

## BlockQuoteStyle

`barWidth` · `barColor` · `barRadius` · `backgroundColor` · `padding` ·
`margin` · `textStyle`

```dart
styleSheet: const GptMarkdownStyleSheet(
  blockQuote: BlockQuoteStyle(
    barWidth: 4,
    barColor: Color(0xFF6366F1),
    barRadius: Radius.circular(2),
    backgroundColor: Color(0x0A6366F1),
    padding: EdgeInsetsDirectional.only(start: 12, top: 8, bottom: 8),
    margin: EdgeInsets.symmetric(vertical: 8),
    textStyle: TextStyle(fontStyle: FontStyle.italic),
  ),
),
```

A background is only drawn when you ask for one — no extra widget in the tree
otherwise.

**A callout style with a builder:**

```dart
GptMarkdown(
  text,
  blockQuoteBuilder: (context, content, style) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(padding: const EdgeInsets.all(12), child: content),
  ),
)
```

---

## CodeBlockStyle

`backgroundColor` · `borderColor` · `borderWidth` · `borderRadius` · `padding` ·
`headerPadding` · `fontFamily` · `fontFamilyPackage` · `fontSize` ·
`textColor` · `showLanguageLabel` · `languageStyle` · `showCopyButton` ·
`copyLabel` · `copiedLabel` · `highlightWhileStreaming`

```dart
styleSheet: const GptMarkdownStyleSheet(
  codeBlock: CodeBlockStyle(
    backgroundColor: Color(0xFF1E1E1E),
    textColor: Color(0xFFD4D4D4),
    borderRadius: Radius.circular(12),
    padding: EdgeInsets.all(20),
    fontFamily: 'GeistMono',
    showLanguageLabel: true,
    showCopyButton: true,
  ),
),
```

**Localise the copy-button tooltip** without replacing the block:

```dart
codeBlock: CodeBlockStyle(
  copyLabel: AppLocalizations.of(context).copyCode,
  copiedLabel: AppLocalizations.of(context).copied,
),
```

**React to a copy:**

```dart
GptMarkdown(text, onCodeCopy: (code) => analytics.log('code_copied'))
```

### Syntax highlighting

Fenced blocks are highlighted automatically when the opening fence names a
recognized language:

````markdown
```python
def greet(name: str) -> str:
    return f"Hello, {name}!"
```
````

The built-in highlighter registers 189 language grammars and follows the
active light or dark brightness. Common fence aliases include `js`, `ts`,
`py`, `python3`, `c++`, `sh` and `yml`. Unknown tags fall back to plain
monospace code, and an omitted tag displays `Code` in the header.

While a fence is still open the block is highlighted again on every source
update. `highlightWhileStreaming: false` holds plain monospace until the closing
fence arrives and highlights once, which is worth setting when replies stream
long blocks. It defaults to true because that is what the package did before the
field existed.

No syntax-theme field is exposed. `CodeBlockStyle` controls the panel, font and
base/fallback text appearance; the built-in token palette is automatic. When
an application needs its own tokenizer or token colors, replace the complete
block with the existing `codeBuilder`.

The built-in copy action keeps the code unchanged, briefly changes its icon to
a check, ignores repeated taps during that state, and invokes `onCodeCopy`
after the clipboard write succeeds.

> [!WARNING]
> Code lines do not wrap. On a phone at a raised text scale a long line
> overflows horizontally. The block scrolls sideways, but if you need it to
> wrap, replace it:

```dart
GptMarkdown(
  text,
  codeBuilder: (context, name, code, closed) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace')),
  ),
)
```

`closed` is false while a fence is still being streamed — useful for showing a
"generating" state.

---

## TableStyle

`borderColor` · `borderWidth` · `borderRadius` · `cellPadding` ·
`headerBackground` · `headerTextStyle` · `rowStripeColor` · `columnWidth`

```dart
styleSheet: const GptMarkdownStyleSheet(
  table: TableStyle(
    borderColor: Color(0x1F000000),
    borderWidth: 1,
    borderRadius: Radius.circular(8),
    cellPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    headerBackground: Color(0x0A000000),
    headerTextStyle: TextStyle(fontWeight: FontWeight.w600),
  ),
),
```

`columnWidth` sets one width policy for every column. Left unset, a column is
sized to its content, which lays every cell out twice — once to measure, once
for real. `columnWidth: FixedColumnWidth(120)` skips that measurement, which is
the escape hatch for a large or streaming table.

A flex policy is not. Tables already scroll horizontally when they exceed the
available width, so the table is laid out against an unbounded width and a flex
column has no finite width to take a share of: `FlexColumnWidth()` collapses
the table to zero width and wraps every cell to one character a line.
[comparison](comparison.md) has the measurements.

---

## ImageStyle

`borderRadius` · `padding` · `fit` · `maxWidth` · `maxHeight`

```dart
styleSheet: const GptMarkdownStyleSheet(
  image: ImageStyle(
    borderRadius: Radius.circular(8),
    padding: EdgeInsets.symmetric(vertical: 8),
    maxHeight: 320,
  ),
),
```

**Cached network images**, with a placeholder and error state:

```dart
GptMarkdown(
  text,
  imageBuilder: (context, url, width, height) => CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    placeholder: (context, _) => const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    ),
    errorWidget: (context, _, __) => const Icon(Icons.broken_image),
  ),
  onImageTap: (url) => openLightbox(url),
)
```

`width` and `height` come from the alt text when written as `WxH`.

---

## HrStyle

`thickness` · `color` · `padding`

```dart
styleSheet: const GptMarkdownStyleSheet(
  hr: HrStyle(
    thickness: 2,
    color: Color(0x1F000000),
    padding: EdgeInsets.symmetric(vertical: 16),
  ),
),
```

**A dotted rule:**

```dart
GptMarkdown(
  text,
  hrBuilder: (context, style) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: DottedLine(),
  ),
)
```

---

## SourceTagStyle

`backgroundColor` · `textStyle` · `size` · `shape` · `padding`

The chip drawn for a `[1]` citation, common in RAG answers.

```dart
styleSheet: const GptMarkdownStyleSheet(
  sourceTag: SourceTagStyle(
    size: 18,
    backgroundColor: Color(0xFFE8DEF8),
    shape: BoxShape.rectangle,
    textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  ),
),

GptMarkdown(text, onSourceTagTap: (content) => showSource(content))
```

---

## LatexStyle

`textStyle` · `padding` · `backgroundColor` · `borderRadius` ·
`scrollBlockHorizontally`

```dart
styleSheet: const GptMarkdownStyleSheet(
  latex: LatexStyle(
    scrollBlockHorizontally: true,
    padding: EdgeInsets.symmetric(vertical: 8),
    backgroundColor: Color(0x08000000),
    borderRadius: Radius.circular(6),
  ),
),
```

> [!WARNING]
> Rendered maths cannot wrap. Without `scrollBlockHorizontally: true`, a wide
> formula overflows on a phone. This is the single most common LaTeX
> complaint.

The renderer itself is built in. `latexBuilder` replaces it — see
[getting started](getting-started.md#latex).

---

## Builders

Where a builder is handed a style-sheet object, it is the **fully resolved**
one, so the builder never has to guess a default or restate a theme colour.
Check the signature first, though: `codeBuilder`, `imageBuilder`,
`tableBuilder`, `orderedListBuilder` and `unOrderedListBuilder` are handed no
style-sheet object — they replace the component outright, and `CodeBlockStyle`,
`ImageStyle`, `TableStyle` and `ListStyle` never reach them. The `TextStyle`
`tableBuilder` does receive is the ambient body style, empty when the widget
sets none.

The three deprecated builders carry an unresolved style as well, kept that way
because the builders written against them expect it: `sourceTagBuilder` is
handed an empty `TextStyle` whenever `SourceTagStyle.textStyle` is unset,
`linkBuilder` the ambient body style rather than the resolved link style its
replacement is given, and `highlightBuilder` the ambient body style — the
resolved code style reaches it only where the surrounding style is null.

| Builder | Signature |
|---|---|
| `headingBuilder` | `(context, int level, Widget content, HeadingStyle style)` |
| `blockQuoteBuilder` | `(context, Widget content, BlockQuoteStyle style)` |
| `checkboxBuilder` | `(context, bool checked, Widget content, CheckboxStyle style)` |
| `radioOptionBuilder` | `(context, bool selected, Widget content, CheckboxStyle style)` |
| `hrBuilder` | `(context, HrStyle style)` |
| `codeBuilder` | `(context, String name, String code, bool closed)` |
| `tableBuilder` | `(context, rows, TextStyle style, GptMarkdownConfig config)` |
| `imageBuilder` | `(context, String url, double? width, double? height)` |
| `latexBuilder` | `(context, String tex, TextStyle style, bool inline)` |
| `inlineLinkBuilder` | `(LinkBuildDetails details)` → `InlineSpan` |
| `linkBuilder` | *Deprecated.* `(context, InlineSpan label, String url, TextStyle style)` |
| `inlineCodeBuilder` | `(context, String code, TextStyle style, InlineCodeStyle codeStyle)` |
| `highlightBuilder` | *Deprecated.* `(context, String text, TextStyle style)` |
| `inlineSourceTagBuilder` | `(SourceTagBuildDetails details)` → `InlineSpan` |
| `sourceTagBuilder` | *Deprecated.* `(context, String content, TextStyle style)` |
| `orderedListBuilder` | `(context, String no, Widget child, GptMarkdownConfig config)` |
| `unOrderedListBuilder` | `(context, Widget child, GptMarkdownConfig config)` |

Reuse the style you are given rather than hard-coding:

```dart
blockQuoteBuilder: (context, content, style) => DecoratedBox(
  decoration: BoxDecoration(
    border: BorderDirectional(
      start: BorderSide(
        // Follows the theme, because the resolved style is passed in.
        color: style.barColor ?? Colors.grey,
        width: style.barWidth ?? 3,
      ),
    ),
  ),
  child: content,
),
```

### The inline builders return a span, not a widget

`inlineCodeBuilder`, `inlineLinkBuilder` and `inlineSourceTagBuilder` all
return an `InlineSpan`. Deliberate. A `Widget` has to be wrapped in a
`WidgetSpan`, which cannot wrap across lines, is skipped by text selection,
sits off the baseline, and is one opaque character to the streaming reveal.

Migrating a `linkBuilder`, term by term:

| old positional argument | new |
|---|---|
| `context` | `details.context` |
| `label` (one span) | `details.labelSpans` — already parsed, already styled |
| `url` | `details.url` |
| `style` | `details.style` — now the *resolved* link style |
| — | `details.linkStyle`, the resolved `LinkStyle` |
| — | `details.isAutolink` |
| — | `details.onTap`, which calls `onLinkTap` for you |
| — | `details.hoverStyle` |
| — | `details.config` |

Because a builder receives one details object rather than positional
arguments, a later release adds a field here instead of a parameter — so
nothing you write today stops compiling.

```dart
// keep the stock link, change one thing
inlineLinkBuilder: (link) =>
    link.defaultSpan(style: link.style.copyWith(fontWeight: FontWeight.bold)),
```

> A `GestureRecognizer` fires only on a `TextSpan` that carries its own `text`,
> never on one that only has `children`. A parsed link label is the second
> kind, so `TextSpan(children: link.labelSpans, recognizer: tap)` renders
> correctly and is silently never tapped. Return `link.defaultSpan()`, a
> `TappableTextSpan`, or `link.asWidgetSpan()`. A debug assert catches it.

If you genuinely need a widget:

```dart
inlineCodeBuilder: (context, code, style, codeStyle) =>
    baselineWidgetSpan(MyChip(code: code, style: style)),

inlineLinkBuilder: (link) => link.asWidgetSpan(MyLinkChip(url: link.url)),
inlineSourceTagBuilder: (tag) => tag.asWidgetSpan(MyChip(tag.id)),
```

`baselineWidgetSpan` aligns it on the text baseline and handles text-scale
compensation. A bare `WidgetSpan` does neither.

---

## Beyond styles and builders

A style changes appearance and a builder replaces a widget. Neither teaches the
parser a syntax it does not already know, which is what an extension is for:

| What you are adding | Use |
|---|---|
| A block syntax such as `:::warning` | `blockComponents` |
| An inline token such as `@name` | `inlinePatterns` |
| A payload that must not be parsed at all | `inlineDirectives` |

> [!WARNING]
> The older extension arguments, `components` and `inlineComponents`, are
> deprecated in 1.3.0 and scheduled for removal in 2.0.0. They still work, but
> passing either — even an empty list — switches the widget to the legacy regex
> parser, which ignores `blockComponents` and loses the incremental segment
> cache, the span-level streaming reveal and lazy sliver rendering.
> `incremental: false` does the same.

Nothing else on this page is affected by that choice: the style objects and
builders above are honoured on both parsers.

[Custom components](custom-components.md) has the detail, and
[migration](../MIGRATION.md) the before and after.

---

## Callbacks

```dart
GptMarkdown(
  text,
  onLinkTap: (url, title) => launchUrlString(url),
  onImageTap: (url) => openLightbox(url),
  onCodeCopy: (code) => analytics.log('code_copied'),
  onSourceTagTap: (content) => showSource(content),
  onCheckboxChanged: (value) => persist(value),  // needs interactive: true
)
```

---

## Theme animation

Every style class implements `lerp`, so a theme transition animates rather than
snapping — colours, widths, radii and padding all interpolate. Nothing to
configure; it follows `ThemeData` like any other extension.

---

## Common mistakes

> [!WARNING]
> **Changing a builder at runtime does nothing.**
> `GptMarkdownConfig.isSame` decides whether spans are regenerated, and it
> cannot compare closures — any consumer writing them inline creates a new one
> every build, so comparing them would defeat the cache entirely.
>
> Give the widget a `key` that changes with the builder, or set it once.
> Styles, `inlinePatterns`, `blockComponents` and the deprecated component
> lists *are* compared and do update live.

> [!WARNING]
> **A raw `WidgetSpan` scales twice.**
> A paragraph lays inline children out in scaled space and multiplies their
> reported size back. A child that also scales its own text reserves far more
> room than it needs at a raised system font setting.
>
> Use `baselineWidgetSpan`, or wrap the child in
> `MediaQuery.withNoTextScaling`.

> [!NOTE]
> **Dark mode needs its own extension.** `GptMarkdownThemeData` lives on
> `ThemeData`, so `theme:` and `darkTheme:` each need one — with
> `brightness:` set to match, or the derived defaults will be wrong.
