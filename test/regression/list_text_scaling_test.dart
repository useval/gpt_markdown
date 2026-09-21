/// A list item's text must grow with the system font size.
///
/// A block construct inside a paragraph deliberately opts out of text scaling:
/// the paragraph lays its inline children out in scaled space and multiplies
/// the result back, so scaling again counts it twice and produced overlapping
/// text. Rendering blocks as sibling widgets removed that paragraph — and with
/// it the thing that was doing the scaling — so an item that still opted out
/// stayed pinned at 1x while the prose around it grew.
///
/// Nothing failed when that happened. The list rendered, the tests passed, and
/// the only symptom was that a reader who had turned their font up did not get
/// it in lists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Future<double> _height(
  WidgetTester tester,
  String markdown,
  double scale,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                key: const Key('probe'),
                children: [GptMarkdown(markdown)],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(find.byKey(const Key('probe'))).height;
}

void main() {
  const cases = <String, String>{
    'bullet list': '- first item here\n- second item here',
    'ordered list': '1. first item here\n2. second item here',
    'task list': '- [x] first item here\n- [ ] second item here',
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} grows with the system font size', (tester) async {
      final small = await _height(tester, entry.value, 1.0);
      final large = await _height(tester, entry.value, 2.0);

      // Not an exact ratio: bigger text at a fixed width wraps into more
      // lines, so the height grows faster than the font. The bug being
      // guarded is the flat case — 1.0, no growth at all.
      expect(
        large,
        greaterThan(small * 1.5),
        reason:
            '${entry.key} did not scale: $small at 1x, $large at 2x. '
            'A list item that opts out of text scaling with no paragraph '
            'above it to scale it stays pinned at 1x.',
      );
    });
  }

  testWidgets('a list scales like the prose beside it', (tester) async {
    const list = '- first item here\n- second item here';
    const prose = 'first item here second item here';

    final listRatio =
        await _height(tester, list, 2.0) / await _height(tester, list, 1.0);
    final proseRatio =
        await _height(tester, prose, 2.0) / await _height(tester, prose, 1.0);

    expect(
      listRatio,
      greaterThanOrEqualTo(proseRatio * 0.8),
      reason:
          'list grew ${listRatio}x while prose grew ${proseRatio}x — a reader '
          'who raises their font size should not get it in one and not the '
          'other',
    );
  });
}
