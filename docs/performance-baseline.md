# Performance baseline

Cold first-paint cost, in microseconds, for comparing revisions of this package.

## Where the harness lives

`benchmark/` — **untracked**, and listed in `.gitignore`. The files there assert
nothing, take minutes to run, and exist to compare revisions of this package
against each other rather than to guard behaviour. Keeping them out of `test/`
keeps them out of `flutter test` and CI; keeping them untracked keeps them out
of the published archive.

That means a fresh clone will not have them, and this table is the record. If
you need to reproduce or extend it, the method is written out below in enough
detail to rebuild the harness — the shape is a widget that mounts a document,
pumps it, tears the subtree down, and repeats.

```sh
flutter test benchmark/render_baseline_test.dart
```

To measure an older revision, drop the same file into a worktree of it. The
harness uses only `GptMarkdown(text)` with default arguments, which is the one
API that has existed unchanged across the package's history, so it runs on any
revision:

```sh
git worktree add -f --detach /tmp/wt <rev>
mkdir -p /tmp/wt/benchmark
cp benchmark/render_baseline_test.dart /tmp/wt/benchmark/
cd /tmp/wt && flutter pub get && flutter test benchmark/render_baseline_test.dart
```

## How to read this

**Compare a row against the same row on another revision. Never compare two
rows within one column.**

Pump timings drift downward through a process as the VM warms — measuring one
identical document five times in a row gave 8424, 6786, 5498, 5222, 4677 µs. So
whichever case runs first looks worst. Running the same file in the same order
on every revision cancels that out. Comparing row to row inside one run cancels
nothing, and doing exactly that produced two false conclusions while this table
was being built: a "superlinear interaction between constructs" and a "1.5x
regression on code fences". Both evaporated when the cases were measured in
isolation.

Each number is the **minimum of three separate runs**, each itself the minimum
of three rounds of twelve mount/unmount cycles, with an empty-harness pump
subtracted. Minimum rather than mean because the noise is one-sided.

Anything under ~300 µs is at or below the harness noise floor (the harness
itself is ~3000 µs and varies by a few percent). Those rows are marked `~0`;
treat them as "unmeasurable", not "zero".

## Results

Measured 2026-09-14, macOS, debug test VM. Absolute values are pessimistic —
a debug VM is not a release build — so use the ratios, not the milliseconds.

| case | `cd3ee62` old regex | `fea4edc` pre-change | span links | **blocks as widgets** |
|---|---:|---:|---:|---:|
| prose | ~0 | ~0 | ~0 | ~0 |
| links_80 | 10250 | 12194 | 1457 | **1202** |
| headings_40 | 2945 | 3719 | 5874 | **2538** |
| list_40 | 6659 | 7048 | 7110 | **6116** |
| table_x4 | 3192 | 3390 | 3862 | **2839** |
| fence_x4 | 5282 | 7027 | 7114 | **6110** |
| mixed_answer | 2407 | 4807 | 3614 | **2918** |
| stream_per_chunk | ~0 | 331 | 322 | **~0** |

Current against the revision this work started from (`fea4edc`):

| case | gain |
|---|---:|
| links_80 | **10.1x** |
| mixed_answer | **1.65x** |
| headings_40 | 1.47x |
| table_x4 | 1.19x |
| list_40 | 1.15x |
| fence_x4 | 1.15x |
| stream_per_chunk | ~0, from 331 µs |

Current against the original regex pipeline (`cd3ee62`), which had no syntax
highlighting, no code panel and no streaming:

| case | ratio |
|---|---:|
| links_80 | **8.5x faster** |
| headings_40 | 1.16x faster |
| table_x4 | 1.12x faster |
| list_40 | 1.09x faster |
| mixed_answer | 1.21x slower |
| fence_x4 | 1.16x slower |

The package is now at or ahead of where it started on every construct except
fenced code, and that gap is the syntax highlighting and the code panel that
`cd3ee62` did not draw at all.

### Revisions

- **`cd3ee62`** (2026-07-28) — before plusparse, before streaming. The original
  regex pipeline.
- **`fea4edc`** (2026-09-05) — plusparse, incremental rendering and the
  streaming reveal all landed; immediately before the span-link change.
- **span links** — links render as `LinkTextSpan` rather than `LinkButton` in
  a `WidgetSpan`.
- **blocks as widgets** — current. A block construct is lifted out of its
  paragraph and rendered as a sibling widget, skipping the placeholder and the
  nested `Text.rich` inside it.

## What the numbers say

**Links are 8.5x faster than they have ever been**, and 10x faster than the
revision this work started from.

**A mixed answer is 1.65x faster** than `fea4edc`, and now within ~20% of the
original regex pipeline while drawing far more: syntax highlighting, a code
panel, streaming, and an incremental view.

**The parser is not visible here, by design.** plusparse is 20–65x faster than
the regex pipeline at parsing, and parsing is 0.1–0.5% of cold first paint, so
it does not move any row. Confirmed by stage split: parse 0.1–0.5%, span build
2.4–6%, widget build + layout + paint 93–98%.

That is the whole lesson of this table. The cost was never the parser and never
the spans — it was that every block construct became a `WidgetSpan` holding a
nested `Text.rich`. A placeholder forces the paragraph to lay the child out as
its own `RenderBox` before it can shape a line, and the nested `Text.rich` is a
second full text-shaping pass. Two changes removed most of that:

- **Links render as text** (`LinkTextSpan`) instead of a widget in a
  placeholder. ~159 µs → ~17 µs per link.
- **Blocks render as sibling widgets** instead of placeholders inside a
  paragraph, when `maxLines` is null. Measured in isolation, A/B against the
  same document forced down the paragraph path: **headings 1.92x**, lists
  1.09x. Lists gain least because a list item's cost is its own widget — the
  bullet and its content paragraph — not the placeholder.

## Where the remaining cost is

| construct | cost each |
|---|---:|
| code fence | ~1640 µs of chrome, ~120 µs of highlighting |
| table | ~1100 µs |
| list item | ~220 µs |
| link | ~17 µs (was ~159 µs) |
| heading | ~63 µs (was ~145 µs) |
| paragraph | below noise |

**Fenced code is now the dominant cost**, and ~75% of it is chrome, not
highlighting: `Material` with a shape, an `IconButton` with a `Tooltip`, an
`AnimatedSwitcher` and a nested horizontal scroll view, all built at first
paint for a button nobody has touched yet. Deferring it is the next win, and
the reason it has not been taken is that a naive deferral costs touch
discoverability and the button's accessibility node.

## Constraints the block path is gated on

- **`maxLines`.** N paragraphs cannot share one line budget, so a document
  rendered as a column of widgets would give each block the full allowance.
  Verified: prose clamps 160 → 40 px with `maxLines: 2`, while a block document
  already does not clamp (152.2 → 152.2). The column path is therefore taken
  only when `maxLines` is null; otherwise the single-paragraph path stands.
- **Scaling has to come from the ambient `MediaQuery`.** A block inside a
  placeholder deliberately opts out of text scaling, because the paragraph
  holding it has already scaled it. Lifted out, there is nothing left to scale
  it — but handing it `textScaler` explicitly applies the scale twice, once to
  the glyphs and once to the width it wraps into, which measured 4x the correct
  height on a bullet list. Hence `GptMarkdownConfig.blocksRenderDirectly` and
  `getRich(ambientScaling:)`.
- Text scaling is otherwise **not** a blocker: a plain `Column` of `Text`
  scales 3.18x at a 2x setting against gpt_markdown's 3.13x.

## Known deliberate differences

A list is about **0.5 px per item shorter** on the incremental path than on the
regex path, because stacking items as widgets no longer pays the line-break
leading between them. Always tighter, never taller; pinned by
`test/block/checkbox_test.dart`.
