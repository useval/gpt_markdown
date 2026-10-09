// ignore_for_file: deprecated_member_use_from_same_package
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Issue #41: the gap between blocks was one empty line (1.15 × the font
/// size) with no way to change it. `GptMarkdownStyleSheet.blockSpacing` sets
/// it, and every rendering path has to agree on it — the incremental column,
/// the single-text document, the legacy pipeline, blocks nested in a quote,
/// and the sliver.

enum _Path { incremental, document, legacy }

Future<double> _height(
  WidgetTester tester,
  String data, {
  required _Path path,
  double? spacing,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: GptMarkdown(
                data,
                incremental: path != _Path.document,
                inlineComponents: path == _Path.legacy
                    ? MarkdownComponent.inlineComponents
                    : null,
                styleSheet: GptMarkdownStyleSheet(blockSpacing: spacing),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return tester.getSize(find.byType(GptMarkdown)).height;
}

/// The gap [path] puts between two one-line paragraphs.
Future<double> _gap(
  WidgetTester tester, {
  required _Path path,
  double? spacing,
  double textScale = 1,
  String separator = '\n\n',
}) async {
  final line = await _height(
    tester,
    'a',
    path: path,
    spacing: spacing,
    textScale: textScale,
  );
  final two = await _height(
    tester,
    'a${separator}b',
    path: path,
    spacing: spacing,
    textScale: textScale,
  );
  return two - 2 * line;
}

void main() {
  for (final path in _Path.values) {
    testWidgets('${path.name}: unset keeps the historical gap', (tester) async {
      expect(
        await _gap(tester, path: path),
        moreOrLessEquals(16.1, epsilon: 0.2),
      );
    });

    for (final spacing in [0.0, 4.0, 8.0, 30.0]) {
      testWidgets('${path.name}: blockSpacing $spacing', (tester) async {
        expect(
          await _gap(tester, path: path, spacing: spacing),
          moreOrLessEquals(spacing, epsilon: 0.2),
        );
      });
    }

    testWidgets('${path.name}: extra blank lines add nothing', (tester) async {
      expect(
        await _gap(tester, path: path, spacing: 8, separator: '\n\n\n\n\n'),
        moreOrLessEquals(8, epsilon: 0.2),
      );
    });

    testWidgets('${path.name}: the gap scales with the text', (tester) async {
      expect(
        await _gap(tester, path: path, spacing: 8, textScale: 2),
        moreOrLessEquals(16, epsilon: 0.3),
      );
    });
  }

  testWidgets('blocks nested in a quote use it too', (tester) async {
    Future<double> quoteGap(double? spacing) async {
      final one = await _height(
        tester,
        '> a',
        path: _Path.incremental,
        spacing: spacing,
      );
      final two = await _height(
        tester,
        '> a\n>\n> b',
        path: _Path.incremental,
        spacing: spacing,
      );
      return two - one;
    }

    final byDefault = await quoteGap(null);
    final tight = await quoteGap(0);
    // The second paragraph adds one line either way; only the gap differs.
    expect(byDefault - tight, moreOrLessEquals(16.1, epsilon: 0.3));
  });

  testWidgets('SliverGptMarkdown agrees with GptMarkdown', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverGptMarkdown(
                'first\n\nsecond',
                config: GptMarkdownConfig(
                  styleSheet: GptMarkdownStyleSheet(blockSpacing: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Rect rectOf(String text) => tester.getRect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == text,
      ),
    );
    expect(
      rectOf('second').top - rectOf('first').bottom,
      moreOrLessEquals(6, epsilon: 0.2),
    );
  });

  test('blockSpacing merges, copies, lerps and compares', () {
    const a = GptMarkdownStyleSheet(blockSpacing: 4);
    const b = GptMarkdownStyleSheet(blockSpacing: 12);
    expect(a.merge(b).blockSpacing, 4);
    expect(const GptMarkdownStyleSheet().merge(b).blockSpacing, 12);
    expect(a.copyWith(blockSpacing: 9).blockSpacing, 9);
    expect(GptMarkdownStyleSheet.lerp(a, b, 0.5)!.blockSpacing, 8);
    expect(a == b, isFalse);
    expect(a, const GptMarkdownStyleSheet(blockSpacing: 4));
  });
}
