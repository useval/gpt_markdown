# Rendering architecture and performance

The legacy regex parser remains supported. Existing `components`,
`inlineComponents`, and `incremental: false` retain their routing, though all
three are deprecated in 1.3.0 and removed in 2.0.0. There is no
required migration for widget/legacy-component integrations and no new runtime
dependency. Direct AST consumers using exhaustive switches over sealed MdNode
must add a case for the new MdCustomBlock variant.

## Modern pipeline

1. Normalize input and protect inline directives/patterns.
2. Retain settled segment strings; on append, re-split the previous tail and
   appended text. Arbitrary edits fall back to a full split.
3. Cache pure-Dart `MdDocument` trees separately from styled spans.
4. Build styled spans once per changed segment and rendering configuration.
   Identical source can share its AST, but widget-bearing spans are cached by
   position as well as source to avoid sharing keys and controllers.
5. Render block widgets directly where possible, and prose as rich text.
6. Cache rendered character counts. Reveal ticks notify only the segments
   intersecting the active reveal/fade window; crossing a segment boundary
   updates the document column. Hidden segments retain their spans.

Theme changes invalidate presentation, not parsing. A quote or heading builds
its styled content once, and reveal counting uses that exact content. Nested
quotes no longer render duplicate subtrees for counting. Tables own their
scroll controllers in widget state, retaining scroll state during appends and
disposing controllers on unmount.

`PlusparseRenderer.renderDocument(context, document, config)` is available when
an integration already has an AST. `render(context, source, config)` remains
available and does parsing plus rendering. For custom blocks, pass a registry
to `Plusparse.parse` and matching `blockComponents` to the render config.

## Extending syntax

Use `blockComponents` for new block syntax and `inlinePatterns` or
`inlineDirectives` for inline syntax. See [custom components](custom-components.md).
The block registry dispatches by first character and opening prefix rather than
trying every extension at every character. Syntax produces a pure-Dart payload;
its Flutter builder owns presentation. No central renderer switch edits are
needed for new custom block types.

Component lists and parsed payloads must be treated as immutable. Keep lists
and component instances stable across normal builds; replace entries when
syntax or builder behavior changes. A replacement invalidates the relevant
caches. Existing legacy callback-cache semantics are unchanged.

## Long documents

For a long answer in its own scrollable viewport, use the sliver path below.
Putting ordinary `GptMarkdown` inside `SingleChildScrollView` still builds and
lays out the entire answer at mount. The sliver path postpones offscreen work
until the reader scrolls toward it. It is an explicit integration choice because
it changes scrolling, selection extent, and character-reveal behavior.

```dart
SelectionArea(
  child: CustomScrollView(
    slivers: [
      SliverGptMarkdown(
        document,
        config: GptMarkdownConfig(
          style: TextStyle(fontSize: 16),
        ),
      ),
    ],
  ),
)
```

`SliverGptMarkdown` segments the document eagerly, but creates spans and widgets
only when the viewport requests a segment, including its cache extent. Custom
syntax matchers also run during segmentation to identify opaque block boundaries. It has
no independent scroll controller and composes with other slivers. Source updates
appear immediately; character reveal remains on `GptMarkdown`. Offscreen
segments can be disposed and rebuilt, and selection covers mounted content.
Legacy component lists use a single `SliverToBoxAdapter` to preserve their
whole-document semantics; that fallback is not viewport-lazy.

A giant individual paragraph, list, table, or code fence remains one segment.
Neither API virtualizes rows inside a table or lines inside a fence. Blank-line
segmentation retains its existing loose-list limitations. New custom syntaxes
must consume their complete block, including internal blank lines.

## Large tables and streaming code

These optional policies trade content-based column sizing and live syntax
coloring for lower update cost, without changing existing defaults:

```dart
GptMarkdown(
  source,
  styleSheet: const GptMarkdownStyleSheet(
    table: TableStyle(columnWidth: FixedColumnWidth(160)),
    codeBlock: CodeBlockStyle(highlightWhileStreaming: false),
  ),
)
```

Fixed widths skip intrinsic column measurement. The default still sizes columns
to content using its existing measurement behavior. This is necessary for custom
cells containing LayoutBuilder, which cannot answer intrinsic-size queries. The
built-in table scrolls horizontally and has unbounded horizontal
constraints, so use fixed widths rather than flex widths there.

Deferred highlighting displays all current code as plain monospace text while
the fence is open and highlights when its closing fence arrives. An input that
never closes remains plain. Custom `codeBuilder` implementations control their
own highlighting; this policy only affects the default code widget.

## Measuring

See [native profile results](rendering-profile-results.md) for representative
cold mounts and the distinction between eager rendering and first-screen work.

```sh
flutter test --no-pub tool/benchmarks/render_architecture_benchmark_test.dart
flutter test --no-pub test/regression/render_work_reuse_test.dart
```

The benchmark uses APIs supported before this refactor so the same file can be
run against an isolated original revision. It measures nested-quote construction
and actual animation ticks while source is unchanged. Deterministic tests pin
builder counts, segment reuse, theme invalidation, and viewport-lazy rendering.

Debug widget-test timings are diagnostics, not production frame budgets. Use
profile builds on representative target devices with recorded source/chunk
sequences to measure build and raster durations separately. Include cold mounts,
appends, reveal backlogs, long unbroken blocks, tables, math, selection, and RTL.
Source normalization, prefix comparisons and metadata reconciliation still do
work proportional to document size on updates; do not claim constant-time
streaming or a universal speedup.

## Reference measurements

On macOS with Flutter 3.44.2 / Dart 3.12.2, the same benchmark file was run
against original revision `5f92914` and this refactor in separate processes.
These are one-run debug host averages, not device frame-time guarantees:

| Workload | Original | Refactor |
| --- | ---: | ---: |
| Depth-10 quote, source to spans | 2,573 µs | 231 µs |
| Inline builder calls for one element in that quote | 1,024 | 1 |
| Reveal backlog, average tick/pump | 3,828 µs | 3,162 µs |
| Redundant inline builds during 40 backlog ticks | 827 | 0 |

The quote workload deliberately exercises pathological nesting. Its roughly
11x timing improvement is not a claim about ordinary chat replies. The backlog
timing includes Flutter layout/paint and the test harness, so eliminating all
redundant source work does not eliminate the rest of a frame's cost.
