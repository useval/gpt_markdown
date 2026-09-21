# gpt_markdown benchmarks

`gpt_markdown` 1.3.0 introduces a new single-pass parser, incremental rendering,
and a lazy sliver for long output. This document measures the resulting gains
against 1.2.1 and two other Flutter Markdown renderers.

## Results at a glance

| Measurement | Result |
|---|---:|
| Parser vs the legacy parser | **3–9× faster** |
| Whole-frame rendering vs 1.2.1 | **Up to 2× faster** |
| Streaming at 12 KB with `GptMarkdown` vs 1.2.1 | **31× faster** |
| Streaming at 12 KB with `SliverGptMarkdown` vs 1.2.1 | **74× faster** |

These are debug-VM measurements on macOS, not device guarantees. Absolute
times vary by machine, Flutter version, viewport, and document shape. The
relative results and scaling behavior are the useful parts.

---

## 1. Compared with gpt_markdown 1.2.1

### Parser

Across the current package benchmark, the new parser is **3–9× faster** than
the legacy regex parser, depending on the document.

This is an equivalent source-to-renderable-span comparison: both sides include
parsing and inline span construction. It does not compare a completed legacy
span tree with only the new parser's intermediate AST.

Parser speed is only one part of a rendered frame. Structured output also
requires widget construction, layout, and paint, which is why the whole-frame
improvement is smaller than the parser-only improvement.

### Whole-frame rendering

Each result below is a cold mount that includes parsing, widget construction,
layout, and paint.

| Document | 1.2.1 | 1.3.0 | Improvement |
|---|---:|---:|---:|
| Short reply | 7.57 ms | 5.45 ms | **1.4×** |
| Long reply (5×) | 25.80 ms | 13.22 ms | **2.0×** |
| Structured document (20×) | 94.34 ms | 54.73 ms | **1.7×** |
| Prose reply | 1.54 ms | 0.89 ms | **1.7×** |
| Long-form prose | 9.47 ms | 5.23 ms | **1.8×** |

The parser represents roughly 4% of a frame for structured documents; most of
the remaining work is build, layout, and paint. On plain prose, parsing is a
larger share of the total cost.

### Streaming

This benchmark measures the cost of processing one additional chunk as the
visible reply grows. It was run twice; the table shows both observed ranges and
uses the more conservative ratio.

| Reply so far | 1.2.1 | `GptMarkdown` | vs 1.2.1 | `SliverGptMarkdown` | vs 1.2.1 |
|---|---:|---:|---:|---:|---:|
| 2 KB† | 5.3–7.5 ms | 0.7–2.0 ms | **3.8×** | 0.69–0.95 ms | **7.6×** |
| 6 KB | 14.1–17.1 ms | 0.80–1.09 ms | **16×** | 0.49–0.75 ms | **23×** |
| 12 KB | 32.0–38.4 ms | 1.01–1.24 ms | **31×** | 0.42–0.52 ms | **74×** |

In 1.2.1, each chunk re-parses and re-renders the complete reply, so the cost
rises with its length. In 1.3.0, settled segments are reused and the cost stays
approximately flat. `SliverGptMarkdown` also avoids building content outside
the viewport, so its measured work can fall as the document grows.

The 31× result reproduced closely across both 12 KB runs: 31.0× and 31.6×. The
2 KB result was less stable because it approaches the harness floor, so it is
marked † and should be read as directional.

Both versions were checked for equivalent visible output. At 12 KB, rendered
height agreed within 2.5%, the visible words were identical, and neither
renderer deferred work beyond the measured frame.

### Cold mounting by document length

One unit contains a heading, a wrapping paragraph with bold text, inline code
and a link, plus a two-item list. The viewport was 800 × 600.

| Document | 1.2.1 | `GptMarkdown` | `SliverGptMarkdown` |
|---|---:|---:|---:|
| 1 unit† | 2.14 ms | 1.39 ms | 1.38 ms |
| 4 units | 4.13 ms | **1.88 ms** | 3.07 ms |
| 20 units | 16.82 ms | 4.97 ms | **2.33 ms** |
| 60 units | 54.90 ms | 13.45 ms | **2.09 ms** |

The regular widget is cheaper for short content because a lazy sliver has setup
cost. The sliver becomes faster once the document extends well beyond the
viewport, then remains nearly flat because off-screen blocks are not built.

---

## 2. Compared with other Flutter renderers

The comparison used these versions:

| Package | Version |
|---|---:|
| **gpt_markdown** | 1.3.0 |
| **flutter_markdown_plus** | 1.0.12 |
| **markdown_widget** | 2.3.2+8 |

`flutter_markdown` is discontinued and directs users to
`flutter_markdown_plus`, so it was not measured separately.

### Finished-message cold mount

Each single-construct document repeats that construct ten times. Ratios are
medians of three same-session rounds. “2× faster” means the other renderer took
twice as long; “2× slower” means `gpt_markdown` took twice as long.

| Content | vs `flutter_markdown_plus` | vs `markdown_widget` |
|---|---:|---:|
| Links | **4.5× faster** | **7.2× faster** |
| Bullet lists | **3.1× faster** | **4.7× faster** |
| Plain prose | **2.4× faster** | **2.8× faster** |
| Headings | **1.5× faster** | **7.1× faster** |
| Mixed answer | 1.1× slower | **1.5× faster** |
| Small table | 1.7× slower | **1.6× faster** |
| 40-row table | **1.1× faster** | — |
| Code blocks | 2.9× slower | 2.5× slower |

Headings and prose showed the greatest run-to-run variation. Their observed
ranges were 0.90–1.71× and 1.99–3.98× respectively, so the direction is more
meaningful than the exact headline ratio.

### Streaming as the reply grows

These are raw elapsed times, including the empty-harness floor shown in the
last column. They are useful for comparing how each renderer scales; they
should not be treated as device-frame guarantees.

| Reply so far | `SliverGptMarkdown` | `GptMarkdown` | `flutter_markdown_plus` | `markdown_widget` | Empty harness |
|---|---:|---:|---:|---:|---:|
| 2 KB | 3.0 ms | 4.0 ms | 21.8 ms | 20.4 ms | 2.8 ms |
| 6 KB | 1.7 ms | 4.2 ms | 25.8 ms | 29.1 ms | 1.6 ms |
| 12 KB | **1.3 ms** | 3.4 ms | 49.3 ms | 57.0 ms | 1.2 ms |
| 18 KB | **1.0 ms** | 4.3 ms | 80.2 ms | 93.0 ms | 0.9 ms |

The two general-purpose renderers re-render the complete document on each
update, so their cost rises with reply length in this benchmark. Both
`gpt_markdown` widgets remain approximately flat; the sliver approaches the
harness floor after the content grows beyond the viewport.

### Tradeoffs

`gpt_markdown` is not fastest on every isolated construct:

- **Code blocks:** `gpt_markdown` performs syntax highlighting and includes a
  language label plus an accessible copy button. `flutter_markdown_plus` draws
  plain code by default; `markdown_widget` highlights but does not include the
  same controls. Setting `CodeBlockStyle(showCopyButton: false)` substantially
  reduces the code-block cost.
- **Small tables:** `gpt_markdown` sizes columns to their content, which
  requires additional measurement. `flutter_markdown_plus` divides available
  width without content measurement. On the measured 40-row table,
  `gpt_markdown` was 1.1× faster.

These differences reflect output and behavior as well as implementation cost,
so isolated rows should be evaluated alongside the features each renderer
produces.

---

## 3. Which widget to use

- Use **`GptMarkdown`** for chat messages, cards, and content up to a few
  screens. It has less setup overhead and supports character reveal.
- Use **`SliverGptMarkdown`** for long replies and documents inside a
  `CustomScrollView`. It builds only the segments requested by the viewport and
  its cache extent.

For an existing 1.2.1 integration, upgrading without switching widgets still
improves every measured document shape and keeps per-chunk streaming work
approximately flat.

---

## 4. Methodology and limitations

- Measurements were collected in the Flutter debug test VM on macOS. Compare
  ratios and scaling trends, not absolute milliseconds.
- The 1.2.1 and 1.3.0 renderers were loaded in the same process. The 1.2.1
  source was byte-identical to tag `v1.2.1`; only its package name and internal
  imports were changed so both versions could run together.
- Test order was counterbalanced, an empty harness was subtracted where stated,
  and a duplicate control was used to identify noisy runs.
- The sliver measurements used an 800 × 600 viewport. Different viewport and
  cache extents change how much content is built.
- Competitor benchmarks ran each package in an identical harness. Every tested
  document was checked for the same visible text and block count before its
  timings were accepted.
- Cold-mount and streaming results come from different harnesses and should
  only be compared within their own tables.
- `flutter test` runs the accessibility pipeline. A typical app without an
  active screen reader may do less work than these measurements show.
- † marks a result close enough to the harness floor that duplicate controls
  diverged materially. Treat those rows as directional.

Benchmarks are snapshots, not universal rankings. Hardware, Flutter versions,
document shape, styling, enabled controls, and application layout all affect
the result. Profile the configuration and content used by your product before
making performance-sensitive decisions.
