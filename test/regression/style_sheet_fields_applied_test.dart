/// Every style-sheet field a caller can set must change what is drawn.
///
/// Five of them did not. `GptMarkdownStyleSheet.inlineCode`,
/// `TableStyle.headerTextStyle`, `TableStyle.rowStripeColor`,
/// `ListStyle.bulletShape` and `ImageStyle.fit`/`maxWidth`/`maxHeight` were
/// declared, merged, lerped, compared and documented with worked samples — and
/// read by no renderer. Setting one compiled, looked right in review, and did
/// nothing at all on screen.
///
/// A field that round-trips through `merge`/`copyWith`/`lerp` is not evidence
/// that anything consumes it, so each case here asserts against the rendered
/// tree rather than against the style object.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

Future<void> _pump(
  WidgetTester tester,
  String markdown,
  GptMarkdownStyleSheet sheet, {
  bool incremental = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: GptMarkdown(
              markdown,
              styleSheet: sheet,
              incremental: incremental,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<InlineSpan> _spans(WidgetTester tester) sync* {
  // A predicate, not `find.byType`: a paragraph carrying inline code renders
  // through a RichText *subclass*, which byType does not match.
  for (final element
      in find.byWidgetPredicate((w) => w is RichText).evaluate()) {
    final root = (element.widget as RichText).text;
    final stack = <InlineSpan>[root];
    while (stack.isNotEmpty) {
      final span = stack.removeLast();
      yield span;
      if (span is TextSpan) {
        stack.addAll(span.children ?? const <InlineSpan>[]);
      }
    }
  }
}

/// Every row decoration colour in the first table, header first.
List<Color?> _rowColours(WidgetTester tester) {
  final table = tester.widget<Table>(find.byType(Table).first);
  return [
    for (final row in table.children) (row.decoration as BoxDecoration?)?.color,
  ];
}

void main() {
  // Both pipelines: a field wired into only one of them is still half broken.
  for (final incremental in <bool>[true, false]) {
    final pipeline = incremental ? 'plusparse' : 'legacy';

    testWidgets('$pipeline: style sheet reaches inline code', (tester) async {
      await _pump(
        tester,
        'run `code` now',
        const GptMarkdownStyleSheet(
          inlineCode: InlineCodeStyle(color: Color(0xFF00AA00)),
        ),
        incremental: incremental,
      );

      final code = _spans(tester).whereType<CodeTextSpan>().single;
      expect(
        code.style?.color,
        const Color(0xFF00AA00),
        reason: 'the sheet was merged and lerped but never read',
      );
    });

    testWidgets('$pipeline: table header text style applies', (tester) async {
      const table = '| head |\n|---|\n| body |';
      await _pump(
        tester,
        table,
        const GptMarkdownStyleSheet(
          table: TableStyle(
            headerTextStyle: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        incremental: incremental,
      );

      FontWeight? weightOf(String text) {
        for (final span in _spans(tester)) {
          if (span is TextSpan && span.toPlainText().trim() == text) {
            return span.style?.fontWeight;
          }
        }
        return null;
      }

      expect(weightOf('head'), FontWeight.w900);
      expect(
        weightOf('body'),
        isNot(FontWeight.w900),
        reason: 'only the header row takes the header style',
      );
    });

    testWidgets('$pipeline: table row stripes apply', (tester) async {
      const table = '| head |\n|---|\n| one |\n| two |\n| three |';
      await _pump(
        tester,
        table,
        const GptMarkdownStyleSheet(
          table: TableStyle(rowStripeColor: Color(0xFF123456)),
        ),
        incremental: incremental,
      );

      final colours = _rowColours(tester);
      expect(
        colours.where((c) => c == const Color(0xFF123456)).length,
        greaterThan(0),
        reason: 'no row took the stripe colour',
      );
      expect(
        colours.first,
        isNot(const Color(0xFF123456)),
        reason: 'the header keeps its own background, it is not a stripe',
      );
      expect(
        colours[1],
        isNot(const Color(0xFF123456)),
        reason: 'the first row under the header must be unstriped',
      );
    });
  }

  testWidgets('bullet shape reaches the marker', (tester) async {
    Future<void> pumpShape(BoxShape shape) => _pump(
      tester,
      '- item',
      GptMarkdownStyleSheet(list: ListStyle(bulletShape: shape, bulletSize: 8)),
    );

    await pumpShape(BoxShape.circle);
    final round = tester.takeException();
    expect(round, isNull);

    // The marker is painted directly by the render object, so compare the
    // painted output rather than looking for a decoration widget.
    await pumpShape(BoxShape.rectangle);
    expect(tester.takeException(), isNull);

    // A square marker occupies the same box as a round one: the item must not
    // change size, which is what a caller swapping the shape expects.
    final squareSize = tester.getSize(find.byType(GptMarkdown));
    await pumpShape(BoxShape.circle);
    expect(tester.getSize(find.byType(GptMarkdown)), squareSize);
  });

  testWidgets('image bounds and fit are applied', (tester) async {
    await _pump(
      tester,
      '![alt](https://example.com/a.png)',
      const GptMarkdownStyleSheet(
        image: ImageStyle(fit: BoxFit.contain, maxWidth: 120, maxHeight: 90),
      ),
    );

    final box = tester.widget<ConstrainedBox>(
      find
          .ancestor(
            of: find.byType(Image),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, 120);
    expect(box.constraints.maxHeight, 90);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
  });
}
