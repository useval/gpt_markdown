# gpt_markdown documentation

Markdown and LaTeX rendering for Flutter, built for AI chat output.

| Guide | Read it when |
|---|---|
| [Getting started](getting-started.md) | You are adding the package to an app |
| [Customization](customization.md) | You want it to look like your app |
| [Streaming and incremental rendering](streaming.md) | You are rendering a reply as it generates or tuning performance |
| [Inline syntax](inline-syntax.md) | You need `@mention`, `#channel`, `:emoji:` or autolinks |
| [Custom components](custom-components.md) | Styles and builders are not enough |
| [Rendering architecture](rendering-architecture.md) | You are registering a block extension or working out which pipeline ran |
| [`GptMarkdown` options](api-options.md) | You need a constructor-default reference |
| [Testing](testing.md) | Your widget tests do not find what you expect |
| [Migration](../MIGRATION.md) | You are upgrading, or want what the next release changes |
| [Comparison with other renderers](comparison.md) | You are choosing between this and another Markdown package |
| [Performance baseline](performance-baseline.md) | You are comparing revisions of this package and need the cold first-paint record |
| [Native rendering measurements](rendering-profile-results.md) | You want profile-mode numbers rather than debug-VM ones |

> [!NOTE]
> Representative code from these guides is compiled by the test suite
> (`test/docs/snippets_test.dart`). It covers the public option and builder
> signatures; prose, links and examples are also checked during review.
>
> Numbers quoted as measurements come from recorded runs, not estimates —
> from the tests in `test/`, or from the benchmark harness the comparison
> and performance guides describe.

## The one rule

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

## Three things that catch people out

* A `WidgetSpan` nested inside another placeholder **does not paint on iOS**.
  The default link is text, so this only bites when the link itself is a widget
  — the deprecated `linkBuilder`, or an `inlineLinkBuilder` returning
  `details.asWidgetSpan(...)`. `InlinePattern` already excludes link labels; a
  `MarkdownComponent` subclass has to declare `scopes` to opt out. See
  [inline syntax](inline-syntax.md#scopes).
* **Changing a builder at runtime does nothing** — builders are not compared
  when deciding to re-render. See [testing](testing.md).
* **`find.text` rarely finds Markdown text** — prose renders as spans inside
  one paragraph widget. It does reach content that renders as its own widget,
  such as a code block. See [testing](testing.md).
