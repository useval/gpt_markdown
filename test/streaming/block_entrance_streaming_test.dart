/// A block entrance has to animate the block a reader will actually see.
///
/// The entrance plays once, when a block first appears. Shown as soon as it
/// could be, a table appeared as its header alone and a fence as an empty box
/// — the entrance animated those, and every row and line after arrived with
/// no animation at all, so the effect was barely visible.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(String text) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 600,
      child: GptMarkdown(
        text,
        animation: GptMarkdownAnimation.fade,
        blockAnimation: GptMarkdownBlockAnimation.fadeIn,
        blockAnimationDuration: const Duration(milliseconds: 600),
        charactersPerSecond: 600,
      ),
    ),
  ),
);

String _visible(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join(' ');

Future<void> _stream(WidgetTester tester, String source, int step) async {
  for (var n = step; n < source.length + step; n += step) {
    await tester.pumpWidget(
      _app(source.substring(0, n.clamp(0, source.length))),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  testWidgets('a table enters with all its rows', (tester) async {
    const source =
        'Results:\n\n| Model | Score |\n|---|---|\n| Small | 71.2 |\n'
        '| Large | 84.9 |\n\nDone.';
    await tester.pumpWidget(_app(''));
    String? atEntrance;
    for (var n = 3; n <= source.length; n += 3) {
      await tester.pumpWidget(_app(source.substring(0, n)));
      await tester.pump(const Duration(milliseconds: 30));
      if (atEntrance == null &&
          find.byType(GptMarkdownBlockEntrance).evaluate().isNotEmpty) {
        atEntrance = _visible(tester);
      }
    }
    expect(atEntrance, isNotNull);
    expect(atEntrance, contains('Large'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a fence label never shows half its language', (tester) async {
    const source = 'Example:\n\n```dart\nvar x = 1;\n```';
    await tester.pumpWidget(_app(''));
    for (var n = 1; n <= source.length; n++) {
      await tester.pumpWidget(_app(source.substring(0, n)));
      await tester.pump(const Duration(milliseconds: 30));
      final text = _visible(tester);
      for (final partial in ['Code ', ' d ', ' da ', ' dar ']) {
        expect(
          ' $text '.contains(partial) && !text.contains('dart'),
          isFalse,
          reason: 'at "${source.substring(0, n)}"',
        );
      }
    }
    expect(_visible(tester), contains('dart'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a closing fence never flashes as a stray backtick', (
    tester,
  ) async {
    const source = '```dart\nvar x = 1;\n```';
    await tester.pumpWidget(_app(''));
    await _stream(tester, source, 1);
    // While the closer arrives, `var x = 1;` is never followed by a backtick.
    await tester.pumpWidget(_app('```dart\nvar x = 1;\n`'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(_visible(tester), isNot(contains('`')));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a block that keeps growing eases to its new height', (
    tester,
  ) async {
    await tester.pumpWidget(_app(''));
    await _stream(tester, '```dart\nline one\n', 4);
    await tester.pump(const Duration(seconds: 1));
    final before = tester.getSize(find.byType(GptMarkdown)).height;
    await tester.pumpWidget(_app('```dart\nline one\nline two\n'));
    await tester.pump(const Duration(milliseconds: 16));
    final during = tester.getSize(find.byType(GptMarkdown)).height;
    await tester.pump(const Duration(milliseconds: 400));
    final after = tester.getSize(find.byType(GptMarkdown)).height;
    expect(after, greaterThan(before));
    // Part-way there one frame after the line landed — not a step.
    expect(during, greaterThan(before));
    expect(during, lessThan(after));
    await tester.pump(const Duration(seconds: 2));
  });

  group('the table hold', () {
    Widget plain(String text, {GptMarkdownBlockAnimation? block}) =>
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: GptMarkdown(
                text,
                animation: GptMarkdownAnimation.fade,
                blockAnimation: block ?? GptMarkdownBlockAnimation.fadeIn,
                charactersPerSecond: 600,
              ),
            ),
          ),
        );
    // Ends in a newline: a row still arriving is held by its own, older
    // rule (a table row is atomic), which is not what these tests check.
    const table = '| A | B |\n|---|---|\n| 1 | 2 |\n';

    testWidgets('releases a table the stream stops growing', (tester) async {
      await tester.pumpWidget(plain(''));
      await tester.pumpWidget(plain(table));
      await tester.pump(const Duration(milliseconds: 100));
      // Held whole: not even the header shows while rows may still come.
      expect(_visible(tester), isNot(contains('A')));
      // The host never says the stream ended: the quiet timer lets it go.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 800));
      expect(_visible(tester), contains('A'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows a table at once when text follows it', (tester) async {
      await tester.pumpWidget(plain(''));
      await tester.pumpWidget(plain('${table}After it.'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_visible(tester), contains('2'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('does not hold without a block animation', (tester) async {
      await tester.pumpWidget(plain('', block: GptMarkdownBlockAnimation.none));
      await tester.pumpWidget(
        plain(table, block: GptMarkdownBlockAnimation.none),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // Streams as before: the header is on screen at once.
      expect(_visible(tester), contains('A'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('leaves a quoted table alone', (tester) async {
      await tester.pumpWidget(plain(''));
      await tester.pumpWidget(plain('> | A | B |\n> |---|---|\n> | 1 | 2 |'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_visible(tester), contains('2'));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
