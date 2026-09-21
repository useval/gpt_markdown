/// Native profile benchmark for user-visible Markdown rendering.
/// Run from example/: flutter run -d macos --profile --no-pub
///   -t ../tool/benchmarks/profile_rendering.dart
/// It prints PERF_JSON records, then closes its own process. Compare the same
/// file and Flutter SDK on both revisions. No network or model is involved.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

String section(int i) => '''
## Step ${i + 1}: configure the worker

The worker processes incoming requests and records the result before acknowledging
the message. For deployment ${i + 1}, start with a small concurrency limit and
increase it after checking latency and memory usage. The [configuration guide](https://example.com/guide/$i)
explains the available options.

### Settings for worker $i

- Set **WORKER_ID** to `worker_$i` so logs identify the instance.
- Keep *retry attempts* bounded and use exponential backoff.
- Store credentials outside the repository and rotate them periodically.
- Check the [health endpoint](https://example.com/health/$i) before routing traffic.

| Worker $i option | Default | Purpose |
|---|---|---|
| concurrency_$i | 4 | Requests processed together |
| timeout_$i | 30 seconds | Maximum request duration |
| retries_$i | 3 | Transient failure recovery |

```python
async def worker_$i(queue, client):
    while True:
        message = await queue.get()
        try:
            result = await client.process(message)
            await save_result(result)
        finally:
            queue.task_done()
```

> Deployment $i: retry a failed operation only when it is idempotent. A timeout
does not necessarily mean the remote service rejected the request.

After deploying worker $i, inspect the error rate and the 95th-percentile response
time. If either rises, reduce concurrency and inspect the slow requests before
adding more workers. **More parallelism does not always improve throughput.**
''';

final shortDocument = section(0);
final longDocument = List.generate(6, section).join('\n\n');
const mathDocument = r'''
## Understanding a quadratic model

For a model \( f(x) = ax^2 + bx + c \), the coefficient \( a \) controls
curvature, while the other terms shift the position of the curve.

### Find the stationary point

Differentiate the polynomial and solve for a zero derivative:

\[ f'(x) = 2ax + b = 0 \]

The stationary point therefore lies at \( x_* = -b/(2a) \). When the leading
coefficient is positive, this is the minimum of the function.

### Interpret the result

- **Positive curvature** produces a minimum.
- **Negative curvature** produces a maximum.
- A zero leading coefficient reduces the model to a line.

\[ f(x_*) = c - \frac{b^2}{4a} \]

This calculation is useful when fitting a local approximation to a smooth
objective. Always check the units and the range over which the approximation
is valid before interpreting its coefficients.
''';

typedef MarkdownBenchmarkBuilder =
    Widget Function(String source, Key key, bool streaming, bool animate);

Map<String, MarkdownBenchmarkBuilder> _builders = {
  'current':
      (source, key, streaming, animate) => GptMarkdown(
        source,
        key: key,
        isStreaming: streaming,
        animation:
            animate ? GptMarkdownAnimation.fade : GptMarkdownAnimation.none,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
};

Map<String, Widget Function(Widget)> _viewports = {};

void main() {
  const withSliver = bool.fromEnvironment('BENCH_SLIVER');
  if (withSliver) {
    _builders['sliver'] =
        (source, key, streaming, animate) => SliverGptMarkdown(
          source,
          key: key,
          config: const GptMarkdownConfig(
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        );
    _viewports['sliver'] = (child) => CustomScrollView(slivers: [child]);
  }
  runRenderingBenchmark();
}

/// Alternate adjacent workloads between package revisions in one process.
/// An external adapter may import an aliased baseline package and supply both.
void runRenderingBenchmark({
  Map<String, MarkdownBenchmarkBuilder>? builders,
  Map<String, Widget Function(Widget)>? viewports,
}) {
  if (builders != null) _builders = builders;
  if (viewports != null) _viewports = viewports;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    stderr.writeln('PERF_ERROR framework exception; discard this run');
    exit(2);
  };
  runApp(const MaterialApp(home: _Benchmark()));
}

class _Benchmark extends StatefulWidget {
  const _Benchmark();
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark> {
  String variant = _builders.keys.first;
  String source = '';
  bool streaming = false;
  bool animate = false;
  int generation = 0;
  bool recording = false;
  final frames = <FrameTiming>[];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _timings(List<FrameTiming> batch) {
    if (recording) frames.addAll(batch);
  }

  Future<void> frame() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }

  Future<void> drain() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  Future<void> display(String text, {bool cold = false}) async {
    setState(() {
      source = text;
      if (cold) generation++;
    });
    await frame();
  }

  double percentile(List<double> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.of(values)..sort();
    return sorted[math.max(0, (sorted.length * p).ceil() - 1)];
  }

  Future<void> measure(
    String name,
    int round,
    Future<void> Function() action,
  ) async {
    await drain();
    frames.clear();
    recording = true;
    await action();
    await drain();
    recording = false;
    final ui =
        frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList();
    final raster =
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList();
    final work =
        frames
            .map(
              (f) =>
                  (f.buildDuration.inMicroseconds +
                      f.rasterDuration.inMicroseconds) /
                  1000,
            )
            .toList();
    stdout.writeln(
      'PERF_JSON ${jsonEncode({'variant': variant, 'case': name, 'round': round, 'frames': frames.length, 'ui_median_ms': percentile(ui, .5), 'ui_p95_ms': percentile(ui, .95), 'raster_median_ms': percentile(raster, .5), 'raster_p95_ms': percentile(raster, .95), 'work_median_ms': percentile(work, .5), 'over_60hz_budget': frames.where((f) => f.buildDuration.inMicroseconds > 16667 || f.rasterDuration.inMicroseconds > 16667).length})}',
    );
  }

  Future<void> cold(String name, String text, int round) async {
    animate = false;
    streaming = false;
    for (var i = 0; i < 8; i++) {
      await display(text, cold: true);
    }
    await measure(name, round, () async {
      for (var i = 0; i < 40; i++) {
        await display(text, cold: true);
      }
    });
  }

  Future<void> stream(int round, {required bool reveal}) async {
    animate = reveal;
    streaming = true;
    await display('', cold: true);
    await measure(
      reveal ? 'stream_animated' : 'stream_no_animation',
      round,
      () async {
        const step = 48;
        for (var end = step; end < longDocument.length + step; end += step) {
          await display(
            longDocument.substring(0, math.min(end, longDocument.length)),
          );
          if (reveal) {
            // 48 characters each three display frames: about 960 chars/sec at
            // 60 Hz, ahead of a 300 chars/sec reveal and representative of bursts.
            await frame();
            await frame();
          }
        }
        setState(() => streaming = false);
        await frame();
        if (reveal) {
          for (var i = 0; i < 90; i++) {
            await frame();
          }
        }
      },
    );
  }

  Future<void> _run() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      stdout.writeln(
        'PERF_DOCS short=${shortDocument.length} long=${longDocument.length} math=${mathDocument.length}',
      );
      const rounds = int.fromEnvironment('BENCH_ROUNDS', defaultValue: 3);
      const coldOnly =
          bool.fromEnvironment('BENCH_COLD_ONLY') ||
          bool.fromEnvironment('BENCH_SLIVER');
      for (var round = 0; round < rounds; round++) {
        final order =
            round.isEven
                ? _builders.keys.toList()
                : _builders.keys.toList().reversed.toList();
        for (final scenario in [
          'cold_short',
          'cold_long',
          'cold_math',
          if (!coldOnly) 'stream_no_animation',
          if (!coldOnly) 'stream_animated',
        ]) {
          for (final name in order) {
            variant = name;
            switch (scenario) {
              case 'cold_short':
                await cold(scenario, shortDocument, round);
              case 'cold_long':
                await cold(scenario, longDocument, round);
              case 'cold_math':
                await cold(scenario, mathDocument, round);
              case 'stream_no_animation':
                await stream(round, reveal: false);
              case 'stream_animated':
                await stream(round, reveal: true);
            }
          }
        }
      }
      exit(0);
    } catch (error, stack) {
      stderr.writeln('PERF_ERROR $error\n$stack');
      exit(1);
    }
  }

  Widget _defaultViewport(Widget child) => SingleChildScrollView(child: child);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AbsorbPointer(
      child: ExcludeFocus(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 560,
            child: SelectionArea(
              child: (_viewports[variant] ?? _defaultViewport)(
                _builders[variant]!(
                  source,
                  ValueKey('$variant-$generation'),
                  streaming,
                  animate,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
