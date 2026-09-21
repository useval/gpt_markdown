import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Counts rendered links.
///
/// A link is a `LinkTextSpan` now, not a `LinkButton` widget — that is what
/// lets its label wrap across lines and be selected with the text around it.
int countLinks(WidgetTester tester) {
  var count = 0;
  for (final rich in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    void walk(InlineSpan span) {
      if (span is LinkTextSpan) {
        count += 1;
      }
      span.visitDirectChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(rich.text);
  }
  return count;
}

void main() {
  testWidgets('the example page renders its sample markdown', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.byType(GptMarkdown), findsOneWidget);
    // The sample ends with a link, so rendering got all the way through.
    expect(countLinks(tester), greaterThan(0));
  });

  testWidgets('each demo is reachable from the app bar', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    for (final demo in <(IconData, String)>[
      (Icons.text_fields_rounded, 'Selection'),
      (Icons.link_rounded, 'Autolinks'),
      (Icons.code_rounded, 'Inline code'),
      (Icons.alternate_email_rounded, 'Inline patterns'),
    ]) {
      await tester.tap(find.byIcon(demo.$1));
      await tester.pumpAndSettle();

      expect(
        find.text(demo.$2),
        findsOneWidget,
        reason: 'tapping the app bar icon should open "${demo.$2}"',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
