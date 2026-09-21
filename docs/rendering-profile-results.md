# Native rendering measurements

## Latest: paired cold rendering and lazy viewport

The final retained implementation was compared against baseline `5f92914`
in the **same native profile app**, with adjacent workloads and reversed order
on alternating rounds. No table-measurement experiment was retained.

| Cold workload | Original eager (ms) | Current eager (ms) | Current sliver (ms) | Original / sliver |
| --- | ---: | ---: | ---: | ---: |
| Short mixed answer, 1,485 characters | 1.698 | 1.661 | 1.802 | 0.94x |
| Long mixed answer, 8,920 characters | 10.384 | 9.695 | 2.269 | **4.58x** |
| Math answer, 845 characters | 1.677 | 1.654 | 1.774 | 0.95x |

These are medians of four rounds' median UI-plus-raster work per frame,
with eight warm-up mounts and forty measured mounts per round. The sliver
uses the same source, 16px style, 560px width, selection wrapper, and native
example window as the eager variants. Its CustomScrollView builds the initial
viewport plus its default cache extent; offscreen segments are deferred.
This is **first-screen work**, not a 4.58x claim for laying out the entire
document, scrolling through it, or end-to-end response latency.

The default eager path was 1.07x faster than the original in this run. Earlier
paired runs varied around parity, so the previous separate-process 16%
regression is not a reproducible diagnosis and the cache-overhead explanation
remains unproven. There is no evidence of a broad 2x eager-rendering improvement.

The substantial gain comes from using `SliverGptMarkdown` for long scrollable
answers. Short content and math showed small sliver overhead instead. Use
`GptMarkdown` when character reveal or the existing compact-widget integration
is needed. Sliver source updates are immediate, selection covers mounted
content, and legacy component lists fall back to eager rendering. Neither
parser was removed. See the [integration example](rendering-architecture.md#long-documents).

An intrinsic table-measurement candidate regressed timings and was removed.
A second candidate reduced child layout calls but did not demonstrate a
meaningful whole-answer gain against its table-layout control, so it was also
removed. The final benchmark measures the retained renderer, not either candidate.

[Raw paired results](../tool/benchmarks/profile_cold_rendering_results.json)
include per-round UI/raster medians and p95 timings. One frame across all
variants exceeded a 16.667ms UI/raster budget; the remainder did not. These
Mac measurements establish headroom, not a guaranteed perceptual improvement
on every device. Mobile, web, active selection, and scroll-through still need
their own profile measurements.

Reproduce current eager versus sliver from `example/`:

```sh
flutter run -d macos --profile --no-pub \
  --dart-define=BENCH_SLIVER=true --dart-define=BENCH_ROUNDS=4 \
  -t ../tool/benchmarks/profile_rendering.dart
```

The benchmark also exposes `runRenderingBenchmark(builders:, viewports:)` for
paired revision comparisons. The reference run used an isolated copy of the
original lib and pubspec, renamed its package and self-import URIs to
`gpt_markdown_before`, and imported both packages into a temporary example.
Font package references stayed unchanged so both used the same font assets.
The baseline and current builder callbacks constructed their respective
`GptMarkdown` with the same style and key. A third callback returned
`SliverGptMarkdown`; its viewport callback was
`(child) => CustomScrollView(slivers: [child])`. Run that adapter with
`BENCH_COLD_ONLY=true` and `BENCH_ROUNDS=4`. No aliased dependency is added
to the distributed package.

## Earlier separate-process measurements

These measurements compare baseline `5f92914` with the working-tree rendering
refactor on macOS 26.5.2, Flutter 3.44.2 / Dart 3.12.2, in native profile mode.
They do **not** establish a general 2x or 3x improvement or a perceptible FPS gain.

| Workload | Before (ms) | After (ms) | Before / after |
| --- | ---: | ---: | ---: |
| Short mixed answer, 1,485 characters, cold mount | 1.620 | 1.655 | 0.98x |
| Long mixed answer, 8,920 characters, cold mount | 8.683 | 10.047 | 0.86x |
| Math answer, 845 characters, cold mount | 1.588 | 1.659 | 0.96x |
| Streaming mixed answer, no reveal | 0.673 | 0.654 | 1.03x |
| Streaming mixed answer, animated reveal | 0.649 | 0.568 | 1.14x |

Values are the median of three rounds' median **UI plus raster work per frame**.
These threads overlap in Flutter's pipeline: their sum is a work metric, not
end-to-end latency or a frame-rate measurement. Ratios above one mean less work
in the refactor. Animated streaming used about 12% less work; its UI-only median
fell from 0.450 ms to 0.371 ms (1.21x). Small static differences do not establish
an improvement. The long cold mount took about 16% more work in this comparison;
that is a potential regression, not a speedup.

All baseline frames and all but one refactor frame kept both UI and raster
durations below 16.667 ms. Thus the test demonstrates some animation headroom,
but no improvement in meeting the 60 Hz frame budget on this machine. Slower
mobile devices and web require their own measurements.

## Method and limits

The same [benchmark](../tool/benchmarks/profile_rendering.dart) was copied into an
isolated original checkout and run against each package. It uses default
`GptMarkdown`, including default highlighting and table sizing, a 560 logical
pixel width, a scroll view at the top, and `SelectionArea`. Mixed content includes
paragraphs, headings, links, emphasis, lists, tables, Python fences, and ordinary
single-level quotes. There are no network images or model requests.

Each cold scenario has eight warm-up mounts and forty measured fresh mounts per
round. Streaming appends 48 characters per scheduled display frame, or every
three frames with reveal enabled, then ends streaming. The benchmark records
Flutter `FrameTiming` callbacks and drains batched timing reports around each
measurement. Counts include framework frames generated during the interval;
animated measurements mix append, reveal, and settling frames.

These are separate process runs, not interleaved A/B samples or confidence
intervals. An earlier exploratory run showed a different long-mount result,
so machine/run variability prevents attributing the full cold regression to
the refactor. That exploratory refactor run also encountered a Flutter selection
callback RangeError and was excluded. The retained runs block pointer/focus
input and terminate on framework errors; both completed without errors. This
does not establish that interactive selection is regression-free; its exception
still needs reproduction and investigation.

No scroll-through, active selection, RTL, giant single block, lazy sliver,
fixed-width-table, or deferred-highlighting speed ratio is established here.
The earlier roughly 11x nested-quote result is a pathological-case diagnostic,
not representative of these ordinary documents.

Run from `example/` with dependencies already resolved:

```sh
flutter run -d macos --profile --no-pub -t ../tool/benchmarks/profile_rendering.dart
```

Keep the app visible and avoid interacting with it. It prints `PERF_JSON` records
and closes its own process. Discard any run with `PERF_ERROR`. The retained
[raw results](../tool/benchmarks/profile_rendering_results.json) include separate
UI/raster medians, p95 durations, frame counts, and budget exceedances.
