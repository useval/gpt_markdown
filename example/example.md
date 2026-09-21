# gpt_markdown

Markdown and LaTeX rendering for Flutter, built for AI chat output.

Full guides live in [`docs/`](https://github.com/useval/gpt_markdown/tree/main/docs).
Run `flutter run` in `example/` for the interactive demos.

---

## 1. Getting started

```dart
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class AnswerView extends StatelessWidget {
  const AnswerView({super.key, required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    // The widget sizes itself to its content, so give it somewhere to scroll.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GptMarkdown(
        reply,
        // Links do nothing on their own — the package has no URL launcher.
        onLinkTap: (url, title) => debugPrint('open $url'),
      ),
    );
  }
}
```

Headings, emphasis, lists, task lists, tables, quotes, rules, images, code
blocks, LaTeX and citations all render out of the box. Bare URLs, `www.` hosts
and email addresses are linked automatically.

---

## 2. Builders — replacing a widget

Use a builder when you need different *structure*. Each one receives the
resolved style, so it can follow the theme rather than restate it.

```dart
GptMarkdown(
  reply,
  // Maths needs a renderer; pick your own engine.
  latexBuilder: (context, tex, style, inline) => Math.tex(
    tex,
    textStyle: style,
    onErrorFallback: (err) => Text(tex, style: style),
  ),

  // Cached images with a placeholder.
  imageBuilder: (context, url, width, height) => CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    placeholder: (context, _) => const CircularProgressIndicator(),
  ),

  // A callout instead of the default quote bar.
  blockQuoteBuilder: (context, content, style) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(padding: const EdgeInsets.all(12), child: content),
  ),

  // `closed` is false while a fence is still streaming.
  codeBuilder: (context, name, code, closed) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    child: SelectableText(code),
  ),
)
```

Builders exist for every component: `headingBuilder`, `checkboxBuilder`,
`radioOptionBuilder`, `hrBuilder`, `tableBuilder`, `orderedListBuilder`,
`unOrderedListBuilder`, `inlineCodeBuilder`, `inlineLinkBuilder` and
`inlineSourceTagBuilder`.

The three that return a `Widget` — `linkBuilder`, `sourceTagBuilder` and
`highlightBuilder` — are deprecated in 1.3.0 and removed in 2.0.0. A widget has
to sit in a `WidgetSpan`, which puts it off the text baseline, stops it
wrapping across lines and hides it from text selection. Their replacements
(`inlineLinkBuilder`, `inlineSourceTagBuilder`, `inlineCodeBuilder`) return an
`InlineSpan` instead. See [MIGRATION.md](../MIGRATION.md).

---

## 3. Customizing appearance

For colours, sizes and padding use a style object — not a builder.

**One widget:**

```dart
GptMarkdown(
  reply,
  styleSheet: const GptMarkdownStyleSheet(
    inlineCode: InlineCodeStyle(fontFamily: 'GeistMono'),
    blockQuote: BlockQuoteStyle(barWidth: 4, barColor: Colors.indigo),
    codeBlock: CodeBlockStyle(borderRadius: Radius.circular(12)),
  ),
)
```

**The whole app**, through the theme extension:

```dart
MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    extensions: [
      GptMarkdownThemeData(
        brightness: Brightness.light,
        h1: Theme.of(context).textTheme.headlineMedium,
        styleSheet: const GptMarkdownStyleSheet(
          link: LinkStyle(decoration: TextDecoration.none),
          table: TableStyle(cellPadding: EdgeInsets.all(10)),
          latex: LatexStyle(scrollBlockHorizontally: true),
        ),
      ),
    ],
  ),
  // Dark mode needs its own extension, with a matching brightness.
  darkTheme: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: [GptMarkdownThemeData(brightness: Brightness.dark)],
  ),
)
```

A value on the widget wins over the theme **field by field**, so overriding one
setting never discards the rest. Every field is optional, and unset fields keep
the package defaults.

Twelve style classes: `HeadingStyle`, `LinkStyle`, `InlineCodeStyle`,
`ListStyle`, `CheckboxStyle`, `BlockQuoteStyle`, `CodeBlockStyle`,
`TableStyle`, `ImageStyle`, `HrStyle`, `SourceTagStyle`, `LatexStyle`.

---

## 4. Streaming an AI reply

Rebuild with a longer string as tokens arrive. Only the part that can still
change is re-rendered, so the cost per token stays flat as the reply grows.

```dart
GptMarkdown(
  buffer.toString(),
  animation: GptMarkdownAnimation.fade,
  isStreaming: stillGenerating,   // false when the reply finishes
)
```

`GptMarkdownAnimation.none` is the default. Setting `isStreaming: false` is
what triggers the fast-forward, so always flip it when the stream ends.

---

## 5. App-specific inline syntax

`@mention`, `#channel`, `:emoji:` — the package supplies the mechanism, you
supply the meaning.

```dart
GptMarkdown(
  reply,
  inlinePatterns: [
    InlinePattern.prefixed(
      prefix: '#',
      knownNames: channelNames,   // only these match, so `#2959` stays text
      builder: (context, match, style) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: ChannelChip(name: match.group(0)!.substring(1)),
      ),
    ),
  ],
  // Link `myapp://` too. `http`, `https`, `mailto` and `xmpp` are automatic.
  autolinkSchemes: const {'myapp'},
)
```

---

## 6. Other useful bits

```dart
// Callbacks
GptMarkdown(
  reply,
  onImageTap: (url) => openLightbox(url),
  onCodeCopy: (code) => showSnackBar('Copied'),
  onSourceTagTap: (content) => showCitation(content),
)

// Selection
SelectionArea(child: GptMarkdown(reply))

// Right to left
GptMarkdown(reply, textDirection: TextDirection.rtl)

// `$…$` maths instead of `\( … \)`
GptMarkdown(reply, useDollarSignsForLatex: true)

// Turn autolinking off
GptMarkdown(reply, autolink: false)
```

---

## Learn more

| | |
|---|---|
| [Getting started](https://github.com/useval/gpt_markdown/blob/main/docs/getting-started.md) | Install, syntax, taps, LaTeX, RTL |
| [Customization](https://github.com/useval/gpt_markdown/blob/main/docs/customization.md) | Every style field and builder |
| [Streaming](https://github.com/useval/gpt_markdown/blob/main/docs/streaming.md) | Pacing, performance, limitations |
| [Inline syntax](https://github.com/useval/gpt_markdown/blob/main/docs/inline-syntax.md) | Autolinks, patterns, scopes |
| [Playground](https://gptmarkdown.com/playground) | Try it in the browser |
