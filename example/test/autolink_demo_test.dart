import 'package:example/autolink_demo.dart';
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
  testWidgets('autolink demo links URLs and honours both switches',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AutolinkApp());
    await tester.pumpAndSettle();

    final linked = countLinks(tester);
    expect(linked, greaterThan(5));

    // Allowlisting `myapp` links one more URL — the bare `myapp://open?id=7`.
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(countLinks(tester), linked + 1);

    // Turning autolinking off leaves only the explicit markdown links.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(countLinks(tester), lessThan(linked));
  });
}
