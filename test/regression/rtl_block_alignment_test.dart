import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/custom_widgets/custom_rb_cb.dart';

const _source =
    '## عنوان\n\n1. أول\n2. العنصر الثاني الأطول\n\n'
    '- أول\n- العنصر الثاني الأطول\n\n> اقتباس\n\n- [x] تمت\n\n(x) مختار\n\n\\[x^2\\]';

void main() {
  testWidgets('RTL document keeps code and horizontal code scrolling LTR', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GptMarkdown(
          '```dart\nfinal result = 1;\n```',
          textDirection: TextDirection.rtl,
        ),
      ),
    );
    final scroll = find.descendant(
      of: find.byType(CodeField),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.widget<Scrollable>(scroll).axisDirection,
      AxisDirection.right,
    );
    final text = find.descendant(
      of: find.byType(CodeField),
      matching: find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'final result = 1;',
      ),
    );
    expect(
      tester.renderObject<RenderParagraph>(text).textDirection,
      TextDirection.ltr,
    );
  });
  for (final mode in ['modern', 'legacy', 'sliver', 'legacy sliver']) {
    testWidgets(
      '$mode blocks follow configured direction, not page direction',
      (tester) async {
        final headingDirections = <TextDirection>[];
        Widget heading(
          BuildContext context,
          int level,
          Widget child,
          HeadingStyle style,
        ) {
          headingDirections.add(Directionality.of(context));
          return const SizedBox(
            key: ValueKey('heading'),
            width: 90,
            height: 25,
          );
        }

        Widget view(TextDirection direction) {
          final config = GptMarkdownConfig(
            textDirection: direction,
            style: const TextStyle(fontSize: 16),
            headingBuilder: heading,
            latexBuilder:
                (_, _, _, _) => const SizedBox(
                  key: ValueKey('math'),
                  width: 64,
                  height: 24,
                ),
            components:
                mode == 'legacy sliver'
                    ? MarkdownComponent.globalComponents
                    : null,
          );
          final Widget content;
          if (mode.contains('sliver')) {
            content = CustomScrollView(
              slivers: [SliverGptMarkdown(_source, config: config)],
            );
          } else {
            content = SingleChildScrollView(
              child: GptMarkdown(
                _source,
                textDirection: direction,
                style: const TextStyle(fontSize: 16),
                incremental: mode != 'legacy',
                headingBuilder: heading,
                latexBuilder:
                    (_, _, _, _) => const SizedBox(
                      key: ValueKey('math'),
                      width: 64,
                      height: 24,
                    ),
              ),
            );
          }
          return MaterialApp(
            home: Directionality(
              textDirection:
                  direction == TextDirection.rtl
                      ? TextDirection.ltr
                      : TextDirection.rtl,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: const ValueKey('frame'),
                  width: 320,
                  height: 580,
                  child: Material(child: content),
                ),
              ),
            ),
          );
        }

        final leadingOffsets = <String, List<double>>{};
        for (final direction in [
          TextDirection.ltr,
          TextDirection.rtl,
          TextDirection.ltr,
          TextDirection.rtl,
        ]) {
          headingDirections.clear();
          await tester.pumpWidget(view(direction));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(headingDirections, isNotEmpty);
          expect(headingDirections, everyElement(direction));
          final frame = tester.getRect(find.byKey(const ValueKey('frame')));
          for (final finder in [
            find.byKey(const ValueKey('heading')),
            find.byType(OrderedListView),
            find.byType(UnorderedListView),
            find.byType(BlockQuoteWidget),
            find.byType(CustomCb),
            find.byType(CustomRb),
            find.byKey(const ValueKey('math')),
          ]) {
            expect(finder, findsWidgets);
            final rects =
                finder
                    .evaluate()
                    .map(
                      (element) =>
                          tester.getRect(find.byWidget(element.widget)),
                    )
                    .toList();
            final id = finder.describeMatch(Plurality.many);
            if (direction == TextDirection.ltr) {
              leadingOffsets[id] =
                  rects.map((rect) => rect.left - frame.left).toList();
            } else {
              final offsets = leadingOffsets[id]!;
              expect(rects.length, offsets.length);
              for (var i = 0; i < rects.length; i++) {
                // Task-list markers have intentional inset; mirror it instead
                // of requiring every nested widget to touch the document edge.
                expect(
                  rects[i].right,
                  closeTo(frame.right - offsets[i], .5),
                  reason: '$id item $i must mirror its LTR leading inset',
                );
              }
            }
          }
        }
      },
    );
  }
}
