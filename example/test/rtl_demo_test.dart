import 'package:example/main.dart';
import 'package:example/rtl_demo.dart';
import 'package:example/rtl_sample.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';

void main() {
  for (final incremental in [true, false]) {
    testWidgets(
      'RTL showcase mirrors numbered block indentation: $incremental',
      (tester) async {
        Widget view(TextDirection direction) => MaterialApp(
              home: Scaffold(
                  body: SingleChildScrollView(
                child: SizedBox(
                  width: 800,
                  child: GptMarkdown(
                    rtlShowcaseMarkdown,
                    textDirection: direction,
                    style: const TextStyle(fontSize: 16),
                    // ignore: deprecated_member_use
                    incremental: incremental,
                    inlinePatterns: rtlInlinePatterns,
                    inlineDirectives: rtlInlineDirectives,
                    imageBuilder: rtlImageBuilder,
                  ),
                ),
              )),
            );
        await tester.pumpWidget(view(TextDirection.ltr));
        await tester.pumpAndSettle();
        final lists = find.byType(OrderedListView);
        expect(lists, findsWidgets);
        final leftEdges = lists
            .evaluate()
            .map(
              (element) => tester.getRect(find.byWidget(element.widget)).left,
            )
            .toList();
        await tester.pumpWidget(view(TextDirection.rtl));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rightEdges = lists
            .evaluate()
            .map(
              (element) => tester.getRect(find.byWidget(element.widget)).right,
            )
            .toList();
        expect(rightEdges.length, leftEdges.length);
        for (var i = 0; i < leftEdges.length; i++) {
          expect(rightEdges[i], closeTo(800 - leftEdges[i], .5));
        }
      },
    );
  }

  testWidgets('RTL demo opens from the example and renders the single showcase',
      (tester) async {
    await tester.pumpWidget(const App());
    await tester.tap(find.byTooltip('RTL block alignment demo'));
    await tester.pumpAndSettle();
    expect(find.byType(RtlPage), findsOneWidget);
    final markdown = tester.widget<GptMarkdown>(find.descendant(
        of: find.byType(RtlPage), matching: find.byType(GptMarkdown)));
    expect(markdown.data, rtlShowcaseMarkdown);
    expect(markdown.textDirection, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL demo switches direction, scale and rendering pipeline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RtlPage()));
    await tester.tap(find.byKey(const ValueKey('rtl-direction')));
    await tester.pumpAndSettle();
    expect(tester.widget<GptMarkdown>(find.byType(GptMarkdown)).textDirection,
        TextDirection.ltr);
    expect(find.byKey(const ValueKey('rtl-sample')), findsNothing);
    await tester.tap(find.text('Text 1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text 2.0x').last);
    await tester.pumpAndSettle();
    expect(tester.widget<GptMarkdown>(find.byType(GptMarkdown)).textScaler,
        const TextScaler.linear(2));
    await tester.tap(find.byKey(const ValueKey('rtl-direction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rtl-renderer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legacy regex').last);
    await tester.pumpAndSettle();
    expect(
        // ignore: deprecated_member_use
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).incremental,
        isFalse);
    await tester.tap(find.byKey(const ValueKey('rtl-renderer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lazy sliver').last);
    await tester.pumpAndSettle();
    expect(find.byType(SliverGptMarkdown), findsOneWidget);
    final sliver =
        tester.widget<SliverGptMarkdown>(find.byType(SliverGptMarkdown));
    expect(sliver.data, rtlShowcaseMarkdown);
    expect(sliver.config.textScaler, const TextScaler.linear(2));
    expect(sliver.config.textDirection, TextDirection.rtl);
    await tester.scrollUntilVisible(
      find.byWidgetPredicate((widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('نهاية الرحلة')),
      400,
      scrollable: find
          .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable))
          .first,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
