/// `maxLines` clamps the whole document, not each block in it.
///
/// The incremental renderer splits a document at blank lines and gives each
/// segment its own paragraph. `maxLines` is a property of a paragraph, so each
/// segment took the full allowance: a two-line preview of a five-paragraph
/// reply rendered ten lines. Nothing failed — no overflow stripe, no
/// exception, no test — the preview was simply the wrong height, and the
/// incremental path is the default, so this was what a clamped preview did
/// unless the caller had opted out of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _doc =
    'First paragraph with quite a lot of words in it so that it definitely '
    'wraps onto more than a single line of output here.\n\n'
    'Second paragraph, also long enough to wrap onto several lines when '
    'rendered at this width so we can see the clamp.\n\n'
    'Third paragraph, likewise long enough to wrap more than once.';

Future<double> _height(
  WidgetTester tester,
  String markdown, {
  required bool incremental,
  int? maxLines,
  TextOverflow overflow = TextOverflow.ellipsis,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: GptMarkdown(
              markdown,
              incremental: incremental,
              maxLines: maxLines,
              overflow: overflow,
              key: const Key('md'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(find.byKey(const Key('md'))).height;
}

void main() {
  testWidgets('a clamp bounds the document, not every block', (tester) async {
    final clamped = await _height(tester, _doc, incremental: true, maxLines: 2);
    // `clip`, because an ellipsis with no line count is itself a budget of
    // one — it would make the unclamped reference shorter than the clamp.
    final whole = await _height(
      tester,
      _doc,
      incremental: true,
      overflow: TextOverflow.clip,
    );

    expect(
      clamped,
      lessThan(whole / 2),
      reason:
          'a two-line clamp of a three-paragraph document rendered $clamped '
          'against $whole unclamped — each segment took the whole allowance',
    );
  });

  testWidgets('both parsers clamp to the same height', (tester) async {
    final incremental = await _height(
      tester,
      _doc,
      incremental: true,
      maxLines: 2,
    );
    final legacy = await _height(tester, _doc, incremental: false, maxLines: 2);

    expect(
      incremental,
      legacy,
      reason:
          'the clamp is a documented property of the widget, so which parser '
          'runs must not change it: $incremental vs $legacy',
    );
  });

  testWidgets('more lines allowed means a taller preview', (tester) async {
    final two = await _height(tester, _doc, incremental: true, maxLines: 2);
    final four = await _height(tester, _doc, incremental: true, maxLines: 4);

    expect(
      four,
      greaterThan(two),
      reason: 'the clamp must still respond to its own value',
    );
  });

  // An ellipsis with no line count is a budget of one: Flutter truncates to a
  // single line when asked for an ellipsis without a `maxLines`. That is
  // Flutter's rule, not this package's — a plain `Text` does the same — but it
  // still has to mean the same thing whichever parser runs, and it did not.
  // The document was split, so each block took a line of its own.
  testWidgets('an ellipsis alone is a budget of one line', (tester) async {
    final incremental = await _height(tester, _doc, incremental: true);
    final legacy = await _height(tester, _doc, incremental: false);

    expect(
      incremental,
      legacy,
      reason:
          'ellipsis with no maxLines: $incremental vs $legacy — the split '
          'document gave every block its own line',
    );
  });

  testWidgets('clip with no budget renders the whole document', (tester) async {
    final clipped = await _height(
      tester,
      _doc,
      incremental: true,
      overflow: TextOverflow.clip,
    );
    final ellipsised = await _height(tester, _doc, incremental: true);

    expect(
      clipped,
      greaterThan(ellipsised * 4),
      reason:
          'only an ellipsis implies a budget; clip must leave the document '
          'at its natural height',
    );
  });

  testWidgets('a single-block document is unaffected', (tester) async {
    const one =
        'Only one paragraph here, long enough that it wraps onto '
        'several lines at this width so a clamp has something to cut.';
    final clamped = await _height(tester, one, incremental: true, maxLines: 2);
    final legacy = await _height(tester, one, incremental: false, maxLines: 2);

    expect(clamped, legacy);
  });
}
