/// A line break inside a paragraph is a line break.
///
/// CommonMark folds a single newline inside a paragraph into a space, and this
/// package has never done that. The plusparse block parser did: it gathered a
/// paragraph's lines and joined them with `' '`, so the newline was gone
/// before the inline parser ran.
///
/// That broke three things at once. A run of short lines — a pasted list using
/// `•` glyphs rather than Markdown list syntax, which is what a model writing
/// prose produces — collapsed into one wrapped paragraph. And the two breaks
/// CommonMark *does* define, two trailing spaces and a trailing backslash,
/// were swallowed with it, because both mark a newline that no longer existed.
///
/// The legacy parser always kept them, so the two pipelines disagreed about
/// the same source.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Bullet glyphs, not Markdown list syntax — one paragraph of short lines.
const _bullets = [
  '• #63 — RTL + jsdom, shared server fixtures: https://example.com/63',
  '• #64 — Move stale-completion permutations: https://example.com/64',
  '• #65 — Generate only navigation history: https://example.com/65',
];

Future<({double height, String text})> _render(
  WidgetTester tester,
  String markdown, {
  required bool incremental,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 700,
            child: GptMarkdown(
              markdown,
              incremental: incremental,
              key: const Key('md'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    height: tester.getSize(find.byKey(const Key('md'))).height,
    text: find
        .byWidgetPredicate((w) => w is RichText)
        .evaluate()
        .map((e) => (e.widget as RichText).text.toPlainText())
        .join('\n'),
  );
}

void main() {
  const styles = <String, String>{
    'a plain newline': '\n',
    'two trailing spaces': '  \n',
    'a trailing backslash': '\\\n',
  };

  for (final style in styles.entries) {
    testWidgets('${style.key} keeps the lines apart', (tester) async {
      final joined = _bullets.join(style.value);
      final rendered = await _render(tester, joined, incremental: true);

      expect(
        '\n'.allMatches(rendered.text).length,
        greaterThanOrEqualTo(2),
        reason:
            'three lines separated by ${style.key} rendered as '
            '"${rendered.text}" — the breaks were folded away',
      );
    });

    testWidgets('${style.key} renders alike in both parsers', (tester) async {
      final joined = _bullets.join(style.value);
      final modern = await _render(tester, joined, incremental: true);
      final legacy = await _render(tester, joined, incremental: false);

      expect(
        modern.height,
        legacy.height,
        reason:
            'same source, different height: ${modern.height} against '
            '${legacy.height}',
      );
    });
  }

  testWidgets('a paragraph of short lines is not one long line', (
    tester,
  ) async {
    // The width is generous on purpose: if the breaks are folded the three
    // lines fit into fewer, and the paragraph is measurably shorter.
    final broken = await _render(
      tester,
      _bullets.join('\n'),
      incremental: true,
    );
    final folded = await _render(tester, _bullets.join(' '), incremental: true);

    expect(
      broken.height,
      greaterThan(folded.height),
      reason:
          'joining the lines with a space gave the same height as keeping '
          'them apart, so the newline is doing nothing',
    );
  });

  testWidgets('a blank line still separates paragraphs', (tester) async {
    final oneBlock = await _render(
      tester,
      _bullets.join('\n'),
      incremental: true,
    );
    final separate = await _render(
      tester,
      _bullets.join('\n\n'),
      incremental: true,
    );

    expect(
      separate.height,
      greaterThan(oneBlock.height),
      reason: 'a blank line must still open a new paragraph, with its gap',
    );
  });
}
