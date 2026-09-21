# Inline syntax

Autolinks, and app-specific tokens like `@mention`, `#channel` and `:emoji:`.

---

## Autolinks

Bare URLs, `www.` hosts, email addresses and `<…>` autolinks become links with
no pre-processing:

```dart
GptMarkdown(
  'Ship it: https://pub.dev or mail ada@example.com',
  onLinkTap: (url, title) => launchUrlString(url),
)
```

Bare autolinks follow the
[GFM autolink extension](https://github.github.com/gfm/#autolinks-extension-),
so the awkward cases come out right:

| Input | Links to |
|---|---|
| `see https://x.com.` | `https://x.com` — the period stays outside |
| `(https://x.com)` | `https://x.com` — unbalanced `)` stays outside |
| `https://en.wikipedia.org/wiki/Foo_(bar)` | the whole URL — parens balance |
| `www.example.com` | `http://www.example.com` |
| `ada@example.com` | `mailto:ada@example.com` |
| `**https://x.com**` | bold link, `**` never reaches the href |
| `` `https://x.com` `` | nothing — it stays code |

`<https://x.com>`, `<mailto:a@b.com>` and `<a@b.com>` follow CommonMark §6.5.

### Schemes

`http`, `https`, `mailto` and `xmpp` are linked bare. Anything else is opt-in:

```dart
GptMarkdown(text, autolinkSchemes: const {'myapp', 'slack'})
```

> [!NOTE]
> A bare `myapp://thing` in prose usually is not meant as a link, which is why
> it needs the allowlist. Angle autolinks accept **any** scheme without it —
> `<myapp://thing>` works — because the author wrote the brackets deliberately.

Turn it all off:

```dart
GptMarkdown(text, autolink: false)
```

Explicit `[label](url)` links keep working.

### Why this beats a pre-processor

> [!IMPORTANT]
> If your app rewrites bare URLs into `[url](url)` before rendering, **delete
> that step** or set `autolink: false`. Otherwise both run.

Removing it is the better fix. A pre-processor works on raw Markdown and has to
guess where the syntax ends and the URL begins — which is how
`**https://x.com**` becomes a link whose href ends in `**`.

Autolinking runs *after* the surrounding syntax is consumed: the parser claims
the `**` first and hands the autolinker a clean URL. That class of bug cannot
happen. The same holds for backticked URLs, headings and table cells.

---

## App-specific tokens

Chat apps layer their own inline syntax on top of Markdown. `#2959` is a
channel in one product, a topic in another, an issue in a third — so the
package supplies the mechanism and you supply the meaning.

> [!IMPORTANT]
> `InlinePattern` and `InlineDirective` are the current route, and they work on
> both parsers. The older route — an `InlineMd` subclass passed to
> `inlineComponents` — is deprecated in 1.3.0 and scheduled for removal in
> 2.0.0. It still works, but passing `inlineComponents` switches the whole
> widget to the legacy regex parser. See
> [custom components](custom-components.md#legacy-extension-points-deprecated-in-130)
> and [migration](../MIGRATION.md).

### A simple pattern

```dart
GptMarkdown(
  text,
  inlinePatterns: [
    InlinePattern(
      pattern: RegExp(r'(?<![\w-])GH-(\d+)\b'),
      builder: (context, match, style) => TextSpan(
        text: match.group(0),
        style: style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => openIssue(match.group(1)!),
      ),
    ),
  ],
)
```

Patterns are matched **ahead of** the built-in components, so a pattern beats
the default reading of the same text — a pattern whose regex covers `**GH-1**`,
asterisks and all, renders your chip rather than bold. Fenced code, registered
custom blocks and multi-line block maths are deliberate exceptions: their
content is not Markdown, and a pattern reaching inside would rewrite source the
author asked to see verbatim. Block maths is protected only while its closing
`\]` sits on a later line than the opening `\[`. Inside a one-line `\[ … \]` a
pattern still matches, and since the match is lifted out before parsing, the
maths renderer is handed the placeholder — the equation and the chip are both
lost.

On the deprecated legacy pipeline precedence is leftmost-match instead — a
built-in whose match starts at an earlier offset swallows the text, and the
pattern wins only when both start at the same offset.

> [!WARNING]
> A single-backtick code span is **not** one of those protected regions. On the
> default pipeline the match is lifted out of the source before the parser sees
> the backticks, so with a `GH-\d+` pattern `` `GH-123` `` renders neither the
> chip nor the literal text — the code chip shows the internal placeholder. The
> legacy pipeline gets this case right, because the code span starts first and
> claims the whole thing.

### Prefixed tokens

`@name` and `#channel` have a helper, because the boundary rules are fiddly —
an `@` inside an email and a `#` in a URL fragment must not match.

```dart
InlinePattern.prefixed(
  prefix: '#',
  knownNames: myChannelNames,          // ['general', 'design-review', …]
  builder: (context, match, style) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: ChannelChip(name: match.group(0)!.substring(1)),
  ),
)
```

Longer names win over shorter ones, so `#design-review` is not shadowed by a
`#design` entry. Matching is case-insensitive.

> [!WARNING]
> `genericTokenPattern` is optional, and leaving it **null** is usually right —
> then only the names you pass match.
>
> Supply one and every `#token` becomes a chip, including `#2959` when the
> author meant issue 2959. That is a real bug that shipped in a real app.

```dart
// Only known channels — recommended
InlinePattern.prefixed(prefix: '#', knownNames: channels, builder: …)

// Any token at all — chips for things that are not channels
InlinePattern.prefixed(
  prefix: '#',
  knownNames: channels,
  genericTokenPattern: r'[A-Za-z0-9_][A-Za-z0-9_-]*',
  builder: …,
)
```

### Emoji shortcodes

Shortcodes have their own helper, because `prefixed` cannot express them: it
has no closing delimiter, so `:tada:` would match `:tada` and leave a stray
colon behind.

```dart
const emoji = {'tada': '🎉', 'rocket': '🚀', 'fire': '🔥'};

InlinePattern.delimited(
  open: ':',                    // close defaults to open
  knownNames: emoji.keys,
  builder: (context, match, style) {
    final name = match.namedGroup('name');
    final glyph = name == null ? null : emoji[name];
    if (glyph == null) {
      return TextSpan(text: match.group(0), style: style);
    }
    return TextSpan(text: glyph, style: style);
  },
)
```

The token name is the named group `name`, and also group 1 — whatever groups
your own `genericTokenPattern` contains.

Boundaries come with it: `10:30:45` and `http://host:8080/x` are not claimed,
`:tada:xyz` is not a shortcode, and `:fire::fire:` matches twice.

Emoji are characters, so a `TextSpan` works — selectable, wrapping, on the
baseline. Reach for a `WidgetSpan` only when the glyph is a real icon or image:

```dart
InlinePattern.delimited(
  open: ':',
  knownNames: iconTable.keys,
  builder: (context, match, style) {
    final name = match.namedGroup('name');
    final icon = name == null ? null : iconTable[name];
    if (icon == null) {
      return TextSpan(text: match.group(0), style: style);
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      // Sized off the surrounding style, not a constant, so it stays
      // proportional when the paragraph's text style changes.
      child: Icon(icon, size: (style.fontSize ?? 14) * 1.15),
    );
  },
)
```

> [!TIP]
> Return the raw `match.group(0)` when the name is not in your table, as both
> examples do. Skip that branch and an unknown `:shrug:` renders as an empty
> gap instead of as the text the author typed.

`delimited` also handles asymmetric and multi-character delimiters —
`::spoiler::`, `{{token}}`, `|redacted|`:

```dart
InlinePattern.delimited(open: '{{', close: '}}', knownNames: …, builder: …)
```

### Prefer a TextSpan

> [!TIP]
> A `TextSpan` stays selectable, wraps across lines and sits on the baseline. A
> `WidgetSpan` does none of those. Use a widget only when the design genuinely
> needs one — a rounded chip with an icon, say.

Widgets returned from a pattern builder are handled correctly at raised text
scales: the package wraps them so they do not scale twice.

---

## Protected host data with `InlineDirective`

Use `InlinePattern` when the custom syntax is still ordinary text. Use
`InlineDirective` when a delimited payload must reach your builder verbatim and
must never be interpreted as Markdown.

For example, a server may insert a private marker containing JSON that the app
turns into a widget:

```dart
const widgetOpen = '\u{E200}widget\u{E202}';
const widgetClose = '\u{E201}';

GptMarkdown(
  reply,
  inlineDirectives: [
    InlineDirective(
      open: widgetOpen,
      close: widgetClose,
      builder: (context, payload, style) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: EmbeddedCard.fromJson(payload),
      ),
    ),
  ],
)
```

A directive is removed before either Markdown parser runs, carried through the
document as inert data, and restored at render time. Characters such as `**`,
backticks, `~~`, links and JSON punctuation inside the payload remain intact.

Choose delimiters that ordinary model output cannot produce accidentally.
Private Use Area code points are a practical choice when your server inserts
the markers after generation.

During streaming, a directive is built only after its closing delimiter
arrives. An incomplete directive stays literal rather than producing a
half-built widget. Directives are read on both parsers and never require you to
pass a component list, so they do not force the legacy parser the way
`inlineComponents` does.

Do not use a directive for mentions, channels, emoji, or syntax that should
participate in Markdown nesting. Those belong in `InlinePattern`.

---

## Scopes

Markdown nests: a link label can contain bold text, a table cell can contain a
link. A component declares where it applies.

| Scope | Where |
|---|---|
| `content` | ordinary document and inline text |
| `linkLabel` | inside the `label` of `[label](url)` |
| `tableCell` | inside a table cell — legacy pipeline only |
| `heading` | inside a `#` heading |

`linkLabel` and `heading` are set by both pipelines, `tableCell` by the legacy
one alone. The default parser renders a cell with the scope the table inherited,
which for a block-level table is `content` — so a pattern restricted to
`{MarkdownScope.tableCell}` never fires there, and one restricted to
`{MarkdownScope.content}` still does.

`InlinePattern` defaults to `MarkdownComponent.allScopesExceptLinkLabel`.

> [!WARNING]
> That default matters whenever the link itself is a widget. The default link
> rendering is a `LinkTextSpan` — real text — so a pattern nested in a label is
> no longer nested in a placeholder. But a link *does* become a `WidgetSpan`
> when you supply the deprecated `linkBuilder`, or when an `inlineLinkBuilder`
> returns `details.asWidgetSpan(...)`. A pattern returning a second placeholder
> inside one of those produces a **nested placeholder, which does not paint on
> iOS** — the text is simply invisible, with no error.
>
> `[#design](https://example.com)` was blank on iOS for exactly this reason,
> back when every link was a placeholder.
>
> The default is left as `allScopesExceptLinkLabel` regardless: changing it is
> a behaviour change with its own tests
> (`test/regression/nested_link_label_widget_test.dart`).

Opt back in when your builder returns a `TextSpan`, which is safe to nest:

```dart
InlinePattern(
  pattern: RegExp(r'GH-\d+'),
  builder: (context, match, style) => TextSpan(text: match.group(0)),
  scopes: MarkdownComponent.allScopes,
)
```

Restrict further when a token only makes sense in prose:

```dart
scopes: const {MarkdownScope.content},
```

That keeps the pattern out of headings and link labels. It does not keep it out
of table cells on the default pipeline, where a cell is `content` already.

---

## Common mistakes

> [!WARNING]
> **A generic `#` fallback.** It turns issue numbers, hex colours and headings
> written mid-sentence into chips. Match known names only unless you have a
> reason not to.

> [!WARNING]
> **Rebuilding the pattern list every frame.** The list is compared by element
> identity, so a fresh list regenerates every span on every build. Cache it in
> a field or make it `const`.

> [!TIP]
> **Anchor with lookarounds, not `^`/`$`.** Patterns are matched against the
> document, not a line, so `^` will not do what you expect. Use
> `(?<![\w-])` and `\b` to define boundaries.
