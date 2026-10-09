import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `TableStyle.overflow` (#93): a table wider than the screen scrolls by
/// default, and wraps its cells to fit with [TableOverflow.wrap].

const _wide =
    '| Feature | Description | Notes |\n'
    '|---|---|---|\n'
    '| Streaming | Renders partial markdown while the model is still writing '
    'the reply, one chunk at a time | Works with every block type |\n'
    '| Tables | Column widths follow the content of the widest cell in each '
    'column of the table | Scrolls or wraps |';

const _width = 360.0;

Future<void> _pump(
  WidgetTester tester, {
  TableStyle? table,
  bool legacy = false,
  double textScale = 1,
  bool intrinsicWidth = false,
}) async {
  tester.view.physicalSize = const Size(_width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget markdown = GptMarkdown(
    _wide,
    styleSheet: GptMarkdownStyleSheet(table: table),
    inlineComponents: legacy ? MarkdownComponent.inlineComponents : null,
  );
  if (intrinsicWidth) {
    markdown = IntrinsicWidth(child: markdown);
  }
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(_width, 1200),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: markdown)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _table => find.byType(Table);

/// The last cell of [_wide]; a table's own rect is clamped to its constraints
/// even when its columns run past them.
Finder get _lastCell => _cell('Scrolls or wraps');

/// The paragraph holding exactly [text].
Finder _cell(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText() == text,
);

Finder get _horizontalScroll => find.ancestor(
  of: _table,
  matching: find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
  ),
);

void main() {
  test('overflow defaults to scroll and takes part in merge and equality', () {
    expect(
      const TableStyle().resolve(const ColorScheme.light()).overflow,
      TableOverflow.scroll,
    );
    const wrap = TableStyle(overflow: TableOverflow.wrap);
    expect(const TableStyle().merge(wrap).overflow, TableOverflow.wrap);
    expect(
      const TableStyle(overflow: TableOverflow.scroll).merge(wrap).overflow,
      TableOverflow.scroll,
    );
    expect(const TableStyle().copyWith(overflow: TableOverflow.wrap), wrap);
    expect(wrap == const TableStyle(), isFalse);
    expect(wrap.hashCode, isNot(const TableStyle().hashCode));
    expect(
      TableStyle.lerp(const TableStyle(), wrap, 0.7)!.overflow,
      TableOverflow.wrap,
    );
  });

  for (final legacy in [false, true]) {
    final pipeline = legacy ? 'legacy' : 'plusparse';

    testWidgets('$pipeline: a wide table scrolls by default', (tester) async {
      await _pump(tester, legacy: legacy);
      expect(tester.takeException(), isNull);
      expect(_horizontalScroll, findsOneWidget);
      expect(tester.getSize(_table).width, greaterThan(_width));
    });

    for (final textScale in [1.0, 2.0, 3.0]) {
      testWidgets('$pipeline: wrap fits the table to the screen '
          'at ${textScale}x', (tester) async {
        await _pump(tester, legacy: legacy, textScale: textScale);
        final scrolledHeight = tester.getSize(_table).height;

        await _pump(
          tester,
          legacy: legacy,
          textScale: textScale,
          table: const TableStyle(overflow: TableOverflow.wrap),
        );
        expect(tester.takeException(), isNull);
        expect(_horizontalScroll, findsNothing);
        final rect = tester.getRect(_table);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(tester.getRect(_lastCell).right, lessThanOrEqualTo(_width));
        // Same rows, narrower columns: the cells wrapped onto more lines.
        expect(rect.height, greaterThan(scrolledHeight));
      });
    }

    testWidgets('$pipeline: wrap lets a flex column width fill the screen', (
      tester,
    ) async {
      await _pump(
        tester,
        legacy: legacy,
        table: const TableStyle(
          overflow: TableOverflow.wrap,
          columnWidth: FlexColumnWidth(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_lastCell).right, lessThanOrEqualTo(_width));
      expect(tester.getSize(_table).width, greaterThan(_width / 2));
    });

    testWidgets('$pipeline: a narrow table is untouched by wrap', (
      tester,
    ) async {
      Future<Size> sizeOf(TableStyle? table) async {
        tester.view.physicalSize = const Size(_width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GptMarkdown(
                '| a | b |\n|---|---|\n| 1 | 2 |',
                styleSheet: GptMarkdownStyleSheet(table: table),
                inlineComponents: legacy
                    ? MarkdownComponent.inlineComponents
                    : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(_table);
      }

      final scrolled = await sizeOf(null);
      final wrapped = await sizeOf(
        const TableStyle(overflow: TableOverflow.wrap),
      );
      expect(wrapped, scrolled);
    });
  }

  testWidgets('wrap keeps short columns whole and still fits many columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(_width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GptMarkdown(
            '$_wide\n\n'
            '| c1 | c2 | c3 | c4 | c5 | c6 | c7 | c8 | c9 | c10 |\n'
            '|---|---|---|---|---|---|---|---|---|---|\n'
            '| alpha | beta | gamma | delta | epsilon | zeta | eta | theta '
            '| iota | kappa |',
            styleSheet: GptMarkdownStyleSheet(
              table: TableStyle(overflow: TableOverflow.wrap),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // A table's own size is clamped to its constraints even when its columns
    // run past them, so check the cells, not the table.
    expect(tester.getRect(_cell('kappa')).right, lessThanOrEqualTo(_width));
    expect(tester.getRect(_cell('Notes')).right, lessThanOrEqualTo(_width));
    // "Feature" is one line, as tall as the "Notes" header beside it: its
    // column did not shrink below the word.
    expect(
      tester.getSize(_cell('Feature')).height,
      tester.getSize(_cell('Notes')).height,
    );
  });

  testWidgets('wrap works inside IntrinsicWidth', (tester) async {
    await _pump(
      tester,
      intrinsicWidth: true,
      table: const TableStyle(overflow: TableOverflow.wrap),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_lastCell).right, lessThanOrEqualTo(_width));
  });

  testWidgets('wrap set on the theme applies', (tester) async {
    tester.view.physicalSize = const Size(_width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            GptMarkdownThemeData(
              brightness: Brightness.light,
              styleSheet: const GptMarkdownStyleSheet(
                table: TableStyle(overflow: TableOverflow.wrap),
              ),
            ),
          ],
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: GptMarkdown(_wide)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_horizontalScroll, findsNothing);
    expect(tester.getRect(_lastCell).right, lessThanOrEqualTo(_width));
  });
}
