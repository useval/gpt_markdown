import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Regression tests for inline widgets rendering in reverse order inside
/// right-to-left paragraphs (flutter/flutter#54400).
///
/// Inline LaTeX is replaced by a fixed-size box per formula so the assertions
/// depend on layout only, not on font metrics or math-renderer internals.

const _mathWidths = <String, double>{
  'one^1': 30,
  'two^2': 40,
  'three^3': 60,
  'four^4': 90,
  'eight^8': 400,
};

Widget _app(
  String markdown, {
  required TextDirection direction,
  bool dollars = true,
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
              useDollarSignsForLatex: dollars,
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

Rect _rectOf(WidgetTester tester, String tex) =>
    tester.getRect(find.byKey(ValueKey('tex:$tex')));

/// Asserts that [texts] — given in logical (reading) order — are laid out
/// right to left without overlapping, on a single line.
void _expectRtlOrder(WidgetTester tester, List<String> texts) {
  final rects = [for (final t in texts) _rectOf(tester, t)];
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      expect(
        rects[j].right,
        lessThanOrEqualTo(rects[i].left),
        reason:
            '"${texts[j]}" (${rects[j]}) must sit entirely to the left of '
            '"${texts[i]}" (${rects[i]})',
      );
    }
  }
}

void _expectLtrOrder(WidgetTester tester, List<String> texts) {
  final rects = [for (final t in texts) _rectOf(tester, t)];
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      expect(
        rects[i].right,
        lessThanOrEqualTo(rects[j].left),
        reason:
            '"${texts[i]}" (${rects[i]}) must sit entirely to the left of '
            '"${texts[j]}" (${rects[j]})',
      );
    }
  }
}

void main() {
  testWidgets('two formulas in an RTL paragraph keep reading order', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        r'واحد $two^2$ ثلاثة أربعة five ستة سبعة $eight^8$',
        direction: TextDirection.rtl,
      ),
    );
    _expectRtlOrder(tester, ['two^2', 'eight^8']);
  });

  testWidgets(r'the \(...\) syntax behaves the same', (tester) async {
    await tester.pumpWidget(
      _app(
        r'واحد \(two^2\) ثلاثة أربعة five ستة سبعة \(eight^8\)',
        direction: TextDirection.rtl,
        dollars: false,
      ),
    );
    _expectRtlOrder(tester, ['two^2', 'eight^8']);
  });

  testWidgets('four formulas in an RTL paragraph', (tester) async {
    await tester.pumpWidget(
      _app(
        r'واحد $one^1$ اثنان $two^2$ ثلاثة $three^3$ أربعة $four^4$ خمسة',
        direction: TextDirection.rtl,
      ),
    );
    _expectRtlOrder(tester, ['one^1', 'two^2', 'three^3', 'four^4']);
  });

  testWidgets('formulas stay ordered when the paragraph wraps', (tester) async {
    // Narrow enough that the four formulas land on more than one line.
    await tester.pumpWidget(
      _app(
        r'واحد $one^1$ اثنان $two^2$ ثلاثة $three^3$ أربعة $four^4$ خمسة',
        direction: TextDirection.rtl,
        width: 260,
      ),
    );
    final rects = {
      for (final t in ['one^1', 'two^2', 'three^3', 'four^4'])
        t: _rectOf(tester, t),
    };
    // More than one line, otherwise this test is not exercising wrapping.
    final tops = rects.values.map((r) => r.top).toSet();
    expect(tops.length, greaterThan(1), reason: 'expected the text to wrap');

    // Within every line, reading order must run right to left; and later lines
    // must sit below earlier ones.
    final byLine = <double, List<MapEntry<String, Rect>>>{};
    for (final e in rects.entries) {
      byLine.putIfAbsent(e.value.top, () => []).add(e);
    }
    final order = ['one^1', 'two^2', 'three^3', 'four^4'];
    for (final line in byLine.values) {
      line.sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
      for (var i = 1; i < line.length; i++) {
        expect(
          line[i].value.right,
          lessThanOrEqualTo(line[i - 1].value.left),
          reason:
              '${line[i].key} must be left of ${line[i - 1].key} on their line',
        );
      }
    }
    for (var i = 1; i < order.length; i++) {
      expect(
        rects[order[i]]!.top,
        greaterThanOrEqualTo(rects[order[i - 1]]!.top),
        reason: '${order[i]} must not move to an earlier line',
      );
    }
  });

  testWidgets('a single formula in RTL is untouched', (tester) async {
    await tester.pumpWidget(
      _app(r'واحد $two^2$ ثلاثة أربعة', direction: TextDirection.rtl),
    );
    // Only one placeholder, so the plain Text path is used.
    expect(find.byType(BidiRichText), findsNothing);
    final math = _rectOf(tester, 'two^2');
    final paragraph = tester.getRect(find.byType(RichText).first);
    expect(math.left, greaterThan(paragraph.left));
  });

  testWidgets('an all-latin document never takes the workaround path', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(r'one $one^1$ two $two^2$ three', direction: TextDirection.ltr),
    );
    expect(find.byType(BidiRichText), findsNothing);
    _expectLtrOrder(tester, ['one^1', 'two^2']);
  });

  testWidgets('an all-latin line inside an RTL document stays LTR', (
    tester,
  ) async {
    // The Arabic word puts the document on the workaround path, but the
    // formulas sit inside a latin run, so their order must not be flipped.
    await tester.pumpWidget(
      _app(
        r'hello $one^1$ middle $two^2$ world  عربي',
        direction: TextDirection.rtl,
      ),
    );
    expect(find.byType(BidiRichText), findsOneWidget);
    _expectLtrOrder(tester, ['one^1', 'two^2']);
  });

  testWidgets('an LTR paragraph containing RTL text is fixed too', (
    tester,
  ) async {
    // Paragraph direction is LTR but both formulas are surrounded by Arabic,
    // so both resolve to an RTL run and must read right to left.
    await tester.pumpWidget(
      _app(
        r'واحد $two^2$ ثلاثة أربعة $eight^8$ خمسة',
        direction: TextDirection.ltr,
      ),
    );
    expect(find.byType(BidiRichText), findsOneWidget);
    _expectRtlOrder(tester, ['two^2', 'eight^8']);
  });

  testWidgets('a trailing formula in an LTR paragraph is left alone', (
    tester,
  ) async {
    // Nothing follows the last formula, so with an LTR base direction it
    // resolves to the paragraph level and belongs on the right — the engine
    // already gets this right and the workaround must not "fix" it.
    await tester.pumpWidget(
      _app(r'واحد $two^2$ ثلاثة أربعة $eight^8$', direction: TextDirection.ltr),
    );
    _expectLtrOrder(tester, ['two^2', 'eight^8']);
  });

  testWidgets('mixed-direction placeholders on one line follow UAX#9', (
    tester,
  ) async {
    // Raw spans: p0 is neutral between Arabic and latin (so it resolves RTL),
    // p1 and p2 sit inside one latin run (so they resolve LTR and keep their
    // order relative to each other).
    //   logical : אאא [p0] hello [p1] mid [p2] world בבב
    //   correct : p1, p2, p0   (left to right)
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 3000,
              child: BidiText(
                const TextSpan(
                  style: TextStyle(fontSize: 10),
                  children: [
                    TextSpan(text: 'אאא '),
                    WidgetSpan(
                      child: SizedBox(
                        key: ValueKey('p0'),
                        width: 10,
                        height: 10,
                      ),
                    ),
                    TextSpan(text: ' hello '),
                    WidgetSpan(
                      child: SizedBox(
                        key: ValueKey('p1'),
                        width: 20,
                        height: 10,
                      ),
                    ),
                    TextSpan(text: ' mid '),
                    WidgetSpan(
                      child: SizedBox(
                        key: ValueKey('p2'),
                        width: 40,
                        height: 10,
                      ),
                    ),
                    TextSpan(text: ' world '),
                    TextSpan(text: 'בבב'),
                  ],
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        ),
      ),
    );
    Rect r(String k) => tester.getRect(find.byKey(ValueKey(k)));
    expect(r('p1').right, lessThanOrEqualTo(r('p2').left));
    expect(r('p2').right, lessThanOrEqualTo(r('p0').left));
  });
}
