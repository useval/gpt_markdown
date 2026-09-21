import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

// Deliberately not linear: the multiplier varies with the base font size.
class _TestScaler extends TextScaler {
  const _TestScaler();
  @override
  double scale(double fontSize) => fontSize + 10;
  @override
  double get textScaleFactor => 1;
}

void main() {
  testWidgets('block math respects style overrides and nonlinear scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GptMarkdown(
            r'\[x^2\]',
            textScaler: _TestScaler(),
            styleSheet: GptMarkdownStyleSheet(
              latex: LatexStyle(textStyle: TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
    final math = tester.widget<Math>(find.byType(Math));
    expect(math.options!.fontSize, 34);
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['modern', 'legacy', 'sliver', 'maxLines']) {
    for (final explicit in [false, true]) {
      testWidgets('math scales once: $mode explicit=$explicit', (tester) async {
        const source =
            r'inline \(x^2\)'
            '\n\n'
            r'\[x^2\]'
            '\n\n'
            r'> \[x^2\]';
        Future<void> pump(double scale) => tester.pumpWidget(
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
                                textScaler:
                                    explicit ? TextScaler.linear(scale) : null,
                              ),
                            ),
                          ],
                        )
                        : SingleChildScrollView(
                          child: GptMarkdown(
                            source,
                            incremental: mode != 'legacy',
                            maxLines: mode == 'maxLines' ? 100 : null,
                            textScaler:
                                explicit ? TextScaler.linear(scale) : null,
                          ),
                        ),
              ),
            ),
          ),
        );
        List<Size> sizes() =>
            find.byType(Math).evaluate().map((element) {
              final box = element.renderObject! as RenderBox;
              return MatrixUtils.transformRect(
                box.getTransformTo(null),
                Offset.zero & box.size,
              ).size;
            }).toList();
        await pump(1);
        final small = sizes();
        expect(small, hasLength(3));
        await pump(2);
        final large = sizes();
        for (var i = 0; i < small.length; i++) {
          expect(
            large[i].width / small[i].width,
            closeTo(2, .05),
            reason: 'formula $i width',
          );
          expect(
            large[i].height / small[i].height,
            closeTo(2, .05),
            reason: 'formula $i height',
          );
        }
        await pump(1);
        expect(sizes(), small);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
