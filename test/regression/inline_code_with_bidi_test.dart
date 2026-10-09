import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Inline-code chips and the right-to-left placeholder reordering share one
/// paragraph render object. These check that adding the chips did not disturb
/// the reordering, and that the reordering's probe layout is skipped when it
/// cannot be needed.

const _mathWidths = <String, double>{'one^1': 30, 'two^2': 40};

Widget _app(
  String markdown, {
  required TextDirection direction,
  double width = 3000,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: GptMarkdown(
              markdown,
              style: const TextStyle(fontSize: 10),
              useDollarSignsForLatex: true,
              textDirection: direction,
              latexBuilder: (context, tex, style, inline) => SizedBox(
                key: ValueKey('tex:$tex'),
                width: _mathWidths[tex] ?? 50,
                height: 10,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderBidiParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderBidiParagraph>(
      find.byWidgetPredicate((w) => w is BidiRichText).first,
    );

void main() {
  testWidgets('RTL placeholders stay in visual order with inline code', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        r'واحد $one^1$ `code` ثلاثة أربعة five $two^2$',
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = _paragraph(tester);
    expect(paragraph.bidiEnabled, isTrue);
    expect(paragraph.inlineCodeRuns, hasLength(1));

    // Logical order one^1 then two^2 must lay out right to left.
    final first = tester.getRect(find.byKey(const ValueKey('tex:one^1')));
    final second = tester.getRect(find.byKey(const ValueKey('tex:two^2')));
    expect(first.left, greaterThan(second.right));

    // The chip is still painted: one fill plus one outline.
    expect(paragraph, paintsExactlyCountTimes(#drawRRect, 2));
  });

  testWidgets('the bidi probe is skipped for a left-to-right paragraph', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        r'one $one^1$ `code` two $two^2$ three',
        direction: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = _paragraph(tester);
    // Two placeholders, but no RTL text — reordering cannot apply, so the
    // probe layout must not run even though the paragraph is ours.
    expect(paragraph.bidiEnabled, isFalse);
    expect(paragraph.inlineCodeRuns, hasLength(1));
    expect(paragraph, paintsExactlyCountTimes(#drawRRect, 2));
  });

  testWidgets('an RTL paragraph with no inline code still reorders', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        r'واحد $one^1$ ثلاثة أربعة five $two^2$',
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = _paragraph(tester);
    expect(paragraph.bidiEnabled, isTrue);
    expect(paragraph.inlineCodeRuns, isEmpty);
    expect(paragraph, paintsExactlyCountTimes(#drawRRect, 0));

    final first = tester.getRect(find.byKey(const ValueKey('tex:one^1')));
    final second = tester.getRect(find.byKey(const ValueKey('tex:two^2')));
    expect(first.left, greaterThan(second.right));
  });
}
