import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math;

/// Issue #108. With `useDollarSignsForLatex`, a `$$` or `$` written inside
/// inline code (a reply explaining LaTeX syntax) paired with a real formula
/// further down, and everything between rendered as garbled maths.

Future<int> _formulas(WidgetTester tester, String data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(data, useDollarSignsForLatex: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return find.byType(Math).evaluate().length;
}

void main() {
  testWidgets('a `\$\$` in inline code does not open a display formula', (
    tester,
  ) async {
    const data =
        '- `\$\$` is not closed\n'
        '- `\$\$\\frac{a+b}{2}` is not wrapped\n'
        '- some use `\$\$...\$\$` across lines\n'
        '\n'
        '\$\$\n'
        '\\frac{a + b}{2} \\geq \\sqrt{ab}\n'
        '\$\$\n';
    expect(await _formulas(tester, data), 1);
  });

  testWidgets(
    'a `\$` in a heading code span does not pair with the next line',
    (tester) async {
      const data =
          '### 1. **Inline**: wrap in a single `\$`\n'
          '```markdown\n'
          '\$ \\frac{a + b}{2} \$\n'
          '```\n'
          'shown as: \$ \\frac{a + b}{2} \$\n';
      expect(await _formulas(tester, data), 1);
    },
  );
}
