import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// The contract every style class in the package follows:
///
/// * unset fields fall back to the theme, then to the package default
/// * the widget wins over the theme **per field**, not per object
/// * the resolved defaults are the values used before the style existed
/// * `lerp` covers every field, so theme animation works
const _quote = '> quoted line';

Future<void> pump(
  WidgetTester tester, {
  GptMarkdownStyleSheet? widgetSheet,
  GptMarkdownStyleSheet? themeSheet,
  BlockQuoteBuilder? builder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: [
          GptMarkdownThemeData(
            brightness: Brightness.light,
            styleSheet: themeSheet,
          ),
        ],
      ),
      home: Scaffold(
        body: GptMarkdown(
          _quote,
          styleSheet: widgetSheet,
          blockQuoteBuilder: builder,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BlockQuoteWidget quoteWidget(WidgetTester tester) =>
    tester.widget<BlockQuoteWidget>(find.byType(BlockQuoteWidget));

void main() {
  group('resolve', () {
    test('fills every field with the pre-existing default', () {
      const scheme = ColorScheme.light();
      final style = const BlockQuoteStyle().resolve(scheme);

      expect(style.barWidth, 3);
      expect(style.barColor, scheme.onSurfaceVariant);
      expect(style.padding, const EdgeInsetsDirectional.only(start: 8));
      expect(style.margin, const EdgeInsets.symmetric(vertical: 2));
      expect(style.backgroundColor, isNull);
      expect(style.barRadius, isNull);
      expect(style.textStyle, isNull);
    });

    test('keeps values that are already set', () {
      const scheme = ColorScheme.light();
      final style = const BlockQuoteStyle(
        barWidth: 9,
        barColor: Color(0xFF00FF00),
      ).resolve(scheme);

      expect(style.barWidth, 9);
      expect(style.barColor, const Color(0xFF00FF00));
      expect(style.padding, const EdgeInsetsDirectional.only(start: 8));
    });
  });

  group('merge', () {
    test('is per field, not per object', () {
      const widget = BlockQuoteStyle(barWidth: 9);
      const theme = BlockQuoteStyle(
        barColor: Color(0xFFFF0000),
        margin: EdgeInsets.all(11),
      );

      final merged = widget.merge(theme);
      expect(merged.barWidth, 9, reason: 'widget wins');
      expect(merged.barColor, const Color(0xFFFF0000), reason: 'theme kept');
      expect(merged.margin, const EdgeInsets.all(11), reason: 'theme kept');
    });

    test('a null other changes nothing', () {
      const style = BlockQuoteStyle(barWidth: 9);
      expect(style.merge(null), style);
    });
  });

  group('lerp', () {
    test('returns the ends exactly', () {
      const a = BlockQuoteStyle(barWidth: 2, barColor: Color(0xFF000000));
      const b = BlockQuoteStyle(barWidth: 6, barColor: Color(0xFFFFFFFF));

      expect(BlockQuoteStyle.lerp(a, b, 0), a);
      expect(BlockQuoteStyle.lerp(a, b, 1), b);
    });

    test('interpolates every field', () {
      const a = BlockQuoteStyle(
        barWidth: 2,
        barColor: Color(0xFF000000),
        barRadius: Radius.circular(0),
        backgroundColor: Color(0xFF000000),
        padding: EdgeInsets.all(0),
        margin: EdgeInsets.all(0),
        textStyle: TextStyle(fontSize: 10),
      );
      const b = BlockQuoteStyle(
        barWidth: 6,
        barColor: Color(0xFFFFFFFF),
        barRadius: Radius.circular(8),
        backgroundColor: Color(0xFFFFFFFF),
        padding: EdgeInsets.all(8),
        margin: EdgeInsets.all(4),
        textStyle: TextStyle(fontSize: 20),
      );

      final mid = BlockQuoteStyle.lerp(a, b, 0.5);
      expect(mid, isNotNull);
      if (mid == null) {
        return;
      }
      expect(mid.barWidth, 4);
      expect(mid.barRadius, const Radius.circular(4));
      expect(mid.padding, const EdgeInsets.all(4));
      expect(mid.margin, const EdgeInsets.all(2));
      expect(mid.textStyle?.fontSize, 15);
      expect(mid.barColor, isNot(a.barColor));
      expect(mid.backgroundColor, isNot(a.backgroundColor));
    });
  });

  group('rendering', () {
    testWidgets('defaults when nothing is set', (tester) async {
      await pump(tester);
      expect(quoteWidget(tester).width, 3);
    });

    testWidgets('the theme applies', (tester) async {
      await pump(
        tester,
        themeSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barWidth: 7),
        ),
      );
      expect(quoteWidget(tester).width, 7);
    });

    testWidgets('the widget wins over the theme', (tester) async {
      await pump(
        tester,
        themeSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barWidth: 7),
        ),
        widgetSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barWidth: 9),
        ),
      );
      expect(quoteWidget(tester).width, 9);
    });

    testWidgets('a widget override keeps the theme for other fields', (
      tester,
    ) async {
      const themeColor = Color(0xFFFF0000);
      await pump(
        tester,
        themeSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barColor: themeColor),
        ),
        widgetSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barWidth: 9),
        ),
      );
      final quote = quoteWidget(tester);
      expect(quote.width, 9, reason: 'from the widget');
      expect(quote.color, themeColor, reason: 'still from the theme');
    });

    testWidgets('a background is only drawn when asked for', (tester) async {
      await pump(tester);
      final before = find.byType(DecoratedBox).evaluate().length;

      await pump(
        tester,
        widgetSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(backgroundColor: Color(0xFF00FF00)),
        ),
      );
      expect(find.byType(DecoratedBox).evaluate().length, before + 1);
    });

    testWidgets('the builder replaces the whole quote', (tester) async {
      await pump(
        tester,
        builder: (context, content, style) => Row(
          children: [
            const Text('CUSTOM'),
            Flexible(child: content),
          ],
        ),
      );
      expect(find.text('CUSTOM'), findsOneWidget);
      expect(find.byType(BlockQuoteWidget), findsNothing);
    });

    testWidgets('the builder receives the resolved style', (tester) async {
      BlockQuoteStyle? seen;
      await pump(
        tester,
        themeSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barWidth: 5),
        ),
        builder: (context, content, style) {
          seen = style;
          return content;
        },
      );
      expect(seen?.barWidth, 5);
      expect(seen?.barColor, isNotNull);
      expect(seen?.padding, isNotNull);
    });
  });
}
