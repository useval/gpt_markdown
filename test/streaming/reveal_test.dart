/// The span-level reveal: the character effects, the block entrances, and the
/// invariants that make them safe to leave on during a real stream.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _doc = '''# Title

A paragraph with **bold** and `code` in it, long enough to matter here.

| A | B |
|---|---|
| 1 | 2 |

Final paragraph.
''';

Future<void> _pump(
  WidgetTester tester,
  String text, {
  required GptMarkdownAnimation animation,
  GptMarkdownBlockAnimation block = GptMarkdownBlockAnimation.none,
  bool isStreaming = true,
  double charactersPerSecond = 120,
}) async {
  Widget app(String t) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 600,
          child: GptMarkdown(
            t,
            animation: animation,
            blockAnimation: block,
            isStreaming: isStreaming,
            charactersPerSecond: charactersPerSecond,
          ),
        ),
      ),
    ),
  );
  // Content present at mount has been seen and appears whole; only text that
  // arrives afterwards animates. Streaming tests therefore mount empty and
  // deliver the document as an update, the way a real stream does.
  if (isStreaming) {
    await tester.pumpWidget(app(''));
  }
  await tester.pumpWidget(app(text));
}

/// Whether [text] is on screen anywhere, including inside the widget spans
/// that block-level constructs render as.
///
/// [_visible] cannot answer this: block content lives inside placeholders, and
/// a placeholder's text is not part of its parent paragraph's plain text.
bool _shows(String text) =>
    find.textContaining(text, findRichText: true).evaluate().isNotEmpty;

/// The text of the paragraphs being revealed, for measuring how far the reveal
/// has got. Placeholder content is deliberately excluded — it arrives whole
/// and would step the count rather than ramp it.
String _visible(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    buffer.write(
      (element.widget as RichText).text.toPlainText(includePlaceholders: false),
    );
  }
  return buffer.toString();
}

/// Distinct alpha values across the leaf spans — the fade ramp's fingerprint.
///
/// A hard cut produces one; a per-character ramp produces many.
Set<double> _alphas(WidgetTester tester) {
  final seen = <double>{};
  void walk(InlineSpan span) {
    if (span is! TextSpan) {
      return;
    }
    final color = span.style?.color;
    if (color != null && (span.text?.isNotEmpty ?? false)) {
      seen.add(color.a);
    }
    span.children?.forEach(walk);
  }

  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    walk((element.widget as RichText).text);
  }
  return seen;
}

/// Leaf spans carrying a `foreground` paint — how [GptMarkdownAnimation.blurIn]
/// shows up in the tree.
int _painted(WidgetTester tester) {
  var count = 0;
  void walk(InlineSpan span) {
    if (span is! TextSpan) {
      return;
    }
    if (span.style?.foreground != null && (span.text?.isNotEmpty ?? false)) {
      count += 1;
    }
    span.children?.forEach(walk);
  }

  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    walk((element.widget as RichText).text);
  }
  return count;
}

void main() {
  group('reveal', () {
    testWidgets('shows a growing prefix rather than the whole document', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _doc, animation: GptMarkdownAnimation.fade);
      await tester.pump();

      final lengths = <int>[];
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        while (tester.takeException() != null) {}
        lengths.add(_visible(tester).length);
      }

      expect(lengths.first, lessThan(lengths.last));
      // Monotonic: the reveal never takes content back.
      for (var i = 1; i < lengths.length; i++) {
        expect(lengths[i], greaterThanOrEqualTo(lengths[i - 1]));
      }
    });

    testWidgets('fade produces a per-character ramp, not a hard cut', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _doc, animation: GptMarkdownAnimation.fade);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      while (tester.takeException() != null) {}

      // Several partial opacities at once is the whole point: one value would
      // mean every visible character is at full strength, which is the hard
      // cut this replaced.
      expect(_alphas(tester).length, greaterThan(3));
    });

    testWidgets('typewriter reveals without animating characters', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _doc, animation: GptMarkdownAnimation.typewriter);
      await tester.pump();
      final early = _visible(tester).length;
      await tester.pump(const Duration(milliseconds: 250));
      while (tester.takeException() != null) {}

      expect(_visible(tester).length, greaterThan(early));
      // No ramp: characters are final the moment they appear.
      expect(_alphas(tester).where((a) => a > 0 && a < 1), isEmpty);
    });

    testWidgets('blurIn paints its characters through a mask filter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _doc, animation: GptMarkdownAnimation.blurIn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      while (tester.takeException() != null) {}

      expect(_painted(tester), greaterThan(0));
    });

    testWidgets('every effect ends with the complete document', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final effect in GptMarkdownAnimation.values) {
        await _pump(tester, _doc, animation: effect);
        await tester.pump();
        await _pump(tester, _doc, animation: effect, isStreaming: false);
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}

        expect(_shows('Title'), isTrue, reason: '$effect');
        expect(_shows('Final paragraph'), isTrue, reason: '$effect');
      }
    });

    testWidgets('a reply that was already finished does not type itself out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        _doc,
        animation: GptMarkdownAnimation.fade,
        isStreaming: false,
      );
      await tester.pump();
      // First frame, no time elapsed: history must already be whole.
      expect(_shows('Final paragraph'), isTrue);
    });

    testWidgets('reduced motion renders whole, immediately', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: GptMarkdown(
                _doc,
                animation: GptMarkdownAnimation.blurIn,
                blockAnimation: GptMarkdownBlockAnimation.growIn,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      while (tester.takeException() != null) {}
      expect(_shows('Final paragraph'), isTrue);
    });

    testWidgets('none builds no ticker and shows everything', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, _doc, animation: GptMarkdownAnimation.none);
      await tester.pump();
      expect(_shows('Final paragraph'), isTrue);
    });
  });

  // The renderer builds block constructs as widgets — a heading is text with
  // larger type, a list item is text with a marker, a quote is text behind a
  // bar — and a widget is one opaque character to a span-level reveal. They
  // used to arrive whole however the reveal was configured. `RevealableSpan`
  // publishes the text inside so the reveal reaches it.
  group('reveal reaches inside block constructs', () {
    const constructs = <String, String>{
      'heading': '# A heading long enough to reveal gradually here',
      'unordered list': '- first item long enough\n- second item long enough',
      'ordered list': '1. first item long enough\n2. second item long enough',
      'task list': '- [x] first item long enough\n- [ ] second one long enough',
      'checkbox': '[x] a checkbox label long enough to ramp',
      'radio': '(x) a radio label long enough to ramp',
      'blockquote': '> a quoted line long enough to reveal gradually',
      'paragraph': 'An ordinary paragraph long enough to reveal gradually.',
    };

    for (final entry in constructs.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = const Size(900, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await _pump(
          tester,
          entry.value,
          animation: GptMarkdownAnimation.fade,
          charactersPerSecond: 90,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        while (tester.takeException() != null) {}

        // Several characters part-way through their entrance at once. One
        // value would mean the construct arrived whole.
        expect(
          _alphas(tester).where((a) => a > 0 && a < 1).length,
          greaterThan(2),
        );
      });
    }
  });

  group('block entrance', () {
    testWidgets('wraps blocks that carry a laid-out widget', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        _doc,
        animation: GptMarkdownAnimation.fade,
        block: GptMarkdownBlockAnimation.growIn,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      while (tester.takeException() != null) {}

      expect(find.byType(GptMarkdownBlockEntrance), findsWidgets);
    });

    // The entrance is for content the character reveal cannot reach. Headings,
    // lists, quotes and checkboxes are text with a marker or a rule around it,
    // and they reveal per character through `RevealableSpan` — an entrance on
    // top would be a second animation over the same content. What is left is
    // genuinely opaque: a table, a fence, block maths, a rule.
    testWidgets('goes only to constructs the reveal cannot animate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const revealed = <String, String>{
        'paragraph': 'Just some ordinary prose text here.',
        'paragraph with a link': 'A [link](https://example.com) in a sentence.',
        'heading': '# A heading of some length',
        'unordered list': '- item one here\n- item two here',
        'ordered list': '1. item one here\n2. item two here',
        'task list': '- [x] item one here\n- [ ] item two here',
        'blockquote': '> a quoted line of text here',
      };
      const entered = <String, String>{
        'table': '| A | B |\n|---|---|\n| 1 | 2 |',
        'fence': '```dart\nvar x = 1;\n```',
        'block maths': r'\[ E = mc^2 \]',
        'rule': '---',
      };

      Future<int> entrances(String source) async {
        await _pump(
          tester,
          source,
          animation: GptMarkdownAnimation.fade,
          block: GptMarkdownBlockAnimation.growIn,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        while (tester.takeException() != null) {}
        return find.byType(GptMarkdownBlockEntrance).evaluate().length;
      }

      for (final entry in revealed.entries) {
        expect(entry.key, isNotEmpty);
        expect(
          await entrances(entry.value),
          0,
          reason:
              '${entry.key} reveals per character; an entrance would be a '
              'second animation over the same content',
        );
      }
      for (final entry in entered.entries) {
        expect(
          await entrances(entry.value),
          greaterThan(0),
          reason: '${entry.key} arrives whole and needs an entrance',
        );
      }
    });

    testWidgets('none adds nothing to the tree', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        _doc,
        animation: GptMarkdownAnimation.fade,
        block: GptMarkdownBlockAnimation.none,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      while (tester.takeException() != null) {}

      expect(find.byType(GptMarkdownBlockEntrance), findsNothing);
    });

    testWidgets('every entrance leaves the document complete', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final entrance in GptMarkdownBlockAnimation.values) {
        await _pump(
          tester,
          _doc,
          animation: GptMarkdownAnimation.fade,
          block: entrance,
        );
        await tester.pump();
        await _pump(
          tester,
          _doc,
          animation: GptMarkdownAnimation.fade,
          block: entrance,
          isStreaming: false,
        );
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}
        expect(
          _visible(tester),
          contains('Final paragraph'),
          reason: '$entrance',
        );
      }
    });
  });

  group('span reveal', () {
    test('counts placeholders as one character', () {
      const spans = <InlineSpan>[
        TextSpan(text: 'ab'),
        WidgetSpan(child: SizedBox()),
        TextSpan(text: 'cd'),
      ];
      expect(countRevealCharacters(spans), 5);
    });

    test('counts nested children', () {
      const spans = <InlineSpan>[
        TextSpan(
          text: 'ab',
          children: [TextSpan(text: 'cd'), TextSpan(text: 'e')],
        ),
      ];
      expect(countRevealCharacters(spans), 5);
    });

    test('truncates to the reveal head and drops the rest', () {
      const spans = <InlineSpan>[TextSpan(text: 'abcdef')];
      final out = applyReveal(
        spans: spans,
        revealed: 3,
        effect: GptMarkdownAnimation.typewriter,
        progressFor: (_) => 1,
        defaultColor: const Color(0xFF000000),
      );
      expect(TextSpan(children: out).toPlainText(), 'abc');
    });

    test('keeps a link recognizer on the rebuilt span', () {
      final recognizer = _NoopRecognizer();
      addTearDown(recognizer.dispose);
      final spans = <InlineSpan>[
        TextSpan(text: 'link', recognizer: recognizer),
      ];
      final out = applyReveal(
        spans: spans,
        revealed: 4,
        effect: GptMarkdownAnimation.fade,
        progressFor: (_) => 0.5,
        defaultColor: const Color(0xFF000000),
      );
      expect((out.single as TextSpan).recognizer, same(recognizer));
    });

    test('never splits a surrogate pair', () {
      // One emoji, two code units.
      const spans = <InlineSpan>[TextSpan(text: 'a🎉b')];
      final out = applyReveal(
        spans: spans,
        revealed: 4,
        effect: GptMarkdownAnimation.fade,
        progressFor: (_) => 0.5,
        defaultColor: const Color(0xFF000000),
      );
      final text = TextSpan(children: out).toPlainText();
      expect(text, 'a🎉b');
      // A split pair would have produced a replacement character instead.
      expect(text.runes.length, 3);
    });

    test('settled characters are not split into per-character spans', () {
      const spans = <InlineSpan>[TextSpan(text: 'abcdefghij')];
      final out = applyReveal(
        spans: spans,
        revealed: 10,
        effect: GptMarkdownAnimation.fade,
        // Everything finished: nothing should need its own span.
        progressFor: (_) => 1,
        defaultColor: const Color(0xFF000000),
        window: 4,
      );
      final children = (out.single as TextSpan).children!;
      // One settled run plus at most the window, never ten.
      expect(children.length, lessThan(10));
    });
  });

  // One span per character is not the same as one span. Flutter shapes each
  // style run separately, so a paragraph split per character kerns and wraps
  // differently from the same paragraph whole, and a construct that styles a
  // continuous stretch — an inline code chip — is broken into pieces. Only
  // what is genuinely mid-entrance may be split; everything else coalesces,
  // and a reveal that has caught up leaves no trace at all.
  group('span coalescing', () {
    const source =
        'Run `npm install` and then build the app to see how it '
        'wraps across several lines of text here in this paragraph.';

    final rich = find.byWidgetPredicate((w) => w is RichText);

    Future<void> settle(
      WidgetTester tester,
      GptMarkdownAnimation animation, {
      required bool streaming,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: GptMarkdown(
                source,
                animation: animation,
                isStreaming: streaming,
                charactersPerSecond: 2000,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      while (tester.takeException() != null) {}
    }

    int spansOnScreen() {
      var total = 0;
      void walk(InlineSpan span) {
        total += 1;
        if (span is TextSpan) {
          span.children?.forEach(walk);
        }
      }

      for (final element in rich.evaluate()) {
        walk((element.widget as RichText).text);
      }
      return total;
    }

    for (final streaming in [true, false]) {
      final state = streaming ? 'still streaming' : 'finished';
      testWidgets('a caught-up reveal collapses back ($state)', (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // `typewriter` reveals but never styles a character, so it is the
        // floor: an animating effect that has caught up must cost no more.
        await settle(
          tester,
          GptMarkdownAnimation.typewriter,
          streaming: streaming,
        );
        final floor = spansOnScreen();

        for (final effect in [
          GptMarkdownAnimation.fade,
          GptMarkdownAnimation.blurIn,
          GptMarkdownAnimation.wave,
        ]) {
          await settle(tester, effect, streaming: streaming);
          expect(
            spansOnScreen(),
            floor,
            reason: '$effect left the document split per character',
          );
        }
      });
    }

    testWidgets('an inline code chip stays a single run', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final effect in GptMarkdownAnimation.values) {
        await settle(tester, effect, streaming: true);
        var runs = 0;
        var characters = 0;
        void walk(InlineSpan span, TextStyle? inherited) {
          if (span is! TextSpan) {
            return;
          }
          final style =
              inherited == null ? span.style : inherited.merge(span.style);
          final family = (style?.fontFamily ?? '').toLowerCase();
          final text = span.text;
          if (text != null && text.isNotEmpty && family.contains('mono')) {
            runs += 1;
            characters += text.length;
          }
          span.children?.forEach((child) => walk(child, style));
        }

        for (final element in rich.evaluate()) {
          walk((element.widget as RichText).text, null);
        }
        expect(runs, 1, reason: '$effect broke the chip into pieces');
        expect(characters, 'npm install'.length, reason: '$effect');
      }
    });
  });
}

class _NoopRecognizer extends TapGestureRecognizer {}
