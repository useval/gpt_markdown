/// A table's horizontal scrollbar must not sit on top of the table.
///
/// A scrollbar paints inside the viewport it belongs to, so a horizontal one
/// lands on the bottom row. On a phone that is the whole of the problem: the
/// bar covers content, and a finger already knows how to drag a table sideways,
/// so it was never offering a gesture anyone needed.
///
/// Nothing supplies one by default either way — `MaterialScrollBehavior`
/// returns the child unchanged for `Axis.horizontal` on every platform — so
/// this widget owns the decision: none on touch, and on a pointer platform a
/// strip of its own underneath the table rather than over it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _wide =
    '| aaaaaaaaaaaaaaa | bbbbbbbbbbbbbbb | ccccccccccccccc |\n'
    '|---|---|---|\n'
    '| 111111111111111 | 222222222222222 | 333333333333333 |';

Future<Size> _pump(WidgetTester tester, TargetPlatform platform) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: GptMarkdown(_wide, key: const Key('md')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getSize(find.byKey(const Key('md')));
}

void main() {
  for (final platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.fuchsia,
  ]) {
    testWidgets('$platform draws no scrollbar over the table', (tester) async {
      await _pump(tester, platform);

      expect(
        find.descendant(
          of: find.byType(Table),
          matching: find.byType(Scrollbar),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(of: find.byType(Table), matching: find.byType(Scrollbar)),
        findsNothing,
        reason: 'a touch platform gets no scrollbar at all',
      );
    });
  }

  for (final platform in <TargetPlatform>[
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$platform keeps a scrollbar, below the table', (tester) async {
      await _pump(tester, platform);

      expect(
        find.ancestor(of: find.byType(Table), matching: find.byType(Scrollbar)),
        findsOneWidget,
      );

      // The strip is reserved by padding *inside* the scroll view, so the
      // table's own box stops short of the bar rather than sharing its rows
      // with it.
      final table = tester.getRect(find.byType(Table));
      final viewport = tester.getRect(
        find
            .ancestor(
              of: find.byType(Table),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      expect(
        table.bottom,
        lessThan(viewport.bottom),
        reason: 'the table reaches the viewport floor, so the bar overlaps it',
      );
    });
  }

  testWidgets('a phone is no taller for the bar it does not draw', (
    tester,
  ) async {
    final phone = await _pump(tester, TargetPlatform.iOS);
    final desktop = await _pump(tester, TargetPlatform.macOS);

    expect(
      phone.height,
      lessThan(desktop.height),
      reason:
          'the reserved strip must cost height only where a bar is drawn — '
          'phone $phone against desktop $desktop',
    );
  });
}
