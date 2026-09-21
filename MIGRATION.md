# Migration guide

## 1.2.x → 1.3.0

Nothing is removed in 1.3.0. Every deprecated argument, class and builder below
still compiles and still works; removal is planned for 2.0.0. The rendering
changes listed below reach both parsers, so staying on a deprecated API does
not hold them off — what it costs is the incremental pipeline, which is why
the arguments are deprecated at all.

Nothing here stops 1.2.x code compiling. The plusparse AST — `MdNode`,
`MdCustomBlock` and everything under `lib/plusparse/` — is new in 1.3.0, so
there is no 1.2.x code walking it to break. It is worth knowing for later that
`MdNode` is sealed: once you do switch over it, a release that adds a node kind
makes an exhaustive `switch` with no `default` clause fail to build.

Three changes have no compiler warning at all:

* Links render as text rather than as a widget. Read §1 — it is an improvement
  in every case I know of, but it moves goldens and it changes what
  `toPlainText` returns.
* Block layout follows the configured text direction, so lists, headings and
  quotes align to the leading edge of a right-to-left document rather than the
  left one.
* Paragraph and widget text scaling is resolved at a single boundary, so
  content that scaled twice at raised system font settings no longer does, and
  standalone tables, checkbox rows and code blocks scale again.

---

## What is deprecated in 1.3.0

plusparse is the parser `GptMarkdown` uses, and the regex parser reached through
`components` and `inlineComponents` is deprecated as a whole — its extension
points, its registration lists, its renderer and its built-in components. The
tables below are the complete set. Three entries need more than a rename; the
recipes after the tables cover those.

### Widget arguments

| Symbol | Use instead | Note |
| --- | --- | --- |
| `GptMarkdown.incremental` | Delete the argument | plusparse is the default; the default value is `true` and stays `true` |
| `GptMarkdown.components` | `blockComponents` | Inline syntax in the same list moves to `inlinePatterns` or `inlineDirectives` |
| `GptMarkdown.inlineComponents` | `inlinePatterns`, or `inlineDirectives` for a delimited payload | Both work on either pipeline |

Passing `components` or `inlineComponents` — even an empty list — switches the
whole widget to the legacy regex parser, which ignores `blockComponents` and has
no incremental segment cache, no span-level streaming reveal and no lazy sliver
rendering. `incremental: false` does the same. Nothing warns about the rendering
change; the deprecation warning on the argument is the only signal.

### Extension points and registration

| Symbol | Use instead | Note |
| --- | --- | --- |
| `InlineMd` | `InlinePattern`, or `InlineDirective` | `InlineDirective` for a region the parser must not look inside |
| `BlockMd` | `MarkdownBlockComponent` with a `MarkdownBlockSyntax` | `FencedBlockSyntax` covers `:::name` containers |
| `MarkdownComponent.globalComponents` | `blockComponents` | The list exists to be spread into `components`, and passing `components` is what selects the legacy parser |
| `MarkdownComponent.inlineComponents` | `inlinePatterns` | Spreading it into `inlineComponents` selects the legacy parser the same way |

`MarkdownComponent` itself, `MarkdownComponent.generate`, `MarkdownScope` and
`AutolinkMd` are not deprecated — the modern pipeline uses all of them.

### The legacy widget

| Symbol | Use instead | Note |
| --- | --- | --- |
| `MdWidget` | `GptMarkdown` | It is still what the legacy path builds internally, so it keeps working; building it directly gives up the segment cache, the span-level reveal and lazy sliver rendering |

### Built-in components of the regex parser

Internals of the regex pipeline, deprecated with no replacement: the modern
parser handles each construct itself, and no caller should name these types.
They are listed so a warning naming one is not a mystery.

| Symbol | Use instead | Construct it handled |
| --- | --- | --- |
| `InlineDirectiveMd` | None | The masked sentinel of an `InlineDirective`, which the modern pipeline unmasks itself |
| `IndentMd` | None | Indented content |
| `HTag` | None | Headings |
| `NewLines` | None | Blank-line block separation |
| `HrLine` | None | Horizontal rules |
| `CheckBoxMd` | None | Task list items |
| `RadioButtonMd` | None | Radio options |
| `BlockQuote` | None | Block quotes |
| `UnOrderedList` | None | Unordered lists |
| `OrderedList` | None | Ordered lists |
| `HighlightedText` | None | Inline code |
| `BoldMd` | None | Bold text |
| `StrikeMd` | None | Strikethrough |
| `ItalicMd` | None | Italic text |
| `LatexMathMultiLine` | None | Display maths |
| `LatexMath` | None | Inline maths |
| `SourceTag` | None | `[1]` citation chips |
| `ATagMd` | None | Links |
| `ImageMd` | None | Images |
| `TableMd` | None | Tables |
| `CodeBlockMd` | None | Fenced code |
| `UnderLineMd` | None | `<u>` spans |

### Builders

| Symbol | Use instead | Note |
| --- | --- | --- |
| `linkBuilder` | `inlineLinkBuilder` | §2 |
| `sourceTagBuilder` | `inlineSourceTagBuilder` | §3 |
| `highlightBuilder` | `inlineCodeBuilder` | Deprecated in 1.2.0; see that section |
| `LinkButton` | `inlineLinkBuilder`, or `LinkTextSpan` directly | A widget, so it needs a `WidgetSpan`: off the baseline, cannot wrap, skipped by selection. Nothing in the package builds one now |
| `LinkSpanBuilder` | — | Only `LinkButton` used it |

The matching typedefs — `LinkBuilder`, `SourceTagBuilder` and `HighlightBuilder`
— are deprecated with them, so a field or variable declared with one warns too.

---

## Migration recipes

### Delete `incremental`

The argument selected the plusparse pipeline, and that pipeline is the one
`GptMarkdown` uses by default, so `incremental: true` asks for what you already
have.

```dart
// before
GptMarkdown(text, incremental: true)

// after
GptMarkdown(text)
```

`incremental: false` is the one worth searching for: it drops to the legacy
parser, so each text change re-parses and re-lays-out the whole message rather
than its tail segment, and `blockComponents` stops being read. It is ignored
when `components` or `inlineComponents` are given, since those select the legacy
parser on their own, and an animating `animation` overrides it, since the
span-level reveal exists only on the plusparse path.

### `components` → `blockComponents`

A custom `components` list replaces the built-ins wholesale — every component
left out of it stops rendering — which is why callers spread
`MarkdownComponent.globalComponents` into their own list. The spread is only
half the cost: naming `components` at all pins the whole document to the
legacy parser.

`blockComponents` separates the two halves a `BlockMd` conflated. The syntax is
pure Dart, takes lines and returns an immutable payload, and runs inside the
incremental parse; the renderer is an ordinary widget builder that reads the
payload. Splitting them is what lets the parse be cached across theme changes
and the block be rendered lazily inside `SliverGptMarkdown`.

```dart
// before
class CalloutMd extends BlockMd {
  @override
  String get expString => r':::callout\n([\s\S]*?)\n:::';

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) =>
      CalloutBox(body: exp.firstMatch(text)?[1] ?? '');
}

GptMarkdown(
  text,
  components: [CalloutMd(), ...MarkdownComponent.globalComponents],
)
```

```dart
// after — the built-ins stay registered, so nothing has to be spread back in
GptMarkdown(
  text,
  blockComponents: [
    MarkdownBlockComponent(
      syntax: const FencedBlockSyntax(
        type: 'callout',
        opening: ':::callout',
      ),
      builder: (context, node, config) => CalloutBox(body: node.body),
    ),
  ],
)
```

`FencedBlockSyntax` closes on `:::` unless you pass `closing`, and its `body` is
raw text including blank lines. A block whose closer has not arrived yet reaches
your builder with `MdCustomBlock.closed` false — the case a streaming reply
hits on every chunk.

For syntax that is not a fence, implement `MarkdownBlockSyntax`: a `type`, a
`prefix` that lines are dispatched on, and `parse(lines, startLine)` returning a
`MarkdownBlockMatch`. The parse has to be pure and may inspect only the lines it
consumes, because blocks are cached independently of one another.

Keep the component instances stable — a field on your `State`, or a `const`
list. Rebuilding the list on every frame invalidates parsing and rendering.

### `InlineMd` and `BlockMd` → `InlinePattern` and `MarkdownBlockComponent`

`InlineMd` asked you to supply a regex that is merged into the parser's own
alternation, and to build a span from the matched *text*, having lost the match
itself. `InlinePattern` keeps the `RegExpMatch` and hands you the resolved
surrounding `TextStyle`, so a builder no longer has to reach into the config to
find out what it is sitting in.

```dart
// before
class ShoutMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'!![A-Za-z]+!!');

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) => TextSpan(
    text: text.replaceAll('!!', '').toUpperCase(),
    style: config.style?.copyWith(fontWeight: FontWeight.bold),
  );
}

GptMarkdown(
  text,
  inlineComponents: [ShoutMd(), ...MarkdownComponent.inlineComponents],
)
```

```dart
// after
GptMarkdown(
  text,
  inlinePatterns: [
    InlinePattern(
      pattern: RegExp(r'!![A-Za-z]+!!'),
      builder: (context, match, style) => TextSpan(
        text: match[0]!.replaceAll('!!', '').toUpperCase(),
        style: style.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
  ],
)
```

Two differences to know about. A pattern is matched against the document as a
whole, so anchor it with lookarounds rather than `^` and `$` unless a
line-anchored match is what you want. And `scopes` defaults to
`MarkdownComponent.allScopesExceptLinkLabel` rather than every scope, because a
`WidgetSpan` nested inside a link's own placeholder does not paint on iOS; a
builder returning a `TextSpan` can opt back in with
`scopes: MarkdownComponent.allScopes`.

For prefixed tokens, `InlinePattern.prefixed` builds the regex for you and
matches known names longest-first, so `#design-review` is not shadowed by a
`#design` entry.

Where the payload is not text the parser should read — JSON, a serialised
widget — use `InlineDirective(open:, close:, builder:)` instead. The region is
lifted out before parsing and put back at render time, so nothing inside it is
interpreted or split across nodes, and an unterminated directive stays literal
text until its closer arrives.

The block half of a legacy pair moves as in the previous recipe: a `BlockMd`
becomes a `MarkdownBlockSyntax` plus a `MarkdownBlockComponent` registered on
`blockComponents`.

---

## 1. Links render as text, not as a widget

**No code change needed.** This is a rendering change, and in almost every case
an improvement you want.

A link used to be a `LinkButton` inside a `WidgetSpan`. It is a `LinkTextSpan`
now. What changes on screen:

* A long link label **wraps mid-label**. Before, the whole label moved to the
  next line because a `WidgetSpan` is atomic.
* The label is **selectable** and included in copied text. Before, selection
  skipped it entirely.
* While streaming, the label **reveals character by character** rather than
  appearing whole — a placeholder was one character to the reveal.
* The label sits on the text baseline.
* Hover is resolved once per paragraph instead of by a `StatefulWidget` per
  link.

Check for these if you depended on the old shape:

* Tests using `find.byType(LinkButton)` — count `LinkTextSpan`s in the span
  tree instead.
* Tests using `find.byType(RichText)` — `BidiRichText extends RichText` and a
  paragraph containing a link now routes through it, so use
  `find.byWidgetPredicate((w) => w is RichText)`.
* `toPlainText(includePlaceholders: false)` now **includes** link labels.
* Golden images that contain links will shift.

To keep a widget-shaped link, pass `inlineLinkBuilder` and return
`details.asWidgetSpan(yourWidget)`.

---

## 2. `linkBuilder` is deprecated

**Still works.** It is scheduled for removal in 2.0.0 and behaves exactly as
before — including the `WidgetSpan` and the `GestureDetector` wrapped around
it.

It returns a `Widget`, so the package has to wrap it in a `WidgetSpan`. The
label then sits off the text baseline, cannot wrap across lines, is skipped by
text selection, is one opaque character to the streaming reveal, and does not
paint on iOS inside a link label. Its four positional parameters are the other
half of the problem: the resolved `LinkStyle`, whether the link is an autolink,
and a link title have nowhere to go without breaking every caller.

`inlineLinkBuilder` returns an `InlineSpan` and takes a single
`LinkBuildDetails`, so later releases can add information without breaking
anything you write today.

If you only want to restyle links, you do not need a builder at all — set
`LinkStyle` on `styleSheet`.

```dart
// before
linkBuilder: (context, label, url, style) => GestureDetector(
  onTap: () => launchUrl(Uri.parse(url)),
  child: Text.rich(label),
),

// after — details.defaultSpan() keeps the tap, the hover and the styling
inlineLinkBuilder: (details) => details.defaultSpan(),
```

`details.onTap` already invokes `onLinkTap` with the right arguments, so hand
it along rather than calling `onLinkTap` yourself.

> A `GestureRecognizer` only fires on a `TextSpan` that carries its own `text`,
> never on one that only has `children`. A parsed link label is the second
> kind, so `TextSpan(children: label, recognizer: tap)` renders correctly and
> is never tapped. Return `details.defaultSpan()`, a `TappableTextSpan`, or
> `details.asWidgetSpan()` — all three are tappable. A debug assert catches the
> mistake.

---

## 3. `sourceTagBuilder` is deprecated

**Still works**, unchanged, until 2.0.0 — including the `TextStyle` it has
always been handed, which is `SourceTagStyle.textStyle` when the style sheet
sets one and an empty `TextStyle` when it does not.

Use `inlineSourceTagBuilder`. It receives the *resolved* `TextStyle` and the
resolved `SourceTagStyle`, so a chip no longer has to guess the surrounding
size and colour.

```dart
// before
sourceTagBuilder: (context, content, style) => MyChip(content),

// after — asWidgetSpan reproduces the stock padding, alignment and tap
inlineSourceTagBuilder: (tag) => tag.asWidgetSpan(MyChip(tag.id)),
```

---

## Not breaking

* Nothing is removed, nothing deprecated stops working, and nothing in this
  release stops 1.2.x code compiling.
* The default **citation chip** is unchanged.
* Both old builders are still consulted when the new one is null.
* When both are set, the new builder wins.
* `LinkButton` and `LinkSpanBuilder` still exist; nothing in the package builds
  them any more.

---

## 1.1.x → 1.2.0

Nothing here stops code compiling — `1.2.0` is a drop-in upgrade. The changes
below alter what you see without a compiler warning, so read the list even
though your build is green.

---

## 1. `highlightBuilder` is deprecated

**Still works.** It is scheduled for removal in 2.0.0, and is now wrapped on
the text baseline rather than at the old hardcoded
`PlaceholderAlignment.middle`, so existing chips sit correctly against the
surrounding text.

It returned a `Widget`, which was wrapped in a `WidgetSpan` at a hardcoded
`PlaceholderAlignment.middle`. That sat off the baseline, could not wrap across
lines, was skipped by text selection, and did not paint on iOS when it ended up
inside a link label — `` [`code`](url) `` rendered as nothing.

Most callers used it only to restyle inline code, and no longer need a builder
at all:

```dart
GptMarkdown(
  text,
  inlineCodeStyle: const InlineCodeStyle(fontFamily: 'GeistMono'),
)
```

`InlineCodeStyle` covers `fontFamily`, `fontSizeFactor`, `fontWeight`, `color`,
`backgroundColor`, `borderColor`, `borderWidth`, `borderRadius`, `padding` and
`boxHeightStyle`. Every field is optional; unset fields follow your
`ColorScheme`.

If you genuinely need a widget:

```dart
// before
highlightBuilder: (context, text, style) => MyChip(text, style),

// after — returns an InlineSpan, so it stays on the baseline
inlineCodeBuilder: (context, code, style, codeStyle) =>
    baselineWidgetSpan(MyChip(code, style)),
```

`inlineCodeBuilder` receives the resolved `InlineCodeStyle` as well, so a
builder can reuse the chip colours instead of restating them. Returning a
`CodeTextSpan` keeps the painted chip; returning any other `TextSpan` drops it.

---

## 2. Inline code looks different

Was bold text on a faint `TextStyle.background` wash. It is now a monospace
chip — the bundled JetBrains Mono, matching fenced blocks — with a tinted fill,
a hairline outline and a 4px radius, painted once per line so long inline code
wraps instead of overflowing.

Nothing to change unless you want the old look. To tone it down:

```dart
GptMarkdown(
  text,
  inlineCodeStyle: const InlineCodeStyle(
    borderWidth: 0,
    backgroundColor: Colors.transparent,
    padding: EdgeInsets.zero,
  ),
)
```

Or app-wide via `GptMarkdownThemeData(brightness: ..., inlineCode: ...)` —
`brightness` is required.

---

## 3. Autolinking is on by default

Bare URLs, `www.` hosts, email addresses and `<...>` autolinks now become
links. Bare autolinks follow the GFM autolink extension; `<...>` autolinks
follow CommonMark §6.5.

```dart
GptMarkdown(text, autolink: false)              // keep URLs as plain text
GptMarkdown(text, autolinkSchemes: {'myapp'})   // also link myapp://…
```

**If your app rewrites bare URLs into `[url](url)` before rendering, remove
that step or set `autolink: false`.** Otherwise both run.

Removing the pre-processor is the better fix: a pre-processor works on raw
Markdown and has to guess where the syntax ends and the URL begins, which is
how `**https://example.com**` becomes a link whose href ends in `**`. The
renderer sees the URL after the emphasis has already been consumed, so that
class of bug cannot happen.

---

## 4. Text scaling is proportional

At raised system font settings, anything rendered through a `WidgetSpan` used
to reserve far more space than it needed — measured at a 2x setting: a heading
17x, a list 10x, a checkbox 39x. Each is now exact.

No API change. A layout tuned around the old inflation will look tighter, and
content that previously overflowed at large font sizes should now fit.

If you build your own inline widgets, wrap them so they do not scale twice:

```dart
WidgetSpan(child: MediaQuery.withNoTextScaling(child: MyChip()))
```

`baselineWidgetSpan` and `InlinePattern` do this for you.

---

## 5. Some components no longer render inside link labels

`ImageMd`, `TableMd` and `ATagMd` now declare
`MarkdownComponent.allScopesExceptLinkLabel`, so `[![alt](img)](url)` and
nested links render differently. They used to produce a placeholder nested
inside the link's own placeholder, which does not paint on iOS.

A **custom** component still renders inside link labels unless it says
otherwise:

```dart
class MyChipMd extends InlineMd {
  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;

  // ...
}
```

If your component returns a `WidgetSpan`, you want this — it is the fix for a
chip going blank inside `[#channel](url)` on iOS.

Better still, app-specific inline syntax has a first-class API that excludes
link labels by default and needs no subclassing:

```dart
GptMarkdown(
  text,
  inlinePatterns: [
    InlinePattern.prefixed(
      prefix: '#',
      knownNames: channelNames,
      builder: (context, match, style) =>
          WidgetSpan(child: ChannelChip(match.group(0)!)),
    ),
  ],
)
```

Leaving `genericTokenPattern` null matches only the names you pass, so `#2959`
stays an issue number instead of being claimed as a channel.

---

## 6. Text that used to disappear now shows

Malformed links such as `[[a](http://x)` or `[label](http://x`, and matches no
component claims, render as plain text instead of being dropped silently. Debug
builds also print a warning.

If you were relying on malformed Markdown vanishing, it no longer does.

---

## 7. Components whose pattern contains a top-level `|`

Handler dispatch was anchored as `'^$pattern$'`, which binds `^` to the first
alternative and `$` to the last. A component whose pattern contained a
top-level `|` therefore claimed matches it did not actually cover — and, being
earlier in the list, could take them from the component that did.

It is now anchored as `'^(?:$pattern)$'`. If you have a component with
alternation, check it still matches what you expect.

---

## 8. Case-insensitive component patterns now match

The combined regex was always built case-sensitively, so a component declaring
`RegExp(..., caseSensitive: false)` never received those matches. It does now,
which may surface matches you did not previously see.

---

## 9. Tests: `find.byType(RichText)` misses package paragraphs

Paragraphs carrying inline code, or needing right-to-left placeholder
reordering, render through `BidiRichText` — a `RichText` **subclass** — and
`find.byType` matches exact runtime types.

```dart
// before
find.byType(RichText)

// after
find.byWidgetPredicate((widget) => widget is RichText)
```

---

## Not breaking

Everything in the customization work is additive:

* `GptMarkdownStyleSheet` and the twelve per-component style classes
* `blockQuoteBuilder`, `headingBuilder`, `checkboxBuilder`,
  `radioOptionBuilder`, `hrBuilder`
* `onCheckboxChanged`, `onCodeCopy`, `onImageTap`, `onSourceTagTap`
* `MarkdownScope`, `InlinePattern`, `autolink`, `autolinkSchemes`

The existing `h1`-`h6`, `linkColor`, `linkHoverColor` and `hrLine*` theme
fields keep working, and every previous builder keeps its signature. A
style-sheet value overrides them only where you set one.
