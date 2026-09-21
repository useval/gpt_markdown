# `GptMarkdown` options

A reference for the public constructor. Follow the linked guides for behavior
that needs more than a one-line description.

## Content and layout

| Option | Default | Purpose |
|---|---|---|
| `data` | required | Markdown source passed as the first positional argument |
| `style` | inherited | Base `TextStyle`; markers and inline code derive from it, heading sizes come from the theme |
| `textDirection` | `TextDirection.ltr` | Direction used by paragraphs, inline widgets and block alignment |
| `textAlign` | inherited | Paragraph alignment |
| `textScaler` | `MediaQuery` | Explicit scaler propagated to text and inline widgets |
| `maxLines` | unlimited | Maximum paragraph lines |
| `overflow` | inherited | Overflow behavior when `maxLines` is reached |

The widget sizes itself to its content and does not provide vertical scrolling.
`textDirection` wraps the whole document in a `Directionality`, so blocks and
builder subtrees follow it instead of the ambient direction: a widget dropped
into an RTL app lays its blocks out left to right until you pass the direction
in. See [getting started](getting-started.md).

## Parsing and syntax

| Option | Default | Purpose |
|---|---|---|
| `useDollarSignsForLatex` | `false` | Enables `$…$` and `$$…$$` maths parsing |
| `latexWorkaround` | none | Transforms TeX immediately before rendering |
| `autolink` | `true` | Enables bare URL, host and email autolinking |
| `autolinkSchemes` | empty set | Additional schemes accepted as bare links |
| `inlineDirectives` | none | Protects delimited host data from Markdown parsing |
| `inlinePatterns` | none | Adds consumer-defined inline tokens to both parser paths |
| `blockComponents` | none | Adds new block syntax while staying on plusparse |
| `incremental` | `true` | *Deprecated.* Delete the argument; plusparse is the default, and `false` opts back into the legacy parser |
| `components` | built-ins | *Deprecated.* Replaces the legacy block-component list; use `blockComponents` |
| `inlineComponents` | built-ins | *Deprecated.* Replaces the legacy inline-component list; use `inlinePatterns` or `inlineDirectives` |

`blockComponents` is the modern route for new block grammar: it supplements the
built-in blocks and keeps plusparse, its segment cache, the span-level
streaming reveal and lazy sliver rendering. Inline syntax goes to
`inlinePatterns`, or to `inlineDirectives` where the host has already wrapped
the region in sentinels.

`incremental`, `components` and `inlineComponents` are deprecated, with removal
slated for 2.0.0; until then they behave as they always have. All three lead to
the legacy regex parser. Passing `components` or `inlineComponents` — even an
empty list — selects it outright, and `incremental: false` selects it unless an
animating `animation` holds plusparse open, since the span-level reveal exists
only on that path. The legacy parser ignores `blockComponents`, so a registered
block syntax renders as ordinary Markdown with no warning, and it has no
incremental segment cache, so each text change re-parses and re-lays-out the
whole message rather than its tail segment. A legacy list also replaces the
built-ins rather than extending them, which is why existing code spreads the
equally deprecated `MarkdownComponent.globalComponents` or
`MarkdownComponent.inlineComponents` into its own list. See
[custom components](custom-components.md).

## Streaming and animation

| Option | Default | Purpose |
|---|---|---|
| `animation` | `GptMarkdownAnimation.none` | Character reveal effect |
| `blockAnimation` | `GptMarkdownBlockAnimation.none` | Entrance for atomic block widgets |
| `isStreaming` | `true` | Says whether more source may arrive |
| `charactersPerSecond` | `300` | Adaptive reveal baseline |
| `revealFadeSeconds` | `0.25` | Time for an arriving character to settle |
| `blockAnimationDuration` | `200 ms` | Duration of a block entrance |
| `blockAnimationCurve` | `Curves.easeOut` | Easing used by block entrances |

`isStreaming`, `charactersPerSecond` and `revealFadeSeconds` matter only when a
character reveal is active. Block animation is an independent axis.
The incremental segment cache applies with `animation: none` as well;
`incremental: false` gives it up along with the rest of plusparse. See
[streaming and incremental rendering](streaming.md).

## Appearance

| Option | Default | Purpose |
|---|---|---|
| `styleSheet` | themed defaults | Per-component visual overrides |
| `inlineCodeStyle` | themed defaults | Convenience override for inline code only |
| `followLinkColor` | `false` | Inert; `LinkStyle` decides how a link is painted |

Use `GptMarkdownThemeData` for app-wide defaults and `styleSheet` for one
widget. Widget fields win over theme fields one property at a time.
`followLinkColor` is plumbed as far as the render config and then read by
nothing, so a link label paints the same whichever value you pass; set
`LinkStyle` on the style sheet instead. See
[customization](customization.md).

## Builders

Builders replace structure. All are optional:

| Option | Replaces |
|---|---|
| `headingBuilder` | A heading and its optional divider |
| `blockQuoteBuilder` | A block quote |
| `checkboxBuilder` | A task-list row |
| `radioOptionBuilder` | A radio-option row |
| `hrBuilder` | A horizontal rule |
| `codeBuilder` | A fenced code block |
| `tableBuilder` | A table |
| `imageBuilder` | An image |
| `latexBuilder` | Inline or block TeX |
| `inlineLinkBuilder` | A Markdown or automatic link, as a span |
| `linkBuilder` | *Deprecated.* A link, as a widget |
| `inlineCodeBuilder` | The span for inline code |
| `highlightBuilder` | *Deprecated.* Inline code, as a widget |
| `inlineSourceTagBuilder` | A citation/source tag, as a span |
| `sourceTagBuilder` | *Deprecated.* A citation/source tag, as a widget |
| `orderedListBuilder` | An ordered-list item |
| `unOrderedListBuilder` | An unordered-list item |

`highlightBuilder`, `linkBuilder` and `sourceTagBuilder` are deprecated; use
`inlineCodeBuilder`, `inlineLinkBuilder` and `inlineSourceTagBuilder`. Each
returns an `InlineSpan` instead of a `Widget`, which keeps the content on the
text baseline, wrapping across lines and selectable. Together with
`incremental`, `components` and `inlineComponents` they are the whole
deprecated surface of the constructor; every one of them still works and is
slated for removal in 2.0.0. Builder signatures and resolved styles are listed
in [customization](customization.md#builders).

## Callbacks

| Option | Called when |
|---|---|
| `onLinkTap` | A link is activated; receives URL and label |
| `onImageTap` | An image is activated |
| `onCodeCopy` | The built-in code copy action succeeds |
| `onSourceTagTap` | A citation/source tag is activated |
| `onCheckboxChanged` | An interactive task checkbox changes |

Checkboxes are read-only unless `CheckboxStyle.interactive` is true. A custom
`codeBuilder` owns its own copy behavior and does not invoke `onCodeCopy`
automatically.

## Choosing the right extension point

1. Use `style` for surrounding typography.
2. Use a style object for component appearance.
3. Use `InlinePattern` for app-specific inline tokens, or `InlineDirective`
   for a delimited payload the parser must not read.
4. Use a builder when the component's structure must change.
5. Use `blockComponents` for genuinely new block grammar.
6. Reach for the `MarkdownComponent` route — a `BlockMd` or `InlineMd`
   subclass passed through `components` or `inlineComponents` — only where
   the legacy parser is acceptable; all four are deprecated and go in 2.0.0.
