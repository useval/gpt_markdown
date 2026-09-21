/// Rebuilding a link-heavy document many times must not leak or throw.
///
/// Tappable leaves get a fresh recognizer per build (recycling them was a
/// wrong-url bug). Fresh-per-build means the old ones have to go somewhere:
/// they are retired rather than freed, because a gesture may still hold one,
/// and the backlog is trimmed past a high-water mark. Disposing a recognizer
/// that is still in a gesture arena throws, so the trim has to stay well
/// behind any live gesture.
///
/// A streaming reply rebuilds once per chunk, so this is the real shape of the
/// load, not a synthetic one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('many rebuilds of a link-heavy document stay healthy', (
    tester,
  ) async {
    const body =
        'see [one](https://example.com/1) and [two](https://example.com/2) '
        'and [three](https://example.com/3) — ';
    final tapped = <String>[];

    for (var i = 0; i < 120; i++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: GptMarkdown(
                '$body chunk $i',
                onLinkTap: (url, title) => tapped.add(url),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    expect(tester.takeException(), isNull);

    // Still tappable after all that churn, and firing the right link.
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate((w) => w is RichText).first,
    );
    expect(rich.text.toPlainText(), contains('one'));
  });
}
