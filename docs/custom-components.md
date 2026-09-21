# Custom components

For syntax the package does not know about.

> [!TIP]
> Reach for this **last**. For `@mention`-style tokens use
> [`InlinePattern`](inline-syntax.md) — no subclassing, and it gets the nesting
> rules right for free. For appearance use a
> [style object](customization.md). A custom component is for genuinely new
> syntax.

> [!IMPORTANT]
> 1.3.0 deprecates the legacy regex extension points: the `components` and
> `inlineComponents` widget arguments, the `InlineMd` and `BlockMd` base
> classes, and the `MarkdownComponent.globalComponents` and
> `MarkdownComponent.inlineComponents` lists. They keep working exactly as they
> did and are scheduled for removal in 2.0.0, but nothing new should be written
> against them. [Migration](../MIGRATION.md) has the before and after.

| What you are adding | Current route | Deprecated route |
|---|---|---|
| A block syntax | `blockComponents`, with `MarkdownBlockComponent` | `components`, with a `BlockMd` subclass |
| An app-specific inline token | `inlinePatterns`, with `InlinePattern` | `inlineComponents`, with an `InlineMd` subclass |
| A delimited payload that must not be parsed | `inlineDirectives`, with `InlineDirective` | — |

The difference is not only spelling. Passing `components` or `inlineComponents`
— even an empty list — switches the widget to the legacy regex parser, which
ignores `blockComponents` and gives up the incremental segment cache, the
span-level streaming reveal and lazy sliver rendering. `incremental: false` does
the same. The current route keeps all three.

---

## A block component

`blockComponents` registers a syntax and its renderer without switching off the
default parser or its segment caches.

```dart
// Keep this list in a field, rather than recreate it on every streamed chunk.
final blocks = <MarkdownBlockComponent>[
  MarkdownBlockComponent(
    syntax: const FencedBlockSyntax(
      type: 'warning',
      opening: ':::warning',
      closing: ':::',
    ),
    builder: (context, node, config) => Container(
      padding: const EdgeInsets.all(12),
      color: Colors.amber.shade100,
      child: Text(node.body, style: config.style),
    ),
  ),
];

GptMarkdown(source, blockComponents: blocks);
```

This recognizes `:::warning` on its own line through a closing `:::` line.
Blank lines stay inside the block, and `node.closed` is false while incomplete.
The body is opaque to inline patterns, directives, and dollar-math rewriting;
same-fence nesting is not interpreted. Custom blocks are
atomic for character reveal and can use the existing `blockAnimation` entrance.

For another grammar, subclass `MarkdownBlockSyntax`, supply a nonempty `type`
and `prefix`, and return `MarkdownBlockMatch(node: MdCustomBlock(...),
endLine: exclusiveEnd)`. Return null to decline a match. The parser must be pure,
handle incomplete input, consume at least one line, and inspect only its consumed
region. An unfinished container should consume all remaining lines. Store any
extra immutable parsed data in `node.data`; the builder consumes it without
reparsing. Registrations must have unique types. Rules are tried in registration
order before built-ins, gated by their opening prefixes, and a match interrupts
an open paragraph — no blank line is needed before `:::warning`. Built-in
code-fence bodies remain opaque.

The registry is intentionally for local block syntax. Cross-document rules such
as a later definition changing earlier blocks need a different invalidation
strategy and should not be implemented by secretly inspecting other segments.
Treat registered lists as immutable and replace component entries when behavior
changes. See [rendering architecture](rendering-architecture.md) for caching and
long-document rendering.

## An inline component

Inline syntax needs no component and no subclass. `InlinePattern` takes a regex
and a builder, works on both pipelines, and defaults to excluding link labels —
the nesting rule that is easiest to get wrong by hand.

```dart
// Keep this in a field too: pattern lists are compared by element identity.
final shout = <InlinePattern>[
  InlinePattern(
    pattern: RegExp(r'!![A-Za-z]+!!'),
    builder: (context, match, style) => TextSpan(
      text: match.group(0)!.replaceAll('!!', '').toUpperCase(),
      style: style.copyWith(fontWeight: FontWeight.bold),
    ),
  ),
];

GptMarkdown('This is !!important!! text.', inlinePatterns: shout);
```

`InlinePattern.prefixed` and `InlinePattern.delimited` already carry the
boundary rules for `@name`, `#channel` and `:emoji:`. Use `inlineDirectives`
when a delimited payload has to reach the builder verbatim and must never be
read as Markdown. [Inline syntax](inline-syntax.md) covers both, including
scopes and the `WidgetSpan` rules.

---

## Legacy extension points (deprecated in 1.3.0)

Everything in this section still works and behaves as it did in 1.2.x. It is
documented so that a codebase already on it can understand what it has; it is
not the route to take for new syntax, and removal is scheduled for 2.0.0.

Passing either `components` or `inlineComponents` selects the legacy parser. If
`blockComponents` is also supplied, the legacy lists take precedence and the
modern block extensions are ignored. Explicit `incremental: false` selects the
legacy parser too, as long as span reveal is off — an `animation` other than
`GptMarkdownAnimation.none` forces the modern path back on, because that is the
only pipeline the span-level reveal exists on. Modern block extensions
supplement the built-ins; a legacy component list replaces them, as below.

### The two legacy lists

```dart
GptMarkdown(
  text,
  components: [...],        // block pass: headings, lists, tables, fences
  inlineComponents: [...],  // inline pass: bold, links, code, images
)
```

> [!WARNING]
> Passing a list **replaces** the defaults. Build on top of them or you lose
> every built-in construct:

```dart
// Wrong — bold, links and code stop working
inlineComponents: [MyComponent()],

// Right
inlineComponents: [MyComponent(), ...MarkdownComponent.inlineComponents],
```

`MarkdownComponent.globalComponents` is the same list for the block pass. Both
are deprecated alongside the arguments they are spread into.

### An inline component with `InlineMd`

Say you want `!!shout!!` to render in caps. On the current route this is the
`InlinePattern` above; the legacy equivalent is a subclass:

```dart
class ShoutMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'!![A-Za-z]+!!');

  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    return TextSpan(
      text: text.replaceAll('!!', '').toUpperCase(),
      style: config.style?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
```

```dart
GptMarkdown(
  'This is !!important!! text.',
  inlineComponents: [ShoutMd(), ...MarkdownComponent.inlineComponents],
)
```

`text` is the whole matched string, so re-run your regex if you need groups:

```dart
final match = exp.firstMatch(text);
final inner = match?.group(1) ?? text;
```

### A block component with `BlockMd`

Extend `BlockMd`, override `expString` and return a widget. The current route
for the same callout is a `FencedBlockSyntax` on `blockComponents`, which keeps
the segment cache and does not need the body re-parsed by a nested widget:

```dart
class CalloutMd extends BlockMd {
  @override
  String get expString => r':::(\w+)\n([\s\S]*?)\n:::';

  @override
  Widget build(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    final match = exp.firstMatch(text);
    final kind = match?.group(1) ?? 'note';
    final body = match?.group(2) ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(kind == 'warning' ? Icons.warning : Icons.info),
          const SizedBox(width: 8),
          // Render the body as Markdown too, in the host's direction.
          Flexible(
            child: GptMarkdown(
              body,
              style: config.style,
              textDirection: config.textDirection,
            ),
          ),
        ],
      ),
    );
  }
}
```

A nested `GptMarkdown` installs a `Directionality` of its own around everything
it renders, and `textDirection` defaults to `TextDirection.ltr`. Leave it out
and the callout body flips back to LTR inside an RTL document. Pass
`config.textDirection` down, as the built-in block components do.

### Legacy rules that are easy to miss

These follow from how the legacy parser works: one combined regex built out of
the whole component list, and a subclass that has to declare by hand what
`InlinePattern` already handles.

#### Declare your scopes

```dart
@override
Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;
```

> [!WARNING]
> Without this a component fires **everywhere**, including inside link labels.
> If it returns a `WidgetSpan`, that nests a placeholder inside the link's own
> placeholder — which **does not paint on iOS**. The text is invisible, with no
> error and nothing in the logs.

`InlinePattern` defaults to `allScopesExceptLinkLabel` already.

#### Order matters twice

List order decides two different things: which alternative the combined regex
matches at a given position, and which handler claims the match. Earlier wins
both times, so **prepend** to override:

```dart
inlineComponents: [MyLinkMd(), ...MarkdownComponent.inlineComponents],
```

#### Inline widgets need scale compensation

> [!WARNING]
> A paragraph lays inline children out in scaled space — it hands them
> `maxWidth / scale` and multiplies the reported size back. A child that also
> scales its own text is counted twice, and at a 2× system font setting can
> reserve **many times** the space it needs.

```dart
// Wrong at raised text scales
return WidgetSpan(child: MyChip());

// Right
return WidgetSpan(child: MediaQuery.withNoTextScaling(child: MyChip()));

// Also right, and baseline-aligned
return baselineWidgetSpan(MyChip());
```

`InlinePattern` does this for you.

#### Case sensitivity is contagious

The combined regex carries one set of flags. One component declaring
`caseSensitive: false` makes the whole alternation case-insensitive — required
for it to match at all, but be aware it affects the others.

---

## Rules that apply either way

### Return the source on failure

A builder that gives up has to hand back the text the author typed, or it
vanishes from the document with no warning:

```dart
// Wrong
if (match == null) return const TextSpan();

// Right, in an InlineMd subclass
if (match == null) return TextSpan(text: text, style: config.style);

// Right, in an InlinePattern builder
if (glyph == null) return TextSpan(text: match.group(0), style: style);
```

The package does the same for malformed links.

### Cache the list

> [!WARNING]
> `inlinePatterns`, `blockComponents` and the legacy component lists are all
> compared by element identity. Building one inline in `build` creates new
> instances every frame, regenerating every span.

```dart
// Wrong
GptMarkdown(text, inlinePatterns: [InlinePattern(...)])

// Right
late final _patterns = [InlinePattern(...)];
GptMarkdown(text, inlinePatterns: _patterns)
```

### Text scaling for components

The rendering pipeline owns scaling at the paragraph boundary. Standalone
blocks inherit the document's `MediaQuery.textScaler`; a `WidgetSpan` child
receives disabled ambient scaling because Flutter scales its entire box.
This applies to built-in blocks, custom block renderers, inline patterns and
inline directives. Nested blocks retain the same rule.

Return `Text` with the original font size from custom builders. Do not capture
the outer context's scaler and apply it again to a widget inside a paragraph.
For custom painters or math engines that do not use `Text`, resolve glyph sizes
at widget build time with `MarkdownTextScaling.fontSize(context, baseSize)`.
That helper uses the effective scaler below the boundary and supports nonlinear
scalers. Images and decorations are not text; fixed block padding, borders and
control icon sizes need not grow with the font.

---

## Testing a component

```dart
testWidgets('renders in caps', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GptMarkdown('a !!loud!! word', inlinePatterns: shout),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Markdown renders as spans, not Text widgets — read the span tree.
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    buffer.write(rt.text.toPlainText(includePlaceholders: false));
  }
  expect(buffer.toString(), contains('LOUD'));
});
```

Add a case for your pattern or component **inside a link label**, since that is
the one that fails silently:

```dart
await tester.pumpWidget(/* … '[!!loud!!](https://x.com)' … */);
// With allScopesExceptLinkLabel it should stay literal, not become a chip.
```

More in [testing](testing.md).
