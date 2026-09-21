# Streaming and incremental rendering

Rendering a reply while the model is still generating it.

## The shape

Streaming is **data, not a `Stream`**. Rebuild `GptMarkdown` with the complete
text received so far and tell it whether more content may arrive:

```dart
class ReplyView extends StatefulWidget {
  const ReplyView({super.key, required this.stream});
  final Stream<String> stream;

  @override
  State<ReplyView> createState() => _ReplyViewState();
}

class _ReplyViewState extends State<ReplyView> {
  final _buffer = StringBuffer();
  bool _generating = true;

  @override
  void initState() {
    super.initState();
    widget.stream.listen(
      (chunk) => setState(() => _buffer.write(chunk)),
      onDone: () => setState(() => _generating = false),
      onError: (_) => setState(() => _generating = false),
    );
  }

  @override
  Widget build(BuildContext context) => GptMarkdown(
    _buffer.toString(),
    animation: GptMarkdownAnimation.fade,
    blockAnimation: GptMarkdownBlockAnimation.fadeIn,
    isStreaming: _generating,
  );
}
```

Keep the same widget identity while the reply grows. Giving every chunk a new
key remounts the renderer and discards its reveal position and caches.

## `incremental` (deprecated in 1.3.0)

> [!IMPORTANT]
> `incremental` is deprecated. plusparse is the default and passing the
> argument is no longer necessary. It keeps working until 2.0.0; the migration
> is to delete it. See [MIGRATION.md](../MIGRATION.md).

`incremental` defaults to `true`. It selects the single-pass plusparse parser
and a segment-cached renderer:

```text
message
├── settled heading       → cached
├── settled paragraph     → cached
├── settled table         → cached
└── changing tail         → rebuilt
```

The source is split into top-level segments at safe blank lines. A blank line
inside fenced code or block maths is not a split point. When text is appended,
unchanged segments keep their parsed spans and settled widget instances; only
changed segments need parsing and rendering. Source normalization, prefix
comparison, and segment reconciliation still depend on document size; a long
unfinished block still grows in cost. During animation, segmentation and counts
are reused and only the active reveal window receives tick notifications.

For document-scale scrolling, use `SliverGptMarkdown` to create segment widgets
on demand. See [rendering architecture](rendering-architecture.md) for extension
registration, lazy rendering, and optional large-table/code policies.

This optimization is useful even without animation:

```dart
GptMarkdown(
  streamedText,
  animation: GptMarkdownAnimation.none,
)
```

There is no need to fake a disabled animation with an extremely high
`charactersPerSecond` value.

### Legacy compatibility

Set `incremental: false` to select the older combined-regex renderer — also
deprecated, and the only reason to reach for it is to compare the two. This is
primarily an escape hatch for compatibility testing.

Supplying custom `components` or `inlineComponents` also selects the legacy
pipeline because consumer-defined regex components cannot be represented by
the built-in AST. `InlinePattern` and `InlineDirective` work on the incremental
pipeline and do not require that fallback.

An active character reveal uses the incremental renderer whenever custom
components do not prevent it, even if `incremental` is false. The reveal needs
the parsed span tree so it can animate existing text without reparsing Markdown
on every frame.

## Performance

There are two separate improvements.

### Parser speed

The package benchmark compares the legacy recursive combined-regex parser with
plusparse doing equivalent source-to-renderable-structure work:

| Scenario | Measured speedup |
|---|---:|
| Dense inline syntax | about **4x** |
| Typical AI reply | about **3.3x** |
| Block-heavy document | about **3.4x** |
| Large 35 KB document | about **6.4x** |
| Re-parsing streamed prefixes | about **8.7x** |

Measured on Flutter 3.44.2 / Dart 3.12.2, macOS.

**These figures were wrong twice before, both times too high, and the reason is
worth recording.** The first set (20x, 32x, 54x, 69x) predated the legacy
parser caching its anchored dispatch regexes; a cheaper denominator shrank
them to 15x, 23x, 36x and 48x. Those were still wrong, for a larger reason:
the benchmark timed `Plusparse.parse`, which stops at the AST, against a
legacy call that also built the `InlineSpan` tree. Unequal work inflates every
ratio. The benchmark now runs `PlusparseRenderer.render` on both sides and
asserts they produce the same visible text, so the comparison cannot drift
apart again without the test failing.

Run it locally:

```bash
flutter test test/plusparse/plusparse_benchmark_test.dart
```

### Streaming rebuild work

The widget benchmark repeatedly appends 30 Markdown chunks. Over three runs
on Flutter 3.44.2 / Dart 3.12.2, segment caching recorded **5.6x to 6.1x**
less total rebuild and layout work than the single-text pipeline, while
reusing every unchanged segment by identity:

```bash
flutter test test/plusparse/incremental_test.dart
```

These are debug-VM measurements, not device guarantees. Absolute times vary by
machine, Flutter version and document shape. The meaningful results are the
relative parser speed and the fact that incremental append cost does not grow
with the whole message.

## Character animations

`animation` controls how prose arrives. It defaults to `none`.

| Value | Behaviour |
|---|---|
| `GptMarkdownAnimation.none` | Shows content immediately; no reveal ticker |
| `.typewriter` | Reveals paced characters at their final appearance |
| `.fade` | Fades newly revealed text from transparent |
| `.blurIn` | Resolves new text out of a blur while fading in |
| `.wave` | Sends an accent-colour crest across new characters |

`typewriter` controls only visibility and pacing. `fade` and `blurIn` style
word-sized runs to preserve shaping, kerning and stable wrapping. `wave` is the
only effect that needs neighboring characters styled independently.

## Block animations

Tables, fenced code, block maths, rules and images are laid-out widgets. They
cannot reveal meaningful partial text, so `blockAnimation` controls their
one-shot entrance separately:

| Value | Behaviour | Changes layout height? |
|---|---|:---:|
| `GptMarkdownBlockAnimation.none` | Appears immediately | No |
| `.fadeIn` | Fades in at full size | No |
| `.growIn` | Expands vertically while fading | **Yes** |
| `.slideUp` | Rises slightly while fading | No |
| `.scaleIn` | Scales from slightly smaller while fading | No |

The two axes compose:

```dart
GptMarkdown(
  streamedText,
  animation: GptMarkdownAnimation.blurIn,
  blockAnimation: GptMarkdownBlockAnimation.slideUp,
  isStreaming: generating,
  charactersPerSecond: 300,
  revealFadeSeconds: 0.25,
  blockAnimationDuration: const Duration(milliseconds: 200),
  blockAnimationCurve: Curves.easeOut,
)
```

Block entrances are independent of the character effect and can be used with
`animation: none`. They play once when a new atomic block arrives; rebuilding
a settled message or scrolling it through a lazy-list cache boundary does not
replay them. They require the incremental renderer, so custom component lists
that select the legacy pipeline do not get these entrances.

## Tuning

`charactersPerSecond` defaults to 300. It is a baseline, not a hard limit. If
the backlog would take too long to clear, the reveal accelerates automatically
so it does not fall progressively behind a fast model.

`revealFadeSeconds` defaults to 0.25. It controls how long a newly revealed
character takes to settle after the reveal head passes. It does not change the
head's base speed and has no visual effect on `typewriter`.

`blockAnimationDuration` defaults to 200 milliseconds, and
`blockAnimationCurve` defaults to `Curves.easeOut`.

When `isStreaming` changes from true to false, any backlog fast-forwards rather
than continuing at the reading pace. Replacing the text instead of extending
it is treated as a regenerate or branch switch and starts a new reveal.

## Existing and incomplete content

Text already present when the renderer mounts is shown immediately. This keeps
history messages, restored conversations and live replies recreated by a lazy
list from replaying their animation. Only content appended after mount enters
through the reveal.

The reveal holds unfinished inline Markdown briefly so readers do not see text
change style after it has appeared. This applies to constructs such as bold,
inline code, links and inline maths. An open fenced-code block continues to
stream as code, while incomplete block maths waits for its closing delimiter.
The hold releases after a quiet period so a genuinely unmatched delimiter
cannot hide the end of a response forever.

## Why `isStreaming` matters

Set `isStreaming` to false for completed and historical messages:

```dart
GptMarkdown(
  message.text,
  animation: GptMarkdownAnimation.fade,
  isStreaming: message.isGenerating,
)
```

It tells the renderer when to fast-forward the remainder and stop its ticker.
Always clear it on normal completion and error paths. Leaving it true does not
disable segment caching, but it can leave reveal machinery waiting for content
that will never arrive.

## Accessibility and interaction

When `MediaQuery.disableAnimationsOf(context)` is true, content renders
immediately and no reveal ticker runs. No additional configuration is needed.

While text is still arriving, the incremental renderer publishes the document
as one semantics node and excludes the blocks beneath it. The collapse does
not depend on an assistive service being attached; only the label — the reply
so far — does. A link does not report itself as a link mid-stream, and no
heading or list item is separately navigable. The structure returns once the
source has been quiet for 250 ms and any reveal in flight has landed, its head
at the end of the text and its tail finished fading. Both have to hold: a
reveal still catching up keeps the document collapsed past the quiet period.
Otherwise every block on screen re-publishes its node on every frame, which is
an announcement storm for anyone listening and, with an assistive service
attached, about half the per-chunk cost of a long reply.

The trigger is text observably arriving: a reveal in flight, or source that
just grew by append. It is deliberately not `isStreaming`, which defaults to
true and which hosts routinely leave on, and not the animation mode — the
collapse happens with `animation: none` too. The legacy pipeline does not do
this.

Selection is not a stable interaction while a reveal is actively rebuilding
its live spans. It is available normally once the reply settles. Links and
other interactions in settled content remain ordinary widgets.

Incremental rendering optimizes one `GptMarkdown` instance. It cannot prevent a
parent chat list from rebuilding every bubble on each token. Keep streaming
state local to the active message where possible.

For auto-scroll, pin to the bottom only while the reader is already there. A
forced jump on every chunk fights both reading and block entrances.

## Trying it

```bash
cd example && flutter run -d macos -t lib/streaming_demo.dart
```

The demo lets you vary model and reveal speed, stop generation to see
fast-forwarding, and compare animation modes.
