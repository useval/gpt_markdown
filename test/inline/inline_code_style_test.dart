import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Future<void> pump(
  WidgetTester tester,
  String markdown, {
  InlineCodeStyle? inlineCodeStyle,
  GptMarkdownThemeData? theme,
  double width = 600,
  InlineCodeBuilder? inlineCodeBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: [
          theme ?? GptMarkdownThemeData(brightness: Brightness.light),
        ],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: GptMarkdown(
              markdown,
              inlineCodeStyle: inlineCodeStyle,
              inlineCodeBuilder: inlineCodeBuilder,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The paragraph render object that carries the inline-code decoration.
RenderBidiParagraph paragraphOf(WidgetTester tester) {
  return tester.renderObject<RenderBidiParagraph>(
    find.byWidgetPredicate((w) => w is BidiRichText).first,
  );
}

/// Every span in the rendered paragraphs, flattened.
List<InlineSpan> allSpans(WidgetTester tester) {
  final spans = <InlineSpan>[];
  void visit(InlineSpan span) {
    spans.add(span);
    if (span is TextSpan) {
      span.children?.forEach(visit);
    }
  }

  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    visit(rt.text);
  }
  return spans;
}

void main() {
  group('inline code spans', () {
    testWidgets('is a TextSpan, not a placeholder', (tester) async {
      await pump(tester, 'run `flutter test` now');
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      expect(code.text, 'flutter test');
      expect(allSpans(tester).whereType<WidgetSpan>(), isEmpty);
    });

    testWidgets('uses the bundled monospace family by default', (tester) async {
      await pump(tester, 'run `code` now');
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      expect(code.style?.fontFamily, 'packages/gpt_markdown/JetBrainsMono');
    });

    testWidgets('stays in the same paragraph as the surrounding text', (
      tester,
    ) async {
      await pump(tester, 'before `code` after');
      final paragraph = paragraphOf(tester);
      expect(paragraph.text.toPlainText(), 'before code after');
    });

    testWidgets('renders inside a link label', (tester) async {
      // Would have been a nested WidgetSpan under a widget-returning builder
      // — the block/buzz#6124 failure.
      await pump(tester, 'see [`code`](https://example.com) here');
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      expect(code.text, 'code');
    });

    testWidgets('inlineCodeBuilder replaces the default span', (tester) async {
      await pump(
        tester,
        'run `code` now',
        inlineCodeBuilder: (context, code, style, codeStyle) =>
            TextSpan(text: 'BUILT:$code', style: style),
      );
      expect(allSpans(tester).whereType<CodeTextSpan>(), isEmpty);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('BUILT:code'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a builder can keep the painted chip', (tester) async {
      await pump(
        tester,
        'run `code` now',
        inlineCodeBuilder: (context, code, style, codeStyle) => CodeTextSpan(
          text: code.toUpperCase(),
          codeStyle: codeStyle.copyWith(borderWidth: 0),
          style: style,
        ),
      );
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      expect(code.text, 'CODE');
      // Outline dropped by the builder, so one fill RRect and no stroke.
      expect(paragraphOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
    });

    testWidgets('baselineWidgetSpan aligns a widget on the text baseline', (
      tester,
    ) async {
      await pump(
        tester,
        'run `code` now',
        inlineCodeBuilder: (context, code, style, codeStyle) =>
            baselineWidgetSpan(Text('W:$code', style: style)),
      );
      final span = allSpans(tester).whereType<WidgetSpan>().single;
      expect(span.alignment, PlaceholderAlignment.baseline);
      expect(span.baseline, TextBaseline.alphabetic);
      expect(find.text('W:code'), findsOneWidget);
    });
  });

  group('chip painting', () {
    testWidgets('paints a fill and an outline on one line', (tester) async {
      await pump(tester, 'run `code` now');
      // One fragment: one fill RRect + one stroke RRect.
      expect(paragraphOf(tester), paintsExactlyCountTimes(#drawRRect, 2));
    });

    testWidgets('paints one chip per line when the code wraps', (tester) async {
      await pump(
        tester,
        'x `aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee` y',
        width: 160,
        inlineCodeStyle: const InlineCodeStyle(borderWidth: 0),
      );
      final paragraph = paragraphOf(tester);
      // The code run breaks over five lines at this width.
      expect(paragraph.size.height, greaterThan(100));
      // Border disabled, so each line fragment contributes exactly one RRect.
      expect(paragraph, paintsExactlyCountTimes(#drawRRect, 5));
    });

    testWidgets('paints a single chip when the same code fits one line', (
      tester,
    ) async {
      await pump(
        tester,
        'x `aaaaaaaaaa bbbbbbbbbb cccccccccc dddddddddd eeeeeeeeee` y',
        width: 2000,
        inlineCodeStyle: const InlineCodeStyle(borderWidth: 0),
      );
      expect(paragraphOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
    });

    testWidgets('draws nothing extra when there is no inline code', (
      tester,
    ) async {
      await pump(tester, 'just ordinary text');
      expect(find.byWidgetPredicate((w) => w is BidiRichText), findsNothing);
    });

    testWidgets('an outline can be switched off', (tester) async {
      await pump(
        tester,
        'run `code` now',
        inlineCodeStyle: const InlineCodeStyle(borderWidth: 0),
      );
      expect(paragraphOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
    });

    testWidgets('a fill can be switched off', (tester) async {
      await pump(
        tester,
        'run `code` now',
        inlineCodeStyle: const InlineCodeStyle(
          backgroundColor: Colors.transparent,
        ),
      );
      expect(paragraphOf(tester), paintsExactlyCountTimes(#drawRRect, 1));
    });
  });

  group('customisation', () {
    testWidgets('widget-level style overrides the theme', (tester) async {
      await pump(
        tester,
        'run `code` now',
        inlineCodeStyle: const InlineCodeStyle(
          fontFamily: 'GeistMono',
          color: Color(0xFFE01E5A),
          fontSizeFactor: 1.0,
        ),
      );
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      // A caller-supplied family is not looked up inside this package.
      expect(code.style?.fontFamily, 'GeistMono');
      expect(code.style?.color, const Color(0xFFE01E5A));
    });

    testWidgets('theme-level style applies without a widget parameter', (
      tester,
    ) async {
      await pump(
        tester,
        'run `code` now',
        theme: GptMarkdownThemeData(
          brightness: Brightness.light,
          inlineCode: const InlineCodeStyle(color: Color(0xFF00AA00)),
        ),
      );
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      expect(code.style?.color, const Color(0xFF00AA00));
      // Unset fields still come from the colour scheme.
      expect(code.style?.fontFamily, 'packages/gpt_markdown/JetBrainsMono');
    });

    testWidgets('a legacy highlightColor becomes the chip fill', (
      tester,
    ) async {
      const legacy = Color(0x33FF0000);
      await pump(
        tester,
        'run `code` now',
        theme: GptMarkdownThemeData(
          brightness: Brightness.light,
          highlightColor: legacy,
        ),
      );
      expect(paragraphOf(tester), paints..rrect(color: legacy));
    });

    testWidgets('font size scales with the surrounding text', (tester) async {
      await pump(
        tester,
        '# heading with `code`',
        inlineCodeStyle: const InlineCodeStyle(fontSizeFactor: 0.5),
      );
      final code = allSpans(tester).whereType<CodeTextSpan>().single;
      final headingSize = GptMarkdownThemeData(
        brightness: Brightness.light,
      ).h1?.fontSize;
      expect(code.style?.fontSize, closeTo(headingSize! * 0.5, 0.01));
    });
  });
}
