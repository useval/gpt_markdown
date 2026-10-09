import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math;

/// Same regression as `rtl_inline_widget_order_test.dart`, but going through
/// the real `Math.tex` builder rather than a stubbed `latexBuilder`.
void main() {
  testWidgets('real inline math keeps reading order in RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 3000,
                child: GptMarkdown(
                  r'واحد $two^2$ ثلاثة أربعة five ستة سبعة $eight^8$',
                  style: TextStyle(fontSize: 14),
                  useDollarSignsForLatex: true,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final maths = find.byType(Math);
    expect(maths, findsNWidgets(2));
    // `two^2` comes first in the source, so in RTL it must render to the right
    // of `eight^8`, and the two must not overlap.
    final first = tester.getRect(maths.at(0));
    final second = tester.getRect(maths.at(1));
    expect(
      second.right,
      lessThanOrEqualTo(first.left),
      reason: r'$eight^8$ ($second) must be left of $two^2$ ($first)',
    );
  });
}
