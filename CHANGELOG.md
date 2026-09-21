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

### `gpt_chat` — Responses API (breaking)

The gateway retired `/chat/completions`; it now answers 404 with *"This API
serves POST /v1/responses"*. The client speaks the Responses API instead.

* `PlusfinityConfig.responsesUri` replaces `completionsUri`, which is
  deprecated and now points at the same endpoint.
* Request fields follow Responses: `input` rather than `messages`,
  `max_output_tokens` rather than `max_tokens`, and `reasoning: {effort}`
  rather than a flat `reasoning_effort`. `x_plusfinity` is unchanged.
* `CompletionChunk` reads typed stream events — `response.output_text.delta`
  for text, `response.completed` / `.failed` / `.incomplete` for the end — and
  an `output` array of `output_text` parts when not streaming. There are no
  `choices`.

### `gpt_chat` — adapter + slot rework (breaking)

The chat layer is now a UI shell any app can drive, with the Plusfinity Gateway
as one plug-in rather than the foundation. See `doc/chat_adapter_plan.md`.

* **New entry points.** `package:gpt_markdown/gpt_chat.dart` is the UI and adapter
  layer and pulls in no HTTP dependency; the gateway client moved to
  `package:gpt_markdown/gpt_chat_gateway.dart`. The old
  `package:gpt_markdown/gpt_chat/gpt_chat.dart` still works and re-exports both.
* **`ChatAdapter`** is the seam between the UI and whatever produces the
  conversation. Apps that already own their chat state implement it directly and
  keep that state; apps with no state layer extend `StreamingChatAdapter`, which
  handles sessions, titling, cancellation, retry and persistence on top of one
  `streamReply` method. `ChatViewModel`, `ChatRepository`, `SessionRepository`
  and `ModelRepository` are gone.
* **`ChatMessage` is now an interface**, so a host can satisfy it on its own
  message type — mutable, a `ChangeNotifier`, backed by a DTO — without
  converting. `SimpleChatMessage` is the package's own implementation. When a
  message is also a `Listenable`, the transcript rebuilds that one bubble as it
  streams instead of the whole list.
* **Slot-based builders.** Every builder now takes a single `ChatSlot` carrying
  the controller, the resolved theme, the default widget, *and* the parts that
  composed it. Replace the transcript and you still get the bubbles
  (`slot.item(i)`); replace an answer and you still get its text, sections and
  actions. Names are flat and prefixed (`answerText`, `composerSend`).
* **`ChatTheme`** covers colours, radii, spacing, widths and typography, so a
  rebrand needs no builders.
* **`ChatCapabilities`** replaces the `showSessions` / `showModelSelector` flags:
  the chrome follows the adapter.
* **Defaults redrawn** to the familiar assistant-app shape — centred reading
  column, user bubble right / assistant full width, model picker in the app bar,
  floating rounded composer, date-grouped conversation drawer.
* `GptChat(config:)` is now `GatewayChat(config:)`; `GptChat` takes an adapter.
* Composer drafts carry attachments and a host-defined tool via `ChatDraft`.
* Send and stop are separate widgets (`ChatSendButton`, `ChatStopButton`) behind
  `composerSend` / `composerStop`; stop takes send's place while a reply streams.
* The drawer groups by recency, searches past eight conversations, and offers
  rename when the adapter allows it. The conversation list, suggestion chips,
  the attachment strip and the load-more footer are each gated on the matching
  `ChatCapabilities` flag.
* Answer actions are copy + regenerate, pinned on touch and hover-revealed on
  pointer platforms per `ChatTheme.answerActionsAlwaysVisible`.
* **A host's own message type now flows through `StreamingChatAdapter`.**
  `newMessage` returns `ChatMessage` rather than the package's own type, and one
  new hook — `updateMessage` — is all a custom model needs. Forgetting it fails
  loudly at send time (debug assert) instead of asynchronously inside the stream.
* **`ChatDelta` carries a `payload`**, plus a `ChatDelta.data` constructor, so a
  chunk's non-prose parts (sources, tool status, media, reasoning) can be routed
  into fields the package knows nothing about via the `applyDelta` hook.
* `ChatTheme.scrollPhysics` and `ChatTheme.transcriptPadding` — the last two
  reasons a host had to override `messageList` just to change a metric.
* `listHeader` / `listFooter` are constrained to the reading column, like every
  exchange, so they no longer have to re-wrap themselves.
* `ChatController(followLatest: false)` hands scrolling entirely to the host, for
  apps whose own view model already drives the transcript. Without it two things
  share one `ScrollController`.
* The transcript's anchor height is now measured *after* `transcriptPadding`, so
  the last exchange is not taller than the space it actually gets.
* The awaiting-first-token state no longer short-circuits the `answer` builder: a
  host's header, status line and progress now render from the moment a question
  is sent, not from the first token.

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
