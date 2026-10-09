## Unreleased

### Changed

* **Breaking:** Migrated from `package:flutter/material.dart` to
  [`material_ui`](https://pub.dev/packages/material_ui) (#152).
* The minimum SDK is now Dart 3.12 and Flutter 3.44, which `material_ui`
  requires.

## 1.3.4

### Changed

* With `useDollarSignsForLatex`, `$…$` is maths even in a reply that also
  uses `\(…\)`. It used to be turned off for the whole reply. Prices still
  stay text (`$5 and $10`).

### Fixed

* With the fade reveal, content below a list jumped up a few pixels as the
  fade finished passing over the list — most visibly the next heading.
* A code block (or second paragraph) inside a list item, after a blank
  line, was rendered outside the list with the item's indent left in every
  line.
* While a code block inside a `>` quote was still streaming, `$` maths and
  inline patterns could reach into it (`echo \(A/\)B`).
* The streaming hold no longer briefly shows a lone `2` before `2. item`, an
  empty `2.` item whose content is still arriving, or a `[1]` that becomes a
  `[1]: url` definition.

## 1.3.3

### Added

* CommonMark syntax: `_italic_` / `__bold__`, multi-backtick code spans,
  `~~~` and longer fences, backslash escapes, entity references
  (`&amp;`, `&#169;`), link titles and `<url>` destinations, reference
  links, setext headings, closing `#`s, and hidden `<!-- comments -->`.
* Footnotes: `text[^1]` with `[^1]: note`.
* `[1]: url` gives a `[1]` citation chip a URL (`SourceTagBuildDetails.url`);
  tapping it calls `onLinkTap` when no `onSourceTagTap` is set.
* `MarkdownDefinitions` and `Plusparse.parse(definitions:)`, for parsing a
  document in pieces.

### Changed

* `*` and `_` followed by a space no longer open emphasis (`2 * 3 * 4`).
* Single `$` maths follows Pandoc's rule, so `$5 and $10` stays prose.
* Text directly above `---` is now a heading.
* `MdNode` has new subclasses: `MdFootnoteReference`, `MdFootnoteDefinitions`.

### Fixed

* Inline patterns no longer reach into code spans or maths (`` `:wave:` ``
  showed a placeholder).
* With `autolink: false`, patterns inside bold were not applied.
* A URL right after `_` was not autolinked.
* `$` maths was applied inside code.
* `[text](url "title")` kept the title in the URL.

## 1.3.2

### Added

* `onLatexTap`: called when a formula is tapped, with a `LatexTapDetails`
  holding the formula (`tex`, `source`), whether it is inline, the TeX of the
  part under the finger (`tappedTex`) and any `\href` target. The default
  formulas show a click cursor while a handler is set.
* `inlineLatexBuilder` builds an inline formula as an `InlineSpan` — return a
  `MathSpan` with its own `onTap`, plain text, or anything else that belongs in
  a line — and `blockLatexBuilder` builds a block formula as a `Widget`. Each
  takes one details object (`InlineLatexBuildDetails`,
  `BlockLatexBuildDetails`) with the formula after `latexWorkaround` and as
  written, the resolved style, an `onTap` bound to `onLatexTap`, and the stock
  formula to keep or wrap (`defaultSpan()`, `defaultWidget()`,
  `asWidgetSpan()`). `LatexStyle` still pads, fills and scrolls a block
  builder's result. Both pipelines honour them.

### Deprecated

* `latexBuilder` and its `LatexBuilder` type, in favour of
  `inlineLatexBuilder` and `blockLatexBuilder`. Nothing is removed: it keeps
  working wherever the matching new builder is not set, and goes in 2.0.0.

### Changed

* Requires `val_latex_flutter` 0.1.2, which adds taps to `MathSpan` and stops
  an inline `MathSpan` scaling twice under a text scaler. The default renderer
  now asks for streaming parses explicitly, so val_latex_flutter's new
  `Math.tex` default (not streaming) does not reach a formula still arriving.

## 1.3.1

### Added

* Alerts: a quote whose first line is `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`,
  `[!WARNING]` or `[!CAUTION]` renders with an icon, a title and an accent
  colour on a faint tint of it (#79). Style it with
  `GptMarkdownStyleSheet.alert` (`AlertStyle`, with per-type overrides) or
  replace it with `alertBuilder`. Apps that set `blockQuoteBuilder` and no
  `alertBuilder` keep their quote look. The parsed `MdBlockQuote` gains an
  optional `alert`; its `children` are unchanged.
* Images with a `data:` URL — `![](data:image/png;base64,...)` — render (#32).
  They went to `NetworkImage`, which cannot load one outside a browser. The
  decoded bytes are cached, so rebuilds do not decode again.
* `GptMarkdownStyleSheet.blockSpacing` sets the gap between blocks, in logical
  pixels (#41). Unset, it is the existing one empty line; it scales with the
  text either way, and extra blank lines in the source never widen it.
* `TableStyle.overflow`: `TableOverflow.wrap` fits a wide table to the screen
  and wraps its cells instead of scrolling it sideways (#93). The default,
  `TableOverflow.scroll`, is the existing behaviour.

### Changed

* Code blocks are highlighted with
  [`val_highlight_flutter`](https://pub.dev/packages/val_highlight_flutter)
  instead of `highlight`: 55 languages, its `light` and `dark` themes, and a
  faster engine. A fence tag with no grammar still renders as plain text.
* The minimum SDK is now Dart 3.9 and Flutter 3.35, which `val_highlight`
  requires.
* Maths renders with
  [`val_latex_flutter`](https://pub.dev/packages/val_latex_flutter) instead of
  `flutter_math_fork`. Formulas are set in Latin Modern Math, a formula still
  streaming in (`\frac{a`) renders what exists so far, and `\tag`, `align`,
  `\ce{…}` and `\SI{…}` work. Size, colour, display style and the raw-TeX
  fallback are unchanged. Selecting a formula copies the LaTeX of the selected
  part. A `latexBuilder` written against `flutter_math_fork` keeps working if
  your app still depends on it.
* Maths streams as it arrives. A formula that is still open — `\(`, `\[`, or
  `$`/`$$` with `useDollarSignsForLatex` — renders as far as it has come and
  grows with each chunk, instead of being held back and appearing whole when
  its closing delimiter lands. A command name still being typed is held for a
  chunk, so raw TeX never shows. Only text that grows while mounted is
  affected; a finished reply renders as before.

### Fixed

* With `useDollarSignsForLatex`, a `$$` display formula that had not closed yet
  was read as an empty `$…$` pair: it rendered as nothing and its body showed
  as prose until the closing `$$` arrived.
* Custom `inlineComponents` / `components` whose regex uses `unicode: true`
  (for example `\p{L}`) now match. The flag was dropped when the patterns were
  combined, so such components silently matched nothing (#114).
* `GptMarkdown` no longer throws inside `IntrinsicWidth` or `IntrinsicHeight`
  — the usual way to shrink-wrap a chat bubble — when the message holds a
  table or a horizontal rule (#107). Normal layout is unchanged. Still open on
  the legacy pipeline (`inlineComponents` / `components`) in debug builds,
  where Flutter asserts on the dry baseline of block placeholders.

## 1.3.0

Our biggest release yet.

`gpt_markdown` 1.3.0 introduces a new rendering pipeline for fast,
production-grade AI output. Parsing is **3–9× faster** than the legacy parser,
whole-frame rendering is up to **2× faster**, and streaming performance stays
flat as responses grow.

At 12 KB, per-chunk streaming is **31× faster** with `GptMarkdown` and **74×
faster** with `SliverGptMarkdown` compared with 1.2.1. See the
[benchmarks](docs/benchmark.md).

Nothing has been removed. Existing integrations continue to work, and
deprecated APIs remain supported until 2.0.0.

### Added

* **`plusparse`** — a new single-pass parser, enabled by default.
* **`SliverGptMarkdown`** — lazy rendering for long documents and streaming
  responses.
* **Streaming animations** — character reveals and block entrances with
  configurable timing and curves.
* **Modern extension APIs** for custom block and inline syntax.
* **Span-based builders** for links, citations, and inline code.
* **Syntax highlighting for nearly 200 languages**, with a language label and
  accessible copy button.

### Changed

* Links now wrap naturally, align with surrounding text, and remain selectable.
* Block elements render independently, improving selection, scaling, and
  bidirectional layouts.

### Fixed

* `maxLines` now limits the complete document, and paragraph line breaks are
  preserved.
* Lists, quotes, tables, code blocks, images, and mathematics scale and style
  consistently.
* Streaming accessibility no longer produces repeated announcement storms.
* Fixed numerous parsing, reveal-ordering, and streaming-stability issues.

### Deprecated

The legacy regex parser remains fully functional, with removal planned
for 2.0.0.

The `incremental` argument is no longer needed. Replace `components` and
`inlineComponents` with `blockComponents`, `inlinePatterns`, or
`inlineDirectives`.

See [MIGRATION.md](MIGRATION.md) for complete upgrade guidance.

## 1.2.1

### Changed

* Radio list markers use `RadioGroup` instead of `Radio.groupValue` and
  `Radio.onChanged`, which Flutter deprecated in 3.32. No visual or behavioural
  change — the marker looks and responds exactly as before.
* Minimum Flutter is now **3.32.0**, the release `RadioGroup` was added in.

### Added

* `InlinePattern.delimited` for tokens that open and close, such as `:emoji:`,
  `::spoiler::` or `{{token}}` — the counterpart to `InlinePattern.prefixed`,
  which cannot express a closing delimiter. The token name is the named group
  `name`. See [docs/inline-syntax.md](docs/inline-syntax.md).

## 1.2.0

Upgrading from 1.1.x? See [MIGRATION.md](MIGRATION.md).

### Changed

* Deprecated `highlightBuilder`. Use `inlineCodeStyle` for appearance, or
  `inlineCodeBuilder` for full control. It still works, is now aligned on the
  text baseline, and will be removed in 2.0.0.
* Inline code renders as a monospace chip that wraps across lines. Restyle with
  `inlineCodeStyle`.
* Autolinking is on by default. Disable with `autolink: false`, and remove any
  pre-processor that rewrites bare URLs.
* `ImageMd`, `TableMd` and `ATagMd` no longer render inside link labels. Custom
  components opt out with `scopes`.
* Malformed links and unclaimed matches render as plain text instead of being
  dropped silently.
* Component dispatch is anchored as `^(?:pattern)$`, so a pattern containing a
  top-level `|` no longer claims matches it does not cover.
* Case-insensitive component patterns now match.
* Tests using `find.byType(RichText)` need
  `find.byWidgetPredicate((w) => w is RichText)` — some paragraphs render as a
  `RichText` subclass.

### Added

* Streaming reveal for generated replies, off by default:
  `GptMarkdown(text, animation: GptMarkdownAnimation.fade, isStreaming: true)`.
  Only the part of the reply that can still change is rebuilt, so the cost per
  token stays flat as the reply grows. The reveal keeps up with a fast model,
  fast-forwards when `isStreaming` turns false, and honours reduced motion.
  See [docs/streaming.md](docs/streaming.md).
* `GptMarkdownStyleSheet` with twelve per-component style classes, settable per
  widget or app-wide on `GptMarkdownThemeData`. Unset fields keep the previous
  defaults.
* Builders for every component: `blockQuoteBuilder`, `headingBuilder`,
  `checkboxBuilder`, `radioOptionBuilder`, `hrBuilder`.
* Callbacks `onCheckboxChanged`, `onCodeCopy`, `onImageTap`, `onSourceTagTap`.
* `InlinePattern` for app-specific inline syntax such as `@mention`,
  `#channel` and `:emoji:`, with `InlinePattern.prefixed` for the common case.
* `MarkdownScope` and `MarkdownComponent.scopes` — components declare which
  nesting contexts they render in.
* Autolinks following the GFM autolink extension and CommonMark §6.5, with
  `autolinkSchemes` for app schemes.
* `GptMarkdownConfig` and the builder typedefs are exported from the main
  import.

### Fixed

* Text scaling: components rendered through a `WidgetSpan` reserved up to 39x
  the space they needed at a 2x system font setting. Every component now scales
  proportionally.
* Theme changes did not repaint — colours are resolved when spans are built,
  and the cache was not invalidated.
* `GptMarkdownConfig.isSame` ignored several fields, so runtime changes to
  components, inline patterns and styles did nothing.
* Inline widgets in right-to-left paragraphs render in visual order
  ([flutter#54400](https://github.com/flutter/flutter/issues/54400)).
* `GptMarkdownConfig.getRich` returns `Widget` instead of `Text`.

## 1.1.8

* 🔗 Fixed consecutive links separated by single newlines not rendering ([#142](https://github.com/useval/gpt_markdown/issues/142)).

## 1.1.7

* Added/updated the interactive playground and pub.dev example flow, with `playground.dart` as a dedicated playground entry and improved demo content for links, lists, blockquotes, tables, and LaTeX.
* Updated package metadata: bumped to `1.1.7`, set `homepage` to [gptmarkdown.com](https://gptmarkdown.com), and added `repository` + `issue_tracker`.
* Bumped `flutter_math_fork` to `^0.7.4` for Flutter 3.35+ compatibility.
* Fixed bold markdown rendering across newlines by enabling `dotAll` in `BoldMd`.
* Fixed link styling so underline/color (including hover color) apply consistently across nested inline spans (bold/italic) inside links via `LinkSpanBuilder`.
* Extended `imageBuilder` to receive parsed size metadata from markdown image syntax (`context, imageUrl, width, height`).
* Resolved deprecated radio API usage by wrapping `Radio<bool>` with `RadioGroup` in custom radio rendering.
* Cleaned up and corrected docs/example markdown content for the updated API and examples.

## 1.1.6

* Added `hrLinePadding` to `GptMarkdownThemeData` (default `EdgeInsets.zero`), wired through the public factory, `copyWith`, and `lerp`, for padding around horizontal rules and the optional line after `#` headings.
* Added `autoAddDividerLineAfterH1` to `GptMarkdownThemeData` (default `true`), with the same factory / `copyWith` / `lerp` support, so the extra divider after a level-1 heading can be toggled from theme data.
* Added `padding` to `CustomDivider` (default `EdgeInsets.zero`); the render object lays out and paints the stroke inside those insets and uses the constrained width when drawing.
* Added `GptMarkdownThemeData.isSame` to compare every field on the theme data type.
* `HTag` and `HrLine` use `hrLineColor`, `hrLinePadding`, and `autoAddDividerLineAfterH1` from `GptMarkdownTheme.of(context)` for the horizontal line widgets.

## 1.1.5

* Fixed block latex markdown syntax.

## 1.1.4

* 🔗 Fixed vertical alignment issue with link text rendering ([#92](https://github.com/useval/gpt_markdown/issues/92))
* 📝 Resolved "null" rendering issue in ordered lists with multiple spaces and line breaks ([#89](https://github.com/useval/gpt_markdown/issues/89))
* 🧹 Removed erroneous `trim()` from `CodeBlockMd` to preserve necessary whitespace in code blocks ([#99](https://github.com/useval/gpt_markdown/issues/99))
* 🎨 Fixed heading style customization issue where custom colors in heading styles were not being applied ([#95](https://github.com/useval/gpt_markdown/issues/95))

## 1.1.3

* Added `RadioGroup` widget for managing radio buttons.
* Updated to align with Flutter 3.35 by resolving the deprecations of `Radio.groupValue` and `Radio.onChanged`.

## 1.1.2

* 📊 Fixed table column alignment support ([#65](https://github.com/useval/gpt_markdown/issues/65))
* 🎨 Added `tableBuilder` parameter to customize table rendering
* 🔗 Fixed text decoration color of link markdown component

## 1.1.1

* 🖼️ Fixed issue where images wrapped in links (e.g. `[![](img)](url)`) were not rendering properly (#72)
* 🔗 Resolved parsing errors for consecutive inline links without spacing (e.g. `[a](url)[b](url)`) (#34)

## 1.1.0

* Changed `onLinkTab` to `onLinkTap` fixed issues of newLine issues.

## 1.0.20

* Fix: support balanced parentheses in image and link URLs. [#68](https://github.com/useval/gpt_markdown/pull/68)

## 1.0.19

* Performance improvements.

## 1.0.18

* dollarSignForLatex is added and by default it is false.

## 1.0.17

* Bloc components rendering inside table.

## 1.0.16

* `IndentMd` and `BlockQuote` fixed.
* Baseline of bloc type component is fixed.
* block quote support improved.
* custom components support added.
* `Table` syntax improved.

## 1.0.15

* Performance improvements.

## 1.0.14

* Added `orderedListBuilder` and `unOrderedListBuilder` parameters to customize list rendering.

## 1.0.13

* Fixed issue [#49](https://github.com/useval/gpt_markdown/issues/49).

## 1.0.12

* imageBuilder parameter added.

## 1.0.11

* dart format.

## 1.0.10

* pubspec flutter version updated.

## 1.0.9

* Fixed issues with flutter 3.29.0.
* Fixed > syntax render issue.

## 1.0.8

* Extra lines inside block latex removed and $$..$$ syntax works with \(..\) syntax.

## 1.0.7

* `closed` parameter added to `codeBuilder`.

## 1.0.6

* `_italic_` and `>Indentation` syntax added.
* `linkBuilder` and `highlightBuilder` added [f45132b](https://github.com/useval/gpt_markdown/commit/f45132b2cd4b069d3e5703561deb5c7e51d3c560).

## 1.0.5

* Fixed the order of inline and block latex in markdown.

## 1.0.4

* Fixing latex issue for block syntax.

## 1.0.3

* Multiline latex syntax bug fix.

## 1.0.2

* Readme updated.

## 1.0.1

* Indentation fixed
* `ATag` syntax fixed
* Documentation improved in readme and example.

## 1.0.0

* `TexMarkdown` is renamed to `GptMarkdown`.
* `h1` to `h6` style added to `GptMarkdownThemeData` class. 
* `hrLineThickness` value added to `GptMarkdownThemeData` class. 
* `hrLineColor` Color added to `GptMarkdownThemeData` class. 
* `linkColor` Color added to `GptMarkdownThemeData` class. 
* `linkHoverColor` Color added to `GptMarkdownThemeData` class. 
* Indentation improved. 
* Math equations are now default selectable. 
* `SelectableAdapter` Widget added to make any widget selectable.

## 0.1.15

* `CodeBlock` is moved out of `gpt_markdown.dart` library.

## 0.1.14

* Changed `withOpacity` to `withAlpha` in `theme.dart` for highlightColor.

## 0.1.13

* `GptMarkdownTheme` and `GptMarkdownThemeData` class moved to `gpt_markdown.dart` library.

## 0.1.12

* Fixed the indentation syntex of regex.

## 0.1.11

* `GptMarkdownTheme` and `GptMarkdownThemeData` classes added.

## 0.1.10

* components are now selectable.

## 0.1.9

* source config added.

## 0.1.8

* unordered list bullet color fixed.

## 0.1.7

* ordered list color fixed.

## 0.1.6

* `overflow` perameter added.

## 0.1.5

* Some color changes and highlighted text style changed.

## 0.1.4

* `[source]` format added.

## 0.1.3

* `maxLines` Parameter added.

## 0.1.2

* `textStyle` Parameter added to the latexBuilder function.

## 0.1.1

* Fixed hitTest essue.

## 0.1.0

* Inline Latex Builder added and Link are now Clickable and Latex Error Color changed to null for debug mode.

* `textScaleFector` is removed and `textScaler` added

## 0.0.12

* codeBuilder method added [[#6](https://github.com/saminsohag/flutter_packages/issues/6)], and maked the table scrollable.

## 0.0.11

* New syntex added for codes and highlight.

## 0.0.10

* `$$_$$` syntex fixes.

## 0.0.9

* `$_$` syntex added for latex with a gard condition for `\(_\)`.

## 0.0.8

* `$_$` syntex added for latex with a gard condition for `\(_\)`.

## 0.0.6

* Fixed textScaler problem by removeing that and added textScaleFector.

## 0.0.5

* Latex table workarround added.

## 0.0.4

* Customizable latex and workarround added.

## 0.0.3

* Some latex related fixes.

## 0.0.2

* TextScaler and TextAlign added.

## 0.0.1

* This package will render response of chatGPT in flutter app.
