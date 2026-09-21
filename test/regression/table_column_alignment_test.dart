/// A table column's own alignment must win over an ambient `textAlign`.
///
/// A left-aligned cell is drawn without an alignment box — it is already flush
/// left, and the box cost two layout passes per cell because content-sized
/// columns measure every cell before laying it out for real. That makes the
/// cell's text fill its column, so `textAlign` is what positions the glyphs
/// rather than a wrapper shrink-wrapping around them. A caller who sets
/// `textAlign` globally would otherwise silently re-align every unaligned
/// column in every table.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _wide = 'wide header here indeed wide header here indeed';

Future<double> _cellX(
  WidgetTester tester,
  String separator, {
  TextAlign? ambient,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 900,
            child: GptMarkdown(
              '| $_wide |\n|$separator|\n| x |',
              textAlign: ambient,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The second paragraph is the body cell; the first is the header.
  final body = find.byType(RichText).evaluate().elementAt(1).widget;
  return tester.getTopLeft(find.byWidget(body)).dx;
}

void main() {
  testWidgets('column alignment places the cell', (tester) async {
    final left = await _cellX(tester, ':---');
    final centre = await _cellX(tester, ':--:');
    final right = await _cellX(tester, '---:');

    expect(left, lessThan(centre), reason: 'left must sit before centre');
    expect(centre, lessThan(right), reason: 'centre must sit before right');
    expect(left, lessThan(20), reason: 'a left cell hugs the leading edge');
  });

  testWidgets('an ambient textAlign does not move a table column', (
    tester,
  ) async {
    for (final separator in <String>[':---', '---']) {
      final plain = await _cellX(tester, separator);
      for (final ambient in <TextAlign>[
        TextAlign.center,
        TextAlign.right,
        TextAlign.justify,
      ]) {
        expect(
          await _cellX(tester, separator, ambient: ambient),
          plain,
          reason:
              'column "$separator" moved when the caller set $ambient — the '
              'table says where its own columns go',
        );
      }
    }
  });
}
