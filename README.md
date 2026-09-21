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

---

## ✨ Why gpt_markdown?

- **Built for AI output** — Markdown, LaTeX, code blocks, tables, citations, images, task lists, and mixed rich content in one response.
- **Streaming that stays fast** — settled segments are reused while the live tail updates. At 12 KB, each update is 31× faster than in 1.2.1—or 74× faster with the lazy sliver. [See the benchmarks](docs/benchmark.md).
- **Production-level control** — style sheets, Flutter theme extensions, component builders, callbacks, and custom components.
- **Extensible inline UI** — add `@mentions`, `#channels`, `:emoji:`, issue references, and product-specific syntax without forking the renderer.
- **Designed for real-world edge cases** — RTL, text scaling, selection, malformed Markdown, autolinks, nested content, reduced motion, Flutter web, and WASM.

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

Every image is one `GptMarkdown` widget with no styling applied — the defaults, in a dark theme. Click any of them for full size.

|  |  |  |
|:--|:--|:--|
| <img alt="Rich text rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/rich-text.png?v=2"><br>**Rich text**<br>Headings, emphasis, lists, quotes, rules, autolinks. | <img alt="LaTeX rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/math.png?v=2"><br>**LaTeX**<br>Inline and display equations, on the text baseline. | <img alt="Tables rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/tables.png?v=2"><br>**Tables**<br>Per-column alignment, Markdown inside cells. |
| <img alt="Code rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/code.png?v=2"><br>**Code**<br>Syntax highlighting, language labels, and copy controls. | <img alt="Task lists rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/lists.png?v=2"><br>**Task lists**<br>Checkboxes, ordered and nested lists, citation tags. | <img alt="Inline patterns rendered by gpt_markdown" src="https://raw.githubusercontent.com/useval/gpt_markdown/main/screenshots/inline-patterns.png?v=2"><br>**Inline patterns**<br>Mentions, channels, shortcodes. `#2959` stays text. |

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

## 💬 Building a chat page?

This package also ships `gpt_chat` — a full chat screen (transcript, streaming,
scrolling, composer) that renders its answers with `gpt_markdown`. One method
gets you a working chat; a theme covers most rebrands.

```dart
import 'package:gpt_markdown/gpt_chat.dart';

class MyAdapter extends StreamingChatAdapter {
  @override
  Stream<ChatDelta> streamReply(List<ChatMessage> history) async* {
    yield ChatDelta('…');
  }
}

GptChat(adapter: MyAdapter());
```

See **[doc/gpt_chat.md](doc/gpt_chat.md)** for the full guide.

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

The reveal adapts to incoming text, finishes when generation ends, and respects reduced-motion settings. See the [streaming guide](docs/streaming.md) for animation modes and configuration.

For long responses and documents, use `SliverGptMarkdown` inside a
`CustomScrollView`. It creates spans and widgets only for the segments requested
by the viewport, including its cache extent. The regular `GptMarkdown` widget is
cheaper for short content and remains the option for character reveal. See the
[rendering architecture guide](docs/rendering-architecture.md).

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

Set styles app-wide with `GptMarkdownThemeData`. Use builders such as `codeBuilder`, `tableBuilder`, and `imageBuilder` to replace components, or span-based builders for links, citations, and inline code. See [customization](docs/customization.md).

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

Use `blockComponents` for custom blocks and `inlineDirectives` for payloads the parser must leave untouched. See [custom components](docs/custom-components.md).

**Upgrading?** Passing `components` or `inlineComponents`, even an empty list, selects the deprecated legacy parser. Replace them to use the new pipeline. See the [migration guide](MIGRATION.md) and [changelog](CHANGELOG.md).

## 🔗 Autolinks

Bare URLs, `www.` hosts, emails, and angle autolinks work automatically. Add custom schemes with `autolinkSchemes: const {'myapp'}`, or disable autolinking with `autolink: false`. Explicit `[label](url)` links still work. See [inline syntax](docs/inline-syntax.md).

## 📚 Documentation

| Guide | Covers |
|---|---|
| [Getting started](docs/getting-started.md) | Installation, syntax, taps, LaTeX, RTL, and selection |
| [Customization](docs/customization.md) | Style classes, themes, builders, and callbacks |
| [Streaming](docs/streaming.md) | Pacing, performance, accessibility, and limitations |
| [Rendering architecture](docs/rendering-architecture.md) | Extension registration, lazy rendering, and performance policies |
| [Inline syntax](docs/inline-syntax.md) | Autolinks, mentions, channels, and scopes |
| [Custom components](docs/custom-components.md) | Block and inline extensions |
| [`GptMarkdown` options](docs/api-options.md) | Every constructor option and default |
| [Benchmarks](docs/benchmark.md) | Methodology, results, and limitations |
| [Migration](MIGRATION.md) | What each release changes, newest first |

## Built by Val

`gpt_markdown` is the open-source rendering foundation of [Val](https://useval.io), the live visual layer for AI agents.

Building an AI product that needs richer output than a text box? [Request early access to Val.](https://useval.io/)

## 💬 Community

Issues and pull requests are welcome on [GitHub](https://github.com/useval/gpt_markdown). If the package helps your project, consider giving it a like on [pub.dev](https://pub.dev/packages/gpt_markdown) or a star on GitHub.

## 📄 License

BSD 3-Clause — see [LICENSE](LICENSE).
