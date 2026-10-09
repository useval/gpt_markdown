/// Tests for the incremental (segment-cached) rendering mode: the stream
/// splitter, widget-instance reuse across streamed appends, and a rebuild-time
/// comparison against the non-incremental single-text pipeline.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'sample_documents.dart';

Widget _app(String text, {bool incremental = true}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GptMarkdown(text, incremental: incremental),
      ),
    ),
  );
}

/// The segment widgets of the incremental view's column, excluding the
/// SizedBox gap separators (which are cheap and recreated every build).
List<Widget> _segments(WidgetTester tester) {
  final column = tester.widget<Column>(
    find
        .descendant(of: find.byType(GptMarkdown), matching: find.byType(Column))
        .first,
  );
  return column.children.where((w) => w is! SizedBox).toList();
}

void main() {
  group('splitStreamSegments', () {
    test('splits on blank lines', () {
      expect(splitStreamSegments('# A\n\npara one\nstill one\n\npara two'), [
        '# A',
        'para one\nstill one',
        'para two',
      ]);
    });

    test('keeps fenced code with blank lines whole', () {
      const doc = 'before\n\n```dart\nline1\n\nline2\n```\n\nafter';
      expect(splitStreamSegments(doc), [
        'before',
        '```dart\nline1\n\nline2\n```',
        'after',
      ]);
    });

    test('unclosed fence consumes the rest (streaming)', () {
      expect(splitStreamSegments('intro\n\n```py\ncode\n\nmore code'), [
        'intro',
        '```py\ncode\n\nmore code',
      ]);
    });

    test('keeps block latex with blank lines whole', () {
      const doc = 'x\n\n\\[\na + b\n\n= c\n\\]\n\ny';
      expect(splitStreamSegments(doc), ['x', '\\[\na + b\n\n= c\n\\]', 'y']);
    });

    test('single-line block latex does not open a region', () {
      expect(splitStreamSegments('\\[a+b\\]\n\nnext'), ['\\[a+b\\]', 'next']);
    });

    test('empty and whitespace input', () {
      expect(splitStreamSegments(''), isEmpty);
      expect(splitStreamSegments('  \n\n \n'), isEmpty);
    });

    test('concatenation of segments loses no content lines', () {
      final segments = splitStreamSegments(sampleChatGpt);
      final joined = segments.join('\n');
      for (final line in sampleChatGpt.split('\n')) {
        if (line.trim().isNotEmpty) {
          expect(joined, contains(line));
        }
      }
    });
  });

  group('incremental rendering', () {
    testWidgets('renders all segments', (tester) async {
      await tester.pumpWidget(
        _app('# Title\n\nHello **world**\n\n- item one\n- item two'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Title', findRichText: true), findsWidgets);
      expect(find.textContaining('Hello ', findRichText: true), findsWidgets);
      expect(find.textContaining('item one', findRichText: true), findsWidgets);
      expect(find.textContaining('item two', findRichText: true), findsWidgets);
    });

    testWidgets('appending text reuses widgets of unchanged segments', (
      tester,
    ) async {
      const base = '# Title\n\nFirst paragraph.\n\nSecond paragraph';
      await tester.pumpWidget(_app(base));
      await tester.pumpAndSettle();
      final before = _segments(tester);

      // Stream more text into the LAST segment.
      await tester.pumpWidget(_app('$base keeps growing'));
      await tester.pumpAndSettle();
      final after = _segments(tester);

      expect(before.length, after.length);
      // Every widget except the tail segment is the exact same instance.
      for (var i = 0; i < after.length - 1; i++) {
        expect(
          identical(before[i], after[i]),
          isTrue,
          reason: 'child $i should be reused',
        );
      }
      expect(identical(before.last, after.last), isFalse);
    });

    testWidgets('a new segment does not rebuild earlier ones', (tester) async {
      const base = 'First paragraph.\n\nSecond paragraph.';
      await tester.pumpWidget(_app(base));
      await tester.pumpAndSettle();
      final before = _segments(tester);

      await tester.pumpWidget(_app('$base\n\nThird'));
      await tester.pumpAndSettle();
      final after = _segments(tester);

      for (var i = 0; i < before.length; i++) {
        expect(identical(before[i], after[i]), isTrue);
      }
      expect(after.length, greaterThan(before.length));
    });

    testWidgets('style change invalidates the cache', (tester) async {
      const text = 'Hello world';
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: GptMarkdown(text, incremental: true))),
      );
      await tester.pumpAndSettle();
      final before = _segments(tester).first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              text,
              incremental: true,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final after = _segments(tester).first;
      expect(identical(before, after), isFalse);
    });

    testWidgets(
      'rebuild-time comparison while streaming (incremental vs not)',
      (tester) async {
        // Simulate streaming: repeatedly append a chunk and re-pump, timing the
        // build+layout work of each mode over the same growing document.
        final chunks = List.generate(
          30,
          (i) => '\n\nParagraph $i with **bold**, `code` and \\( x_$i^2 \\).',
        );

        Future<int> run(bool incremental) async {
          var text = '# Streaming benchmark';
          await tester.pumpWidget(_app(text, incremental: incremental));
          await tester.pumpAndSettle();
          final sw = Stopwatch()..start();
          for (final chunk in chunks) {
            text += chunk;
            await tester.pumpWidget(_app(text, incremental: incremental));
            await tester.pump();
          }
          sw.stop();
          return sw.elapsedMilliseconds;
        }

        final fullMs = await run(false);
        await tester.pumpWidget(const SizedBox());
        final incMs = await run(true);

        debugPrint(
          'streaming rebuild total over ${chunks.length} appends: '
          'single-text ${fullMs}ms vs incremental ${incMs}ms '
          '(${(fullMs / incMs).toStringAsFixed(1)}x)',
        );
        expect(incMs, greaterThan(0));
        expect(fullMs, greaterThan(0));
      },
    );
  });

  // `stretch` on the segment column forced every child to the maximum width the
  // parent offered, so a two-word answer laid claim to the whole column while
  // the single-text pipeline sized to its content. The two must agree.
  group('intrinsic width', () {
    const cases = <String, String>{
      'two words': 'Hi there',
      'long paragraph':
          'A much longer paragraph that should wrap and fill the line here.',
      'heading': '# Short',
      'bullet list': '- one\n- two',
      'task list': '- [x] done',
      'blockquote': '> quoted',
      'table': '| A | B |\n|---|---|\n| 1 | 2 |',
      'fenced code': '```dart\nvar x = 1;\n```',
      'horizontal rule': '---',
      'block maths': r'\[ E = mc^2 \]',
      'mixed document': '# Title\n\nshort\n\n| A | B |\n|---|---|\n| 1 | 2 |',
    };

    /// Width under *loose* constraints — room available, nothing forcing it.
    /// A tight `SizedBox` would make even a plain `Text` fill the space and
    /// prove nothing.
    Future<double> widthOf(
      WidgetTester tester,
      String source, {
      required bool incremental,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: GptMarkdown(source, incremental: incremental),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      return (find.byType(GptMarkdown).evaluate().first.renderObject
              as RenderBox)
          .size
          .width;
    }

    for (final entry in cases.entries) {
      testWidgets('${entry.key} sizes like the regex pipeline', (tester) async {
        tester.view.physicalSize = const Size(900, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        expect(
          await widthOf(tester, entry.value, incremental: true),
          moreOrLessEquals(
            await widthOf(tester, entry.value, incremental: false),
            epsilon: 0.5,
          ),
        );
      });
    }

    testWidgets('a short answer does not claim the whole width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      expect(await widthOf(tester, 'Hi', incremental: true), lessThan(200));
    });
  });

  // Changing how text *appears* must not change how it is *parsed*. Every
  // animating effect forces the incremental pipeline, so with the regex
  // pipeline selected `GptMarkdownAnimation.none` renders through a different
  // parser than its neighbours — different wrapping, and an extra line after a
  // fenced block. Pinning the parser has to make them agree exactly.
  group('animation does not change layout', () {
    const source =
        'Run the installer and then build the app to see how the '
        'text wraps across several lines here.\n\n'
        '```dart\nvar x = 1;\nvar y = 2;\n```\n\n'
        'Trailing paragraph after the code block.';

    Future<double> heightOf(
      WidgetTester tester,
      GptMarkdownAnimation animation,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: GptMarkdown(
                source,
                animation: animation,
                incremental: true,
                isStreaming: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      return (find.byType(SizedBox).evaluate().first.renderObject as RenderBox)
          .size
          .height;
    }

    testWidgets('every effect lays out identically on one parser', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final baseline = await heightOf(tester, GptMarkdownAnimation.none);
      for (final effect in GptMarkdownAnimation.values) {
        expect(
          await heightOf(tester, effect),
          moreOrLessEquals(baseline, epsilon: 0.5),
          reason: '$effect laid out differently from none',
        );
      }
    });
  });
}
