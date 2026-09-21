import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';

// Measure painted glyphs, including all enclosing WidgetSpan transforms.
double glyphHeight(WidgetTester tester, String word) {
  final finder = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(word),
  );
  final paragraph = tester.renderObject<RenderParagraph>(finder.last);
  final start = paragraph.text.toPlainText().indexOf(word);
  final box =
      paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + word.length),
          )
          .first
          .toRect();
  return MatrixUtils.transformRect(paragraph.getTransformTo(null), box).height;
}

void main() {
  for (final mode in ['modern', 'legacy', 'sliver', 'maxLines']) {
    final incremental = mode != 'legacy';
    for (final explicit in [true, false]) {
      testWidgets('nested content scales once: mode=$mode explicit=$explicit', (
        tester,
      ) async {
        Future<void> pump(double scale) {
          const source =
              'prose @chip @nested {{directive}}\n\n- outer\n  - inner\n    1. deepest\n\n> quoted\n>\n> - inside';
          final patterns = [
            InlinePattern(
              pattern: RegExp(r'@chip'),
              builder:
                  (context, match, style) =>
                      WidgetSpan(child: Text('custom', style: style)),
            ),
            InlinePattern(
              pattern: RegExp(r'@nested'),
              builder:
                  (context, match, style) => TextSpan(
                    children: [
                      WidgetSpan(child: Text('wrapped', style: style)),
                    ],
                  ),
            ),
          ];
          final directives = [
            InlineDirective(
              open: '{{',
              close: '}}',
              builder:
                  (context, payload, style) =>
                      WidgetSpan(child: Text(payload, style: style)),
            ),
          ];
          final scaler = explicit ? TextScaler.linear(scale) : null;
          return tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(explicit ? 1 : scale),
                ),
                child: Scaffold(
                  body:
                      mode == 'sliver'
                          ? CustomScrollView(
                            slivers: [
                              SliverGptMarkdown(
                                source,
                                config: GptMarkdownConfig(
                                  textScaler: scaler,
                                  style: const TextStyle(fontSize: 16),
                                  inlinePatterns: patterns,
                                  inlineDirectives: directives,
                                ),
                              ),
                            ],
                          )
                          : SingleChildScrollView(
                            child: GptMarkdown(
                              source,
                              incremental: incremental,
                              maxLines: mode == 'maxLines' ? 100 : null,
                              style: const TextStyle(fontSize: 16),
                              textScaler: scaler,
                              inlinePatterns: patterns,
                              inlineDirectives: directives,
                            ),
                          ),
                ),
              ),
            ),
          );
        }

        await pump(1);
        final words = [
          'prose',
          'outer',
          'inner',
          'deepest',
          'quoted',
          'inside',
          'custom',
          'wrapped',
          'directive',
        ];
        final small = {
          for (final word in words) word: glyphHeight(tester, word),
        };
        await pump(2);
        for (final word in words) {
          expect(
            glyphHeight(tester, word) / small[word]!,
            closeTo(2, .05),
            reason: word,
          );
        }
        await pump(1);
        for (final word in words) {
          expect(glyphHeight(tester, word), closeTo(small[word]!, .01));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('direct bullet grows and returns to its original size', (
    tester,
  ) async {
    Future<double> indent(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Align(
              alignment: Alignment.topLeft,
              child: UnorderedListView(
                scalesItsOwnText: true,
                padding: 0,
                spacing: 0,
                bulletSize: 6,
                child: SizedBox(key: Key('body'), width: 10, height: 40),
              ),
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.byKey(const Key('body'))).dx -
          tester.getTopLeft(find.byType(UnorderedListView)).dx;
    }

    expect(await indent(1), 6);
    expect(await indent(2), 12);
    expect(await indent(1), 6);
  });
  testWidgets('direct ordered marker grows with its text scaler', (
    tester,
  ) async {
    Future<double> indent(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Align(
              alignment: Alignment.topLeft,
              child: OrderedListView(
                no: '12.',
                scalesItsOwnText: true,
                padding: 0,
                spacing: 0,
                style: TextStyle(fontSize: 16),
                child: SizedBox(key: Key('body'), width: 10, height: 40),
              ),
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.byKey(const Key('body'))).dx -
          tester.getTopLeft(find.byType(OrderedListView)).dx;
    }

    final small = await indent(1);
    expect(await indent(2), closeTo(small * 2, .01));
  });
}
