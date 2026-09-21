/// Regression pins for the streaming-reveal defects found by frame probes:
/// the inline-code chip vanishing while a segment animated, the reveal head
/// moving backwards when a construct opened late, entrance replays on
/// remount, and shaped-run splitting inside words.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Plain text across every paragraph, including RichText subclasses — the
/// chip-decorated paragraph renders through one.
String _plain(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    buffer.write(
      (element.widget as RichText).text.toPlainText(includePlaceholders: false),
    );
  }
  return buffer.toString();
}

/// Whether any paragraph in the tree carries a [CodeTextSpan] — the tag the
/// inline-code chip painter keys on.
bool _hasCodeSpan(WidgetTester tester) {
  var found = false;
  void walk(InlineSpan span) {
    if (span is CodeTextSpan) {
      found = true;
    }
    if (span is TextSpan) {
      span.children?.forEach(walk);
    }
  }

  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    walk((element.widget as RichText).text);
  }
  return found;
}

Widget _app(
  String text, {
  GptMarkdownAnimation animation = GptMarkdownAnimation.fade,
  GptMarkdownBlockAnimation block = GptMarkdownBlockAnimation.none,
  bool isStreaming = true,
  bool useDollarSignsForLatex = false,
  Key? key,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 600,
          child: GptMarkdown(
            text,
            key: key,
            animation: animation,
            blockAnimation: block,
            isStreaming: isStreaming,
            useDollarSignsForLatex: useDollarSignsForLatex,
            charactersPerSecond: 600,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // Big enough that nothing is clipped out of the finders.
  });

  group('inline-code chip during the reveal', () {
    testWidgets('the tag is in the tree the moment its text is', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const source =
          'Run `npm install` now, and keep going with plenty of prose so the '
          'segment is still animating while the code is on screen.';
      await tester.pumpWidget(_app(''));
      var sawText = false;
      for (var n = 1; n <= source.length; n++) {
        await tester.pumpWidget(_app(source.substring(0, n)));
        await tester.pump(const Duration(milliseconds: 16));
        if (_plain(tester).contains('npm install')) {
          sawText = true;
          // The defect: text visible, tag (and so the chip) absent until the
          // whole segment settled — measured at 1.8 s on the demo reply.
          expect(
            _hasCodeSpan(tester),
            isTrue,
            reason: 'code text visible without its chip tag at n=$n',
          );
        }
      }
      expect(sawText, isTrue);
    });
  });

  group('the reveal never moves backwards', () {
    testWidgets('a construct opening late does not un-show read text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // `[the docs]` closes and reveals as prose; `(` then reopens the whole
      // construct. Before the fix the rendered text shrank 14 -> 4 characters
      // — content the reader had seen vanished — and the re-advanced
      // characters replayed their fade. What IS allowed is the one-frame
      // collapse of markup glyphs when a construct completes: `[the docs]`
      // becoming the link `the docs` drops the brackets, never the words.
      const source =
          r'see [the docs](https://example.dev) plus prose to keep '
          'the tail busy for a good while longer.';
      await tester.pumpWidget(_app(''));
      var sawDocs = false;
      var high = 0;
      for (var n = 1; n <= source.length; n++) {
        await tester.pumpWidget(_app(source.substring(0, n)));
        for (var f = 0; f < 2; f++) {
          await tester.pump(const Duration(milliseconds: 16));
          final plain = _plain(tester);
          if (sawDocs) {
            expect(
              plain,
              contains('the docs'),
              reason: 'read content vanished at n=$n',
            );
          }
          sawDocs = sawDocs || plain.contains('the docs');
          // Between source updates nothing may shrink: only a re-parse can
          // legitimately collapse markup glyphs.
          if (f > 0) {
            expect(
              plain.length,
              greaterThanOrEqualTo(high),
              reason: 'the reveal moved backwards at n=$n',
            );
          }
          high = plain.length;
        }
      }
      expect(sawDocs, isTrue);
    });

    test('the engine holds its head when the target shrinks', () {
      final engine = RevealEngine(fadeSeconds: 0.25);
      engine.tick(1.0, 100, 1000);
      expect(engine.revealedFloor, 100);

      // The document shrank under the reveal (a late-opening construct).
      engine.tick(0.016, 90, 1000);
      expect(engine.revealedFloor, 100, reason: 'head must hold its ground');

      // It grows back: nothing already read replays its entrance, and no
      // aliased ring slot is consulted (100 & 63 == 36, freshly stamped).
      engine.tick(0.016, 120, 1000);
      expect(engine.progressFor(36), 1.0);
      expect(engine.progressFor(80), 1.0);
      expect(engine.progressFor(engine.revealedFloor - 1), lessThan(1.0));
    });
  });

  group('remount', () {
    testWidgets('a remounted reply appears whole even while streaming', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const source = 'A reply with `code` in it that the reader has seen.';
      await tester.pumpWidget(_app('', key: const ValueKey(1)));
      await tester.pumpWidget(_app(source, key: const ValueKey(1)));
      await tester.pumpAndSettle();
      expect(_plain(tester), contains('code'));

      // A lazy list disposing and re-inflating the item mid-stream: the new
      // state must not replay the reveal from nothing.
      await tester.pumpWidget(_app(source, key: const ValueKey(2)));
      await tester.pump();
      expect(_plain(tester), contains('the reader has seen'));
      expect(_hasCodeSpan(tester), isTrue);
    });

    testWidgets('a remounted reply replays no block entrance', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const source = 'Above the rule.\n\n---\n\nBelow the rule.';
      await tester.pumpWidget(
        _app(
          '',
          block: GptMarkdownBlockAnimation.fadeIn,
          key: const ValueKey(1),
        ),
      );
      await tester.pumpWidget(
        _app(
          source,
          block: GptMarkdownBlockAnimation.fadeIn,
          key: const ValueKey(1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // Streamed in: the rule got an entrance.
      expect(find.byType(GptMarkdownBlockEntrance), findsWidgets);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _app(
          source,
          block: GptMarkdownBlockAnimation.fadeIn,
          key: const ValueKey(2),
        ),
      );
      await tester.pump();
      // Remounted with the content already present: nothing to enter.
      expect(find.byType(GptMarkdownBlockEntrance), findsNothing);
      expect(_plain(tester), contains('Below the rule.'));
    });
  });

  group('segments and holds', () {
    testWidgets('two identical blocks do not collide on one key', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Two `---` segments share one cached paragraph; before the fix they
      // also shared one keyed entrance wrapper — a duplicate-keys crash.
      const source = 'One.\n\n---\n\nTwo.\n\n---\n\nThree.';
      await tester.pumpWidget(
        _app('', block: GptMarkdownBlockAnimation.fadeIn),
      );
      await tester.pumpWidget(
        _app(source, block: GptMarkdownBlockAnimation.fadeIn),
      );
      for (var f = 0; f < 20; f++) {
        await tester.pump(const Duration(milliseconds: 32));
        expect(tester.takeException(), isNull);
      }
      expect(_plain(tester), contains('Three.'));
    });

    testWidgets('a fence glued to a paragraph still streams its body', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // No blank line before the fence: one segment. The inline hold used to
      // read the fence's backticks as inline delimiters and withhold the
      // whole code body.
      const source = 'para\n```dart\nconst x = 1;\nconst y = 2;';
      await tester.pumpWidget(_app(''));
      await tester.pumpWidget(_app(source));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining('const x = 1;', findRichText: true),
        findsWidgets,
      );
    });

    test('a trailing half-opener is held until the next character', () {
      // `\` may become `\(`; `<` may become `<u>`. Un-held they were shown,
      // read, and then vanished when the second half landed.
      expect(inlineSafeLength(r'Since \'), 6);
      expect(inlineSafeLength('This is <u'), 8);
      expect(inlineSafeLength('This is <'), 8);
      // But a closed construct still shows whole.
      expect(inlineSafeLength(r'Since \(x^2\) holds.'), 20);
    });

    test('an unpaired dollar is held only in dollar-maths mode', () {
      const source = r'Now comes $b';
      expect(inlineSafeLength(source), source.length);
      expect(inlineSafeLength(source, holdMathDollars: true), 10);
      const closed = r'Let $a=1$ rest';
      expect(inlineSafeLength(closed, holdMathDollars: true), closed.length);
    });

    testWidgets('a dollar pair completing does not blank the message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const before = r'Let $a=1$ hold for a moment here. Now comes $b';
      const after = r'Let $a=1$ hold for a moment here. Now comes $b=2$ done.';
      await tester.pumpWidget(_app('', useDollarSignsForLatex: true));
      await tester.pumpWidget(_app(before, useDollarSignsForLatex: true));
      await tester.pump(const Duration(milliseconds: 500));
      final shown = _plain(tester).length;
      expect(shown, greaterThan(0));

      // The rewrite changes `$b` to `\(b=2\)` retroactively: an edit, not a
      // new reply. Before the fix this reset the engine — zero characters for
      // a frame, then the whole message re-typed.
      await tester.pumpWidget(_app(after, useDollarSignsForLatex: true));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        _plain(tester).length,
        greaterThanOrEqualTo(shown - 12),
        reason: 'the reveal must carry on, not restart',
      );
    });
  });

  group('span shape', () {
    List<InlineSpan> reveal(
      GptMarkdownAnimation effect, {
      required double Function(int) progressFor,
    }) {
      return applyReveal(
        spans: const [TextSpan(text: 'alpha beta gamma delta')],
        revealed: 22,
        effect: effect,
        progressFor: progressFor,
        defaultColor: const Color(0xFF000000),
      );
    }

    List<String> leaves(List<InlineSpan> spans) {
      final out = <String>[];
      void walk(InlineSpan span) {
        if (span is! TextSpan) {
          return;
        }
        if (span.text != null && span.text!.isNotEmpty) {
          out.add(span.text!);
        }
        span.children?.forEach(walk);
      }

      spans.forEach(walk);
      return out;
    }

    test('fade splits at whitespace only — never inside a word', () {
      final pieces = leaves(
        reveal(GptMarkdownAnimation.fade, progressFor: (i) => 0.5),
      );
      expect(pieces, ['alpha', ' beta', ' gamma', ' delta']);
    });

    test('wave still styles letter by letter', () {
      final pieces = leaves(
        reveal(GptMarkdownAnimation.wave, progressFor: (i) => 0.5),
      );
      expect(pieces.length, 22);
    });

    test('a settled span passes through as the original object', () {
      const original = CodeTextSpan(
        text: 'npm install',
        codeStyle: InlineCodeStyle(),
      );
      final out = applyReveal(
        spans: const [original],
        revealed: 11,
        effect: GptMarkdownAnimation.fade,
        progressFor: (i) => 1.0,
        defaultColor: const Color(0xFF000000),
        window: 0,
      );
      expect(identical(out.single, original), isTrue);
    });

    test('a revealing code container is measured by its subtree', () {
      const root = TextSpan(
        children: [
          TextSpan(text: 'Run '),
          CodeTextSpan.revealing(
            children: [TextSpan(text: 'npm '), TextSpan(text: 'install')],
            codeStyle: InlineCodeStyle(),
          ),
        ],
      );
      final runs = collectInlineCodeRuns(root);
      expect(runs, hasLength(1));
      expect(runs.single.start, 4);
      expect(runs.single.end, 15);
    });
  });
}
