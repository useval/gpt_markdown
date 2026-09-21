/// A gesture in flight must keep firing the link it started on.
///
/// Tappable leaves are armed with `TapGestureRecognizer`s owned by the
/// paragraph's state. Recycling those objects across builds — reassigning
/// `onTap` on a recognizer a live gesture still references — makes a rebuild
/// that lands mid-gesture reassign it to a *different* link, so releasing the
/// pointer opens the wrong url.
///
/// Found by review, reproduced here before the fix: the probe logged `a` for
/// a press that began, and ended, on `b`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Finder richFinder() => find.byWidgetPredicate((w) => w is RichText);

void main() {
  testWidgets('a rebuild mid-gesture does not redirect the tap', (
    tester,
  ) async {
    final log = <String>[];
    const linkStyle = LinkStyle();

    InlineSpan linkA({required bool split}) =>
        split
            ? LinkTextSpan.wrapping(
              url: 'a',
              linkStyle: linkStyle,
              onTap: () => log.add('a'),
              children: const <InlineSpan>[
                TextSpan(text: 'A'),
                TextSpan(text: 'A'),
              ],
            )
            : LinkTextSpan(
              text: 'AA',
              url: 'a',
              linkStyle: linkStyle,
              onTap: () => log.add('a'),
            );

    InlineSpan doc({required bool split}) => TextSpan(
      children: <InlineSpan>[
        linkA(split: split),
        const TextSpan(text: ' xx '),
        LinkTextSpan(
          text: 'BB',
          url: 'b',
          linkStyle: linkStyle,
          onTap: () => log.add('b'),
        ),
      ],
    );

    Widget frame({required bool split}) {
      final span = doc(split: split);
      return MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: BidiText(
              span,
              bidiEnabled: false,
              inlineTapRuns: collectInlineTapRuns(span),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(split: false));

    final rich = tester.renderObject<RenderParagraph>(richFinder().first);
    final plain = rich.text.toPlainText();
    final start = plain.indexOf('BB');
    final box =
        rich
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: start + 2),
            )
            .first;
    final topLeft = tester.getTopLeft(richFinder().first);
    final centre =
        topLeft +
        Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2);

    final gesture = await tester.startGesture(centre);
    await tester.pump();

    // A frame arrives that splits link A into two leaves. Nothing about link B
    // changed on screen.
    await tester.pumpWidget(frame(split: true));

    await gesture.up();
    await tester.pump();

    expect(log, <String>[
      'b',
    ], reason: 'the press began and ended on B, so it must fire B');
  });
}
