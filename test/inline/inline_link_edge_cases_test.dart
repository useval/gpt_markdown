/// The cases the span-link design was shipped without proving.
///
/// Each of these was listed as an open risk when `inlineLinkBuilder` landed.
/// They are pinned here so the answer is a test result rather than a guess.
library;

import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Finder findRich() => find.byWidgetPredicate((w) => w is RichText);

Offset boxCentreOf(WidgetTester tester, String needle) {
  final rich = tester.widget<RichText>(findRich().first);
  final plain = rich.text.toPlainText();
  final start = plain.indexOf(needle);
  expect(start, isNot(-1), reason: 'no "$needle" in "$plain"');
  final renderObject = tester.renderObject<RenderParagraph>(findRich().first);
  final boxes = renderObject.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + needle.length),
  );
  expect(boxes, isNotEmpty, reason: 'no boxes for "$needle"');
  final box = boxes.first;
  return tester.getTopLeft(findRich().first) +
      Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2);
}

void main() {
  testWidgets('a link wrapping across two lines is tappable on both', (
    tester,
  ) async {
    // A `WidgetSpan` link cannot wrap at all — the whole label jumps to the
    // next line. This is the behaviour the span form exists to get right, so
    // both halves must answer a tap.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: GptMarkdown(
              'x [a link label long enough to wrap](https://example.com/a) y',
              inlineLinkBuilder: (link) => link.defaultSpan(),
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final renderObject = tester.renderObject<RenderParagraph>(findRich().first);
    final plain = tester.widget<RichText>(findRich().first).text.toPlainText();
    final start = plain.indexOf('a link label');
    final boxes = renderObject.getBoxesForSelection(
      TextSelection(
        baseOffset: start,
        extentOffset: start + 'a link label long enough to wrap'.length,
      ),
    );
    expect(boxes.length, greaterThan(1), reason: 'label did not wrap');

    final origin = tester.getTopLeft(findRich().first);
    for (final box in boxes) {
      tapped.clear();
      await tester.tapAt(
        origin + Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
      );
      await tester.pump();
      expect(tapped, <String>['https://example.com/a'], reason: 'box $box');
    }
  });

  testWidgets('a link in a right-to-left paragraph is tappable', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'مرحبا [الوثائق](https://example.com/docs) هنا',
              textDirection: TextDirection.rtl,
              inlineLinkBuilder: (link) => link.defaultSpan(),
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(boxCentreOf(tester, 'الوثائق'));
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);
  });

  testWidgets('a link clipped by maxLines does not report a phantom target', (
    tester,
  ) async {
    // `getBoxesForSelection` returns nothing for a range past the ellipsis, so
    // a clipped link simply has no tap target. That is acceptable — what would
    // not be is a target in the wrong place.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: GptMarkdown(
              'one two three four five six seven eight nine ten eleven '
              'twelve [clipped](https://example.com/clipped)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              inlineLinkBuilder: (link) => link.defaultSpan(),
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap everywhere on the single visible line; nothing should fire, because
    // the link is not on it.
    final rect = tester.getRect(findRich().first);
    for (var dx = 4.0; dx < rect.width; dx += 12) {
      await tester.tapAt(rect.topLeft + Offset(dx, rect.height / 2));
      await tester.pump();
    }

    expect(tapped, isEmpty);
  });

  testWidgets('a link is tappable while the reveal is still running', (
    tester,
  ) async {
    // Not testable before the flip: a link was one opaque placeholder to the
    // reveal, so it arrived whole and there was no mid-reveal state to tap.
    // Now the label reveals character by character, and a recognizer has to
    // ride onto every piece the reveal emits — a recognizer left only on the
    // container can never fire.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [the docs](https://example.com/docs) now and more text here',
              animation: GptMarkdownAnimation.fade,
              isStreaming: true,
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tapAt(boxCentreOf(tester, 'the'));
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);

    // Let the reveal finish so teardown does not trip a pending timer.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a consumer span keeps its hover callbacks beside a link', (
    tester,
  ) async {
    // The tap layer rebuilds every span in a paragraph that contains a link,
    // to arm tappable leaves and apply the hovered style. A rebuild that
    // dropped fields would break a consumer's span only in paragraphs that
    // happen to contain a link — silently, and nowhere else.
    var entered = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'ping @ada and see [the docs](https://example.com/docs)',
              inlinePatterns: [
                InlinePattern(
                  pattern: RegExp(r'@\w+'),
                  builder:
                      (context, match, style) => TextSpan(
                        text: match[0],
                        style: style,
                        onEnter: (_) => entered += 1,
                        semanticsLabel: 'mention',
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    InlineSpan? mention;
    void walk(InlineSpan span) {
      if (span is TextSpan && span.text == '@ada') {
        mention = span;
      }
      span.visitDirectChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.widget<RichText>(findRich().first).text);

    expect(mention, isNotNull, reason: 'the pattern did not render');
    expect(
      (mention! as TextSpan).onEnter,
      isNotNull,
      reason: 'onEnter was dropped when the paragraph was rebuilt for the link',
    );
    expect((mention! as TextSpan).semanticsLabel, 'mention');
  });

  testWidgets('an emoji in the label does not shift the tap target', (
    tester,
  ) async {
    // Tap runs are measured in UTF-16 code units, which is what
    // `getBoxesForSelection` also counts — an emoji is a surrogate pair, so a
    // run measured in runes instead would land the target two units early for
    // everything after it. Emoji in link labels are ubiquitous in chat.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'hi [go 🎉 now](https://example.com/a) after',
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // "now" sits after the surrogate pair, so it is the part that moves if the
    // arithmetic is wrong.
    await tester.tapAt(boxCentreOf(tester, 'now'));
    await tester.pump();
    expect(tapped, <String>['https://example.com/a']);

    // And text outside the link still must not fire.
    tapped.clear();
    await tester.tapAt(boxCentreOf(tester, 'after'));
    await tester.pump();
    expect(tapped, isEmpty);
  });

  testWidgets('the whole line box of a link is tappable, and fires once', (
    tester,
  ) async {
    // Two layers can deliver this tap: the recognizer armed on the leaf, which
    // covers only the tight glyph boxes, and the paragraph's range layer,
    // which covers the line box. Near the top of the line only the second one
    // can. It must fire, and it must fire exactly once — two tap recognizers
    // in one arena would be a double open.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [the docs](https://example.com/docs) now',
              style: const TextStyle(fontSize: 30),
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rich = tester.widget<RichText>(findRich().first);
    final plain = rich.text.toPlainText();
    final start = plain.indexOf('the docs');
    final renderObject = tester.renderObject<RenderParagraph>(findRich().first);
    final box =
        renderObject
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: start + 8),
              boxHeightStyle: BoxHeightStyle.max,
            )
            .first;
    final origin = tester.getTopLeft(findRich().first);

    // Just inside the top of the line box — above the glyphs.
    await tester.tapAt(
      origin + Offset((box.left + box.right) / 2, box.top + 1),
    );
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);
  });

  testWidgets('a consumer recognizer inside a label still wins the tap', (
    tester,
  ) async {
    // The range layer stands aside for a recognizer the consumer put on a
    // span, so a mention inside a link label opens the profile rather than
    // the link.
    final mentionTaps = <String>[];
    final linkTaps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [ask @ada now](https://example.com/docs)',
              inlinePatterns: [
                InlinePattern(
                  pattern: RegExp(r'@\w+'),
                  scopes: MarkdownComponent.allScopes,
                  builder:
                      (context, match, style) => TextSpan(
                        text: match[0],
                        style: style,
                        recognizer:
                            TapGestureRecognizer()
                              ..onTap = () => mentionTaps.add(match[0]!),
                      ),
                ),
              ],
              onLinkTap: (url, title) => linkTaps.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(boxCentreOf(tester, '@ada'));
    await tester.pump();
    expect(mentionTaps, <String>['@ada']);
    expect(linkTaps, isEmpty, reason: 'the link must not also fire');

    // And text beside it still belongs to the link.
    await tester.tapAt(boxCentreOf(tester, 'ask'));
    await tester.pump();
    expect(linkTaps, <String>['https://example.com/docs']);
  });

  testWidgets('an empty link label does not trip the debug assert', (
    tester,
  ) async {
    // `[](url)` is valid Markdown with nothing to tap, which is correct, not a
    // mistake. The assert guards against a builder returning something dead —
    // it must not fire on the package's own recommended `defaultSpan()`.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [](https://example.com/x) now',
              inlineLinkBuilder: (link) => link.defaultSpan(),
              onLinkTap: (url, title) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a genuinely untappable span still trips the assert', (
    tester,
  ) async {
    // The other half: relaxing the assert for empty labels must not blunt it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [the docs](https://example.com/x) now',
              inlineLinkBuilder: (link) => TextSpan(text: link.label),
              onLinkTap: (url, title) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('a link beside an animating block does not stop its reveal', (
    tester,
  ) async {
    // The tap layer rebuilds every span in a paragraph holding a link, and a
    // `RevealableSpan` carries the reveal's own rebuild hook. Rebuilding it as
    // a plain `TextSpan` drops that hook, so a document with both a link and
    // an animating block would render the block and never reveal it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              '# A heading\n\nsee [the docs](https://example.com/x) now',
              animation: GptMarkdownAnimation.fade,
              isStreaming: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final text =
        tester
            .widgetList<RichText>(findRich())
            .map((r) => r.text.toPlainText())
            .join();
    expect(text, contains('A heading'));
    expect(text, contains('the docs'));
  });

  testWidgets('an inert nested span does not kill the link over its text', (
    tester,
  ) async {
    // Tap resolution takes the innermost run. A nested TappableTextSpan with
    // no callback is still a run, so taking it innermost-first left the
    // enclosing link dead over exactly that text — a hole in the middle of a
    // link, with the cursor still showing a pointing hand.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [the docs here](https://example.com/docs)',
              inlineLinkBuilder:
                  (link) => link.defaultSpan(
                    children: <InlineSpan>[
                      TextSpan(text: 'the ', style: link.style),
                      // Decoration only — carries no callback.
                      TappableTextSpan(text: 'docs', style: link.style),
                      TextSpan(text: ' here', style: link.style),
                    ],
                  ),
              onLinkTap: (url, title) => tapped.add(url),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(boxCentreOf(tester, 'docs'));
    await tester.pump();

    expect(tapped, <String>[
      'https://example.com/docs',
    ], reason: 'the inert inner run swallowed the link');
  });

  testWidgets('a long press does not fire the link', (tester) async {
    // On mobile a long press is how selection starts, so a link must not
    // treat it as a tap. `TappableTextSpan` deliberately has no `onLongPress`:
    // arming a leaf for tap makes the paragraph's range layer stand aside, and
    // that layer was the only thing that could have delivered a long press —
    // so the field would have been public and silently dead. It can be added
    // later without breaking anyone.
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: SizedBox(
              width: 600,
              child: GptMarkdown(
                'see [the docs](https://example.com/docs) now',
                onLinkTap: (url, title) => tapped.add(url),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPressAt(boxCentreOf(tester, 'the docs'));
    await tester.pumpAndSettle();

    expect(tapped, isEmpty, reason: 'a long press must not count as a tap');
  });
}
