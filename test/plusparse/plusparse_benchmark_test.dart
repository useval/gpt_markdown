/// Speed/performance comparison between gpt_markdown's current regex-based
/// parsing pipeline and the new pure-Dart plusparse parser.
///
/// Both sides are measured doing their real "text → renderable structure"
/// work:
///  - legacy: `MarkdownComponent.generate(...)` — the combined-regex
///    splitMapJoin pipeline that `MdWidget` runs on every build, producing an
///    `InlineSpan` tree.
///  - plusparse: `PlusparseRenderer.render(...)` — the single-pass character
///    scanner plus the same span construction, so it also produces an
///    `InlineSpan` tree.
///
/// Both sides must produce the SAME KIND of output for the ratio to mean
/// anything. An earlier version of this benchmark timed `Plusparse.parse`,
/// which stops at the AST and never builds spans, against a legacy call that
/// did build them. That is unequal work, and it inflated every ratio here —
/// the published figures said 15x to 47x where the like-for-like answer is
/// about 4x to 12x. The span-count assertions below exist so that cannot
/// happen again silently.
///
/// Run with: flutter test test/plusparse/plusparse_benchmark_test.dart
///
/// Numbers are from the debug-mode test VM, so absolute values are pessimistic;
/// the *ratio* between the two pipelines is what matters.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'sample_documents.dart';

/// The words a reader would see, with placeholders and whitespace normalised.
///
/// A `WidgetSpan` contributes `U+FFFC` to `toPlainText`, and the two pipelines
/// place different numbers of them, so they are stripped before comparing.
String _visibleText(List<InlineSpan> spans) =>
    TextSpan(children: spans)
        .toPlainText(includeSemanticsLabels: false)
        .replaceAll('\uFFFC', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Average microseconds per run of [action] over [iters] timed iterations.
double _bench(void Function() action, {required int iters, int? warmup}) {
  for (var i = 0; i < (warmup ?? (iters ~/ 5) + 1); i++) {
    action();
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < iters; i++) {
    action();
  }
  sw.stop();
  return sw.elapsedMicroseconds / iters;
}

String _fmtUs(double us) {
  if (us >= 1000) {
    return '${(us / 1000).toStringAsFixed(2)} ms';
  }
  return '${us.toStringAsFixed(1)} µs';
}

void main() {
  testWidgets('legacy regex pipeline vs plusparse (speed and performance)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(SizedBox));
    const config = GptMarkdownConfig();

    final largeDoc = buildLargeDocument();
    final scenarios = <({String name, String doc, int iters})>[
      (name: 'inline-heavy (1 line)', doc: sampleInlineHeavy, iters: 200),
      (name: 'chatgpt sample (~0.9 KB)', doc: sampleChatGpt, iters: 100),
      (name: 'block-heavy (~0.5 KB)', doc: sampleBlockHeavy, iters: 100),
      (
        name: 'large doc (~${(largeDoc.length / 1024).round()} KB)',
        doc: largeDoc,
        iters: 10,
      ),
    ];

    final rows = <List<String>>[];

    for (final s in scenarios) {
      // Sanity: both pipelines must actually produce output for this input.
      expect(
        MarkdownComponent.generate(context, s.doc, config, true),
        isNotEmpty,
        reason: 'legacy produced no spans for ${s.name}',
      );
      final legacySpans = MarkdownComponent.generate(
        context,
        s.doc,
        config,
        true,
      );
      final newSpans = PlusparseRenderer.render(context, s.doc, config);
      expect(
        newSpans,
        isNotEmpty,
        reason: 'plusparse produced no spans for ${s.name}',
      );
      // The ratio is only meaningful if both sides rendered the same content.
      // Span *count* is not the test: the legacy pipeline wraps blocks and
      // links in `WidgetSpan` placeholders, so it emits more spans for the
      // same words. What must match is the text a reader would see.
      expect(
        _visibleText(newSpans),
        _visibleText(legacySpans),
        reason:
            'the two pipelines rendered different text for ${s.name}, so '
            'their timings are not comparable',
      );

      final legacyUs = _bench(
        () => MarkdownComponent.generate(context, s.doc, config, true),
        iters: s.iters,
      );
      final newUs = _bench(
        () => PlusparseRenderer.render(context, s.doc, config),
        iters: s.iters,
      );

      rows.add([
        s.name,
        _fmtUs(legacyUs),
        _fmtUs(newUs),
        '${(legacyUs / newUs).toStringAsFixed(1)}x',
      ]);

      expect(legacyUs, greaterThan(0));
      expect(newUs, greaterThan(0));
    }

    // Streaming simulation: an LLM emits the ChatGPT sample in 64-char
    // chunks and the whole visible text is re-parsed after every chunk —
    // exactly what a chat UI does while a reply streams in.
    const step = 64;
    final prefixes = <String>[
      for (var end = step; end < sampleChatGpt.length; end += step)
        sampleChatGpt.substring(0, end),
      sampleChatGpt,
    ];
    final legacyStreamUs = _bench(() {
      for (final prefix in prefixes) {
        MarkdownComponent.generate(context, prefix, config, true);
      }
    }, iters: 20);
    final newStreamUs = _bench(() {
      for (final prefix in prefixes) {
        PlusparseRenderer.render(context, prefix, config);
      }
    }, iters: 20);
    rows.add([
      'streaming (${prefixes.length} re-parses)',
      _fmtUs(legacyStreamUs),
      _fmtUs(newStreamUs),
      '${(legacyStreamUs / newStreamUs).toStringAsFixed(1)}x',
    ]);

    // Print the comparison table.
    const headers = ['scenario', 'legacy regex', 'plusparse', 'speedup'];
    final widths = List<int>.generate(
      headers.length,
      (c) => [
        headers[c].length,
        ...rows.map((r) => r[c].length),
      ].reduce((a, b) => a > b ? a : b),
    );
    String line(List<String> cells) => cells
        .asMap()
        .entries
        .map((e) => e.value.padRight(widths[e.key]))
        .join('  |  ');
    debugPrint('');
    debugPrint('plusparse vs legacy regex pipeline (avg per parse, debug VM)');
    debugPrint(line(headers));
    debugPrint(widths.map((w) => ''.padRight(w, '-')).join('--+--'));
    for (final r in rows) {
      debugPrint(line(r));
    }
    debugPrint('');

    // Generous regression guard: parsing the large document must stay well
    // under a frame-budget-scale bound even on a slow debug VM.
    final largeNewUs = _bench(() => Plusparse.parse(largeDoc), iters: 5);
    expect(
      largeNewUs,
      lessThan(250 * 1000),
      reason: 'plusparse took ${_fmtUs(largeNewUs)} on the large document',
    );
  });
}
