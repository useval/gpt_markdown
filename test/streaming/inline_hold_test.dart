/// Holding the reveal behind markup that has not finished arriving.
///
/// A streamed reply is parsed from what has arrived, so `` `npm install `` is
/// prose and `` `npm install` `` is a code chip. Revealing characters as they
/// arrive shows them in the wrong form and restyles them a moment later — a
/// different font, a background, a line that reflows. These tests pin both
/// halves of the bargain: nothing is shown before its styling is final, and
/// nothing waits on a delimiter that is never going to close.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// The plain text currently on screen.
String _rendered(WidgetTester tester) {
  final buffer = StringBuffer();
  void walk(InlineSpan span) {
    if (span is! TextSpan) {
      return;
    }
    if (span.text != null) {
      buffer.write(span.text);
    }
    span.children?.forEach(walk);
  }

  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    walk((element.widget as RichText).text);
  }
  return buffer.toString();
}

void main() {
  group('inlineSafeLength', () {
    test('plain prose is shown whole', () {
      const source = 'Just ordinary prose with nothing special in it at all.';
      expect(inlineSafeLength(source), source.length);
    });

    test('a closed construct is shown whole', () {
      for (final source in [
        'Run `npm install` and then continue on with the work.',
        'Use **the build** command and then carry on with it.',
        r'Since \( x^2 + 1 \) is positive we can continue on.',
        'See [the docs](https://example.com) for more detail now.',
      ]) {
        expect(inlineSafeLength(source), source.length, reason: source);
      }
    });

    test('an open construct holds from its opener', () {
      expect(inlineSafeLength('Run `npm inst'), 4);
      expect(inlineSafeLength(r'Since \( x^2 + 1'), 6);
      expect(inlineSafeLength('See [the docs](https://exam'), 4);
    });

    // The other half of the bargain. A lone backtick or a footnote asterisk
    // has no closer coming, and waiting for one stalls the reveal and then
    // dumps the backlog — which reads worse than the restyle being avoided.
    test('a delimiter that never closes stops being waited on', () {
      const tick =
          'A lone ` backtick followed by a great deal of ordinary '
          'prose that goes on well past the prose delimiter hold limit.';
      const star =
          'A footnote* marker followed by a great deal of ordinary '
          'prose that goes on well past the prose delimiter hold limit.';
      expect(inlineSafeLength(tick), tick.length);
      expect(inlineSafeLength(star), star.length);
    });

    test('balanced punctuation is not markup', () {
      const source = 'Compute 2 * 3 * 4 and then carry on with the rest.';
      expect(inlineSafeLength(source), source.length);
    });

    test('holding is bounded by the prose limit', () {
      final long = 'a ` ${'x' * (proseDelimiterHold + 10)}';
      expect(inlineSafeLength(long), long.length);
    });
  });

  group('streaming', () {
    /// Streams [doc] a character at a time and counts the frames that showed
    /// [inner] while its construct was still unterminated.
    Future<int> prematureFrames(
      WidgetTester tester,
      String doc,
      String inner,
      String closer,
    ) async {
      var premature = 0;
      for (var n = 1; n <= doc.length; n++) {
        final source = doc.substring(0, n);
        if (!source.contains(inner) || source.contains('$inner$closer')) {
          continue;
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: GptMarkdown(
                  source,
                  animation: GptMarkdownAnimation.fade,
                  isStreaming: true,
                  // Fast enough that the reveal is never what is holding the
                  // text back — only the hold is under test.
                  charactersPerSecond: 400,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        while (tester.takeException() != null) {}
        if (_rendered(tester).contains(inner)) {
          premature += 1;
        }
      }
      return premature;
    }

    const cases = <String, (String, String, String)>{
      'inline code': ('Run `npm install` now.', '`npm install', '`'),
      'bold': ('Use **the build** now.', '**the build', '**'),
      'italic': ('Use *the build* now.', '*the build', '*'),
      'strikethrough': ('Use ~~the build~~ now.', '~~the build', '~~'),
      'underline': ('Is <u>underlined</u> now.', '<u>underlined', '</u>'),
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} is not shown before it closes', (tester) async {
        tester.view.physicalSize = const Size(900, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final (doc, inner, closer) = entry.value;
        expect(await prematureFrames(tester, doc, inner, closer), 0);
      });
    }

    testWidgets('a finished reply is never held back', (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Ends mid-construct, and nothing more is coming: showing it as the
      // literal text it is beats showing nothing at all.
      const source = 'Run `npm inst';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: GptMarkdown(
                source,
                animation: GptMarkdownAnimation.fade,
                isStreaming: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(_rendered(tester), contains('npm inst'));
    });
  });
}
