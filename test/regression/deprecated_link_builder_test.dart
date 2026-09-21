// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/link_button.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `linkBuilder` is kept for one major so 1.2.x code still compiles and still
/// behaves the same. It returns a `Widget`, so its result is still wrapped in
/// a `WidgetSpan` with a `GestureDetector` around it — that shape is the whole
/// reason `inlineLinkBuilder` exists, and it must not change under anyone who
/// has not migrated.
///
/// It is consulted only when `inlineLinkBuilder` is null.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    LinkBuilder? linkBuilder,
    InlineLinkBuilder? inlineLinkBuilder,
    void Function(String url, String title)? onLinkTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'see [the docs](https://example.com/docs)',
              linkBuilder: linkBuilder,
              inlineLinkBuilder: inlineLinkBuilder,
              onLinkTap: onLinkTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the legacy builder still renders its widget', (tester) async {
    await pump(
      tester,
      linkBuilder:
          (context, text, url, style) =>
              Text('LEGACY', key: const Key('legacy')),
    );

    expect(find.byKey(const Key('legacy')), findsOneWidget);
  });

  testWidgets('the legacy builder is still wrapped so a tap reaches it', (
    tester,
  ) async {
    final tapped = <String>[];
    await pump(
      tester,
      linkBuilder:
          (context, text, url, style) =>
              Text('LEGACY', key: const Key('legacy')),
      onLinkTap: (url, title) => tapped.add(url),
    );

    await tester.tap(find.byKey(const Key('legacy')));
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);
  });

  testWidgets('inlineLinkBuilder wins when both are given', (tester) async {
    await pump(
      tester,
      linkBuilder:
          (context, text, url, style) =>
              Text('LEGACY', key: const Key('legacy')),
      inlineLinkBuilder: (link) => link.defaultSpan(),
    );

    expect(find.byKey(const Key('legacy')), findsNothing);
  });

  testWidgets('with neither builder the default is a LinkTextSpan', (
    tester,
  ) async {
    // The default link path is a span now, so the label wraps, selects and
    // reveals with the text around it. `LinkButton` is only reached through
    // the deprecated `linkBuilder`.
    await pump(tester);

    var found = 0;
    for (final rich in tester.widgetList<RichText>(
      find.byWidgetPredicate((w) => w is RichText),
    )) {
      void walk(InlineSpan span) {
        if (span is LinkTextSpan) {
          found += 1;
        }
        span.visitDirectChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(rich.text);
    }

    expect(found, 1);
    expect(find.byType(LinkButton), findsNothing);
  });
}
