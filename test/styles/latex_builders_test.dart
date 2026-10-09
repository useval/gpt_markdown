import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math, MathSpan;

/// `inlineLatexBuilder`, `blockLatexBuilder` and `onLatexTap`, and the
/// deprecated `latexBuilder` they replace.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget markdown, {
    double textScale = 1,
    bool selectable = false,
  }) async {
    Widget body = SingleChildScrollView(child: markdown);
    if (selectable) body = SelectionArea(child: body);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String plainText(WidgetTester tester) => tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .join();

  for (final legacy in [false, true]) {
    final pipeline = legacy ? 'legacy' : 'plusparse';

    group(pipeline, () {
      GptMarkdown markdown(
        String text, {
        InlineLatexBuilder? inline,
        BlockLatexBuilder? block,
        LatexBuilder? deprecated,
        void Function(LatexTapDetails)? onTap,
        String Function(String)? workaround,
        GptMarkdownStyleSheet? styleSheet,
      }) => GptMarkdown(
        text,
        inlineComponents: legacy ? MarkdownComponent.inlineComponents : null,
        inlineLatexBuilder: inline,
        blockLatexBuilder: block,
        // ignore: deprecated_member_use_from_same_package
        latexBuilder: deprecated,
        onLatexTap: onTap,
        latexWorkaround: workaround,
        styleSheet: styleSheet,
      );

      testWidgets('inlineLatexBuilder builds the span, with source and tex', (
        tester,
      ) async {
        InlineLatexBuildDetails? seen;
        await pump(
          tester,
          markdown(
            r'Area \(\pi r^2\) here.',
            workaround: (tex) => tex.replaceAll('r', 'R'),
            inline: (latex) {
              seen = latex;
              return TextSpan(text: '[${latex.tex}]');
            },
          ),
        );
        expect(seen!.source, r'\pi r^2');
        expect(seen!.tex, r'\pi R^2');
        expect(plainText(tester), contains(r'[\pi R^2]'));
        expect(find.byType(Math), findsNothing);
      });

      testWidgets('defaultSpan is the stock formula', (tester) async {
        await pump(
          tester,
          markdown(
            r'Area \(\pi r^2\).',
            inline: (latex) => latex.defaultSpan(),
          ),
        );
        expect(tester.widget<Math>(find.byType(Math)).tex, r'\pi r^2');
      });

      testWidgets('a returned MathSpan scales once, like the default', (
        tester,
      ) async {
        Future<Size> size(double scale, InlineLatexBuilder? builder) async {
          await pump(
            tester,
            markdown(r'Area \(\pi r^2\).', inline: builder),
            textScale: scale,
          );
          // On screen, through the paragraph's transform: a paragraph scales
          // its placeholders rather than laying them out larger.
          final box = tester.renderObject<RenderBox>(find.byType(Math));
          return MatrixUtils.transformRect(
            box.getTransformTo(null),
            Offset.zero & box.size,
          ).size;
        }

        InlineSpan mathSpan(InlineLatexBuildDetails latex) =>
            MathSpan(latex.tex, style: latex.style.copyWith(fontSize: 16));
        for (final builder in <InlineLatexBuilder?>[null, mathSpan]) {
          final small = await size(1, builder);
          final large = await size(2, builder);
          expect(large.width / small.width, closeTo(2, 0.05));
          expect(large.height / small.height, closeTo(2, 0.05));
        }
      });
    });

    testWidgets('$pipeline: a deprecated latexBuilder still runs where no new '
        'builder is set', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Inline \\(a\\).\n\n\\[b\\]',
              inlineComponents: legacy
                  ? MarkdownComponent.inlineComponents
                  : null,
              inlineLatexBuilder: (latex) => const TextSpan(text: 'NEW'),
              // ignore: deprecated_member_use_from_same_package
              latexBuilder: (context, tex, style, inline) {
                calls.add(inline);
                return Text('OLD $tex');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(plainText(tester), contains('NEW'));
      expect(find.text('OLD b'), findsOneWidget);
      expect(calls, [false], reason: 'never consulted for inline maths');
    });
  }

  group('blockLatexBuilder', () {
    testWidgets('builds the widget, and wins over latexBuilder', (
      tester,
    ) async {
      BlockLatexBuildDetails? seen;
      await pump(
        tester,
        GptMarkdown(
          r'\[x^2\]',
          blockLatexBuilder: (latex) {
            seen = latex;
            return Text('BLOCK ${latex.tex}');
          },
          // ignore: deprecated_member_use_from_same_package
          latexBuilder: (context, tex, style, inline) => const Text('OLD'),
        ),
      );
      expect(seen!.source, 'x^2');
      expect(find.text('BLOCK x^2'), findsOneWidget);
      expect(find.text('OLD'), findsNothing);
    });

    testWidgets('LatexStyle still wraps what it returns', (tester) async {
      const background = Color(0xFF123456);
      await pump(
        tester,
        GptMarkdown(
          r'\[x^2\]',
          blockLatexBuilder: (latex) => const Text('BLOCK'),
          styleSheet: const GptMarkdownStyleSheet(
            latex: LatexStyle(
              backgroundColor: background,
              padding: EdgeInsets.all(13),
            ),
          ),
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('BLOCK'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, background);
      expect(
        find.ancestor(
          of: find.text('BLOCK'),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == const EdgeInsets.all(13),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('defaultWidget is the stock formula', (tester) async {
      await pump(
        tester,
        GptMarkdown(
          r'\[x^2\]',
          blockLatexBuilder: (latex) => latex.defaultWidget(),
        ),
      );
      expect(tester.widget<Math>(find.byType(Math)).tex, 'x^2');
    });
  });

  group('onLatexTap', () {
    testWidgets('the default inline formula reports the formula and the part '
        'tapped', (tester) async {
      final taps = <LatexTapDetails>[];
      await pump(
        tester,
        GptMarkdown(r'Area \(\pi r^2\) here.', onLatexTap: taps.add),
      );
      await tester.tap(find.byType(Math));
      expect(taps, hasLength(1));
      expect(taps.single.source, r'\pi r^2');
      expect(taps.single.inline, isTrue);
      expect(taps.single.tappedTex, isNotNull);
    });

    testWidgets('the default block formula reports inline: false', (
      tester,
    ) async {
      final taps = <LatexTapDetails>[];
      await pump(tester, GptMarkdown(r'\[x^2 + y^2\]', onLatexTap: taps.add));
      await tester.tap(find.byType(Math));
      expect(taps.single.inline, isFalse);
      expect(taps.single.source, 'x^2 + y^2');
    });

    testWidgets('still fires inside a SelectionArea', (tester) async {
      final taps = <LatexTapDetails>[];
      await pump(
        tester,
        GptMarkdown(r'Area \(\pi r^2\) here.', onLatexTap: taps.add),
        selectable: true,
      );
      await tester.tap(find.byType(Math));
      expect(taps, hasLength(1));
    });

    testWidgets('reaches a builder\'s own formula through details.onTap', (
      tester,
    ) async {
      final taps = <LatexTapDetails>[];
      await pump(
        tester,
        GptMarkdown(
          r'Area \(\pi r^2\).',
          onLatexTap: taps.add,
          inlineLatexBuilder: (latex) => latex.asWidgetSpan(
            GestureDetector(onTap: latex.onTap, child: const Text('F')),
          ),
        ),
      );
      await tester.tap(find.text('F'));
      expect(taps.single.source, r'\pi r^2');
      expect(taps.single.tappedTex, isNull);
    });

    testWidgets('without a handler a formula is not a tap target', (
      tester,
    ) async {
      await pump(tester, GptMarkdown(r'Area \(\pi r^2\).'));
      expect(tester.widget<Math>(find.byType(Math)).onTap, isNull);
    });
  });
}
