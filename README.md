<p align="center">
  <img src="assets/gpt-mark.png" width="112" alt="gpt_markdown logo">
</p>

<h1 align="center">gpt_markdown</h1>

<p align="center"><strong>The Flutter renderer for AI output.</strong></p>

<p align="center">
  Production-grade Markdown and LaTeX rendering for streaming Flutter AI interfaces.<br>
  Render rich assistant replies, math, code, tables, citations, images, and custom inline UI in one widget.
</p>

<p align="center">
  <a href="https://pub.dev/packages/gpt_markdown"><img src="https://img.shields.io/pub/v/gpt_markdown?color=F47C3C" alt="Pub Version"></a>
<a href="https://img.shields.io/pub/likes/gpt_markdown?color=8B5CF6"><img src="https://img.shields.io/pub/likes/gpt_markdown?color=8B5CF6" alt="Pub Likes"></a>
<a href="https://img.shields.io/pub/points/gpt_markdown?color=44C11F"><img src="https://img.shields.io/pub/points/gpt_markdown?color=44C11F" alt="Pub Points"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-1687D2.svg" alt="BSD-3-Clause license"></a>
</p>

<p align="center">
  <a href="https://gptmarkdown.com">🌐 Website</a> ·
  <a href="https://gptmarkdown.com/docs">📖 Documentation</a> ·
  <a href="https://gptmarkdown.com/playground">🎮 Live Playground</a> ·
  <a href="https://pub.dev/packages/gpt_markdown">📦 pub.dev</a>
</p>

<p align="center">
  <a href="https://x.com/use_val">
    <img src="https://img.shields.io/badge/Follow%20Val%20on%20X-%40use__val-F47C3C?logo=x&logoColor=white&labelColor=000000" alt="Follow Val on X: @use_val">
  </a>
</p>

---

## ✨ Why gpt_markdown?

- **Built for AI output** — Markdown, LaTeX, code blocks, tables, alerts, citations, images, task lists, and mixed rich content in one response.
- **Streaming that stays fast** — settled segments are reused while the live tail updates. At 12 KB, each update is 31× faster than in 1.2.1—or 74× faster with the lazy sliver. [See the benchmarks](docs/performance/benchmarks.mdx).
- **Production-level control** — style sheets, Flutter theme extensions, component builders, callbacks, and custom components.
- **Extensible inline UI** — add `@mentions`, `#channels`, `:emoji:`, issue references, and product-specific syntax without forking the renderer.
- **Designed for real-world edge cases** — RTL, text scaling, selection, malformed Markdown, autolinks, nested content, reduced motion, Flutter web, and WASM.
- **CommonMark, tested** — 530 of the 652 CommonMark 0.31.2 spec examples pass on every CI run; the rest are raw HTML, indented code, and three documented leniencies for model output. [See the details](docs/commonmark.mdx).

## 🧩 Everything AI output needs

| | Rendering | | Production experience | | Extensibility |
|---|---|---|---|---|---|
| 📝 | Rich Markdown | ⚡ | Adaptive streaming | 🎨 | Component style sheet |
| ∑ | Inline and block LaTeX | 🚀 | Lazy sliver rendering | 🧱 | Structural builders |
| 💻 | Syntax-highlighted code | ♿ | Selection and text scaling | 🏷️ | Mentions, channels, and emoji |
| 📊 | Tables and aligned columns | 🌍 | RTL, web, and WASM | 🧩 | Custom components and scopes |
| 🔗 | Links, autolinks, and images | 🌓 | Theme-aware rendering | 👆 | Interaction callbacks |
| ☑️ | Lists, tasks, and citations | 🛡️ | Graceful malformed input | 📱 | Custom URL schemes |

## 🖼️ What it renders

Every image is one `GptMarkdown` widget in a light Material 3 theme. The only styling is softer table borders and compact checkboxes; the inline components are app-supplied builders. Click any of them for full size.

|  |  |  |
|:--|:--|:--|
| <img alt="Rich text rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/rich-text.png?v=3"><br>**Rich text**<br>Headings, emphasis, lists, quotes, rules, autolinks. | <img alt="LaTeX rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/math.png?v=3"><br>**LaTeX**<br>Inline and display equations, on the text baseline. | <img alt="Tables rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/tables.png?v=3"><br>**Tables**<br>Per-column alignment, Markdown inside cells. |
| <img alt="Code rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/code.png?v=3"><br>**Code**<br>Syntax highlighting, language labels, and copy controls. | <img alt="Task lists rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/lists.png?v=3"><br>**Task lists**<br>Checkboxes, ordered and nested lists, citation tags. | <img alt="Custom inline components rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/inline-components.png?v=3"><br>**Custom inline components**<br>Mentions, channels, status pills, file chips. `#2959` stays text. |

## 🛠️ Quick start

```bash
flutter pub add gpt_markdown
```

```dart
import 'package:gpt_markdown/gpt_markdown.dart';

GptMarkdown(
  reply,
  onLinkTap: (url, title) => openUrl(url),
)
```

The widget sizes itself to its content. Place it inside your preferred scrollable chat or document surface.

## ⚡ Streaming AI responses

Rebuild `GptMarkdown` with the complete text received so far. Settled segments are reused while the changing tail updates.

```dart
GptMarkdown(
  streamedReply,
  animation: GptMarkdownAnimation.fade,
  blockAnimation: GptMarkdownBlockAnimation.fadeIn,
  isStreaming: stillGenerating,
  charactersPerSecond: 300,
)
```

The reveal adapts to incoming text, finishes when generation ends, and respects reduced-motion settings. See the [streaming guide](docs/streaming.mdx) for animation modes and configuration.

For long responses and documents, use `SliverGptMarkdown` inside a
`CustomScrollView`. It creates spans and widgets only for the segments requested
by the viewport, including its cache extent. The regular `GptMarkdown` widget is
cheaper for short content and remains the option for character reveal. See the
[rendering architecture guide](docs/architecture.mdx).

## 📝 Markdown, LaTeX, and rich AI output

```dart
GptMarkdown(
  r'''
## Revenue forecast

Projected growth: **18%**.

\[
R_{next} = R_{current} \times (1 + 0.18)
\]

- [x] Validate the assumptions
- [ ] Review the final forecast

Sources: [1] [2]
  ''',
  onSourceTagTap: (source) => openSource(source),
)
```

Use `\( ... \)` for inline LaTeX and `\[ ... \]` for block equations. Enable dollar-sign syntax with `useDollarSignsForLatex: true`. Code fences include syntax highlighting, language labels, and copy controls.

Wrap the renderer with `SelectionArea` when selectable output is needed:

```dart
SelectionArea(
  child: GptMarkdown(reply),
)
```

## 🎨 Make it match your product

Use style objects for appearance and builders when you need to replace structure.

```dart
GptMarkdown(
  reply,
  styleSheet: const GptMarkdownStyleSheet(
    blockQuote: BlockQuoteStyle(
      barWidth: 4,
      barColor: Colors.indigo,
    ),
    inlineCode: InlineCodeStyle(
      fontFamily: 'GeistMono',
      borderRadius: Radius.circular(6),
    ),
    codeBlock: CodeBlockStyle(
      borderRadius: Radius.circular(12),
      showCopyButton: true,
    ),
    table: TableStyle(
      cellPadding: EdgeInsets.all(10),
    ),
  ),
  onCodeCopy: (code) => trackCopy(code),
  onImageTap: (url) => openImage(url),
)
```

Set styles app-wide with `GptMarkdownThemeData`. Use builders such as `codeBuilder`, `tableBuilder`, and `imageBuilder` to replace components, or span-based builders for links, citations, and inline code. See [customization](docs/customization.mdx).

## 🏷️ App-specific inline UI

Render mentions, channels, emoji, issue references, and other product syntax alongside Markdown:

```dart
GptMarkdown(
  reply,
  inlinePatterns: [
    InlinePattern.prefixed(
      prefix: '#',
      knownNames: channelNames,
      builder: (context, match, style) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: ChannelChip(
          name: match.group(0)!.substring(1),
        ),
      ),
    ),
  ],
)
```

Only known channel names are matched, longest-first. Patterns exclude link labels by default; unrecognized tokens such as `#2959` remain text.

Use `blockComponents` for custom blocks and `inlineDirectives` for payloads the parser must leave untouched. See [custom components](docs/custom-components.mdx).

**Upgrading?** Passing `components` or `inlineComponents`, even an empty list, selects the deprecated legacy parser. Replace them to use the new pipeline. See the [migration guide](docs/migration.mdx) and [changelog](CHANGELOG.md).

## 🔗 Autolinks

Bare URLs, `www.` hosts, emails, and angle autolinks work automatically. Add custom schemes with `autolinkSchemes: const {'myapp'}`, or disable autolinking with `autolink: false`. Explicit `[label](url)` links still work. See [inline syntax](docs/inline-syntax.mdx).

## 📚 Documentation

| Guide | Covers |
|---|---|
| [Getting started](docs/getting-started.mdx) | Installation, taps, text style, RTL, and selection |
| [Markdown syntax](docs/syntax.mdx) | Everything it renders, and the rules that decide what stays text |
| [Components](docs/components/index.mdx) | One page per component: preview, syntax, styling, and API reference |
| [Math](docs/components/math.mdx) | Formulas, taps, your own renderer, and dollar-sign maths |
| [Customization](docs/customization.mdx) | Style classes, themes, builders, and callbacks |
| [Streaming](docs/streaming.mdx) | Pacing, performance, accessibility, and limitations |
| [Rendering architecture](docs/architecture.mdx) | Extension registration, lazy rendering, and performance policies |
| [Inline syntax](docs/inline-syntax.mdx) | Autolinks, mentions, channels, and scopes |
| [Custom components](docs/custom-components.mdx) | Block and inline extensions |
| [`GptMarkdown` options](docs/options.mdx) | Every constructor option and default |
| [Benchmarks](docs/performance/benchmarks.mdx) | Methodology, results, and limitations |
| [Migration](docs/migration.mdx) | What each release changes, newest first |

## When to use gpt_markdown

Choose `gpt_markdown` for fast, customizable AI output rendering in Flutter.
Render streaming replies, Markdown, LaTeX, syntax-highlighted code, tables,
images, and citations together in one widget.

At 12 KB, per-chunk streaming is **31× faster with `GptMarkdown`** and
**74× faster with `SliverGptMarkdown`** than in 1.2.1.
[See benchmark methodology and results](docs/performance/benchmarks.mdx).

Build ChatGPT-style chat apps, copilots, and AI assistants with themes,
custom builders, and inline UI. Works with text output from ChatGPT,
Claude, Gemini, and other LLMs, as well as general Markdown documents.

## Built by Val

`gpt_markdown` is the open-source rendering foundation of [Val](https://useval.io), the live visual layer for AI agents.

Building an AI product that needs richer output than a text box? [Request early access to Val.](https://useval.io/)

## 💬 Community

Issues and pull requests are welcome on [GitHub](https://github.com/useval/gpt_markdown). If the package helps your project, consider giving it a like on [pub.dev](https://pub.dev/packages/gpt_markdown) or a star on GitHub.

## 📄 License

BSD 3-Clause — see [LICENSE](LICENSE).
