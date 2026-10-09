import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math;

/// A formula still arriving renders as far as it has arrived, instead of
/// being held back and appearing whole when its closing delimiter lands.
void main() {
  Widget view(
    String text, {
    GptMarkdownAnimation animation = GptMarkdownAnimation.none,
    bool dollars = false,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GptMarkdown(
          text,
          animation: animation,
          useDollarSignsForLatex: dollars,
        ),
      ),
    ),
  );

  /// The reply received so far in the current test.
  var received = '';
  setUp(() => received = '');

  /// Streams [chunks] in, appending to [received], one pump per chunk.
  Future<void> stream(
    WidgetTester tester,
    List<String> chunks, {
    GptMarkdownAnimation animation = GptMarkdownAnimation.none,
    bool dollars = false,
  }) async {
    for (final chunk in chunks) {
      received += chunk;
      await tester.pumpWidget(
        view(received, animation: animation, dollars: dollars),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Let a reveal catch up with what has arrived.
    await tester.pump(const Duration(seconds: 2));
  }

  List<String> texs(WidgetTester tester) =>
      tester.widgetList<Math>(find.byType(Math)).map((m) => m.tex).toList();

  String visibleText(WidgetTester tester) => tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .join();

  /// Opacity of the text holding [word]: the reveal fades characters in, so
  /// a restarted reveal shows here as text that is present but transparent.
  double opacityOf(WidgetTester tester, String word) {
    var opacity = 0.0;
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan && (span.text?.contains(word) ?? false)) {
          opacity = span.style?.color?.a ?? 1;
          return false;
        }
        return true;
      });
    }
    return opacity;
  }

  for (final animation in [
    GptMarkdownAnimation.none,
    GptMarkdownAnimation.fade,
  ]) {
    group('animation: ${animation.name}', () {
      testWidgets('inline maths grows before its closer arrives', (
        tester,
      ) async {
        await stream(tester, [
          'The area is ',
          r'\( \pi ',
          'r^2 + ',
        ], animation: animation);
        expect(texs(tester), [r'\pi r^2 +']);
        expect(visibleText(tester), isNot(contains(r'\(')));

        await stream(tester, ['1 \\) done.'], animation: animation);
        expect(texs(tester), [r'\pi r^2 + 1']);
      });

      testWidgets('block maths grows line by line', (tester) async {
        await stream(tester, [
          'Intro.\n\n',
          '\\[\n\\begin{aligned}\n',
          'a &= b \\\\\n',
          'c &= \\frac{1}{',
        ], animation: animation);
        expect(texs(tester), hasLength(1));
        expect(texs(tester).single, contains(r'\frac{1}{'));
        expect(visibleText(tester), isNot(contains(r'\[')));
      });

      testWidgets('a command name still arriving is held back', (tester) async {
        await stream(tester, ['Then ', r'\( x = \fra'], animation: animation);
        expect(texs(tester), ['x =']);
        expect(visibleText(tester), isNot(contains(r'\fra')));
      });

      testWidgets('dollar maths grows too', (tester) async {
        await stream(
          tester,
          ['So ', r'$x^2 + ', 'y'],
          animation: animation,
          dollars: true,
        );
        expect(texs(tester), ['x^2 + y']);

        await stream(
          tester,
          [r'$ holds.'],
          animation: animation,
          dollars: true,
        );
        expect(texs(tester), ['x^2 + y']);
      });
    });
  }

  testWidgets(r'a $$ display block grows before its closer arrives', (
    tester,
  ) async {
    await stream(tester, [
      'So:\n\n',
      '\$\$\n',
      'x^2 + \\frac{1}{',
    ], dollars: true);
    expect(texs(tester), hasLength(1));
    expect(texs(tester).single, contains(r'x^2 + \frac{1}{'));
    expect(visibleText(tester), isNot(contains(r'$$')));
  });

  testWidgets('a long dollar block closing does not restart the reveal', (
    tester,
  ) async {
    final body = List.filled(30, r'a_{i} + b_{i} \\').join('\n');
    await stream(
      tester,
      [
        'Before the block, some prose that has already been read.\n\n',
        '\$\$\n\\begin{aligned}\n$body\n',
      ],
      animation: GptMarkdownAnimation.fade,
      dollars: true,
    );
    expect(opacityOf(tester, 'already'), 1);

    // The next frame after the formula closes. A restart would blank the
    // message here and retype it from the first word.
    received += '\\end{aligned}\n\$\$';
    await tester.pumpWidget(
      view(received, animation: GptMarkdownAnimation.fade, dollars: true),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(opacityOf(tester, 'already'), 1);
  });

  group('text that is not being streamed is left as it was', () {
    testWidgets('an unclosed \\( in a finished reply stays text', (
      tester,
    ) async {
      await tester.pumpWidget(view(r'A stray \( and more text.'));
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsNothing);
      expect(visibleText(tester), contains(r'\( and more text.'));
    });

    testWidgets('an unpaired dollar in a finished reply stays text', (
      tester,
    ) async {
      await tester.pumpWidget(
        view(r'Set $HOME before running it.', dollars: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsNothing);
      expect(visibleText(tester), contains(r'$HOME'));
    });
  });
}
