import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';

void main() {
  testWidgets(
    'deferred highlighting keeps code current and highlights at closure',
    (tester) async {
      Widget view(String source) => MaterialApp(
        home: GptMarkdown(
          source,
          styleSheet: const GptMarkdownStyleSheet(
            codeBlock: CodeBlockStyle(highlightWhileStreaming: false),
          ),
        ),
      );
      await tester.pumpWidget(view('```dart\nfinal n = 1;'));
      var field = tester.widget<CodeField>(find.byType(CodeField));
      expect(field.highlightCode, isFalse);
      expect(field.codes, 'final n = 1;');
      await tester.pumpWidget(view('```dart\nfinal n = 12;\n```'));
      field = tester.widget<CodeField>(find.byType(CodeField));
      expect(field.highlightCode, isTrue);
      expect(field.codes, 'final n = 12;');
    },
  );
  for (final incremental in [true, false]) {
    testWidgets('fixed table widths work on incremental=$incremental', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GptMarkdown(
            '| A | B |\n|---|---|\n| one | two |',
            incremental: incremental,
            styleSheet: const GptMarkdownStyleSheet(
              table: TableStyle(columnWidth: FixedColumnWidth(120)),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Table)).width, 240);
    });
  }
  test('performance policies survive style resolution and copying', () {
    const code = CodeBlockStyle(highlightWhileStreaming: false);
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    expect(code.resolve(scheme).highlightWhileStreaming, isFalse);
    expect(const CodeBlockStyle().merge(code), code);
    expect(code.copyWith(fontSize: 18).highlightWhileStreaming, isFalse);
    expect(code, isNot(const CodeBlockStyle(highlightWhileStreaming: true)));
    expect(
      CodeBlockStyle.lerp(
        code,
        const CodeBlockStyle(highlightWhileStreaming: true),
        0.75,
      )!.highlightWhileStreaming,
      isTrue,
    );
    const width = FixedColumnWidth(100);
    const table = TableStyle(columnWidth: width);
    expect(table.resolve(scheme).columnWidth, same(width));
    expect(const TableStyle().merge(table), table);
    expect(table.copyWith(borderWidth: 2).columnWidth, same(width));
  });
  for (final incremental in [true, false]) {
    testWidgets('table supports layout-dependent custom cells: $incremental', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GptMarkdown(
            '| A |\n|---|\n| `wide` |',
            incremental: incremental,
            inlineCodeBuilder:
                (_, _, _, _) => WidgetSpan(
                  child: LayoutBuilder(
                    builder: (_, _) => const SizedBox(width: 180, height: 20),
                  ),
                ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Table)).width,
        greaterThanOrEqualTo(180),
      );
    });
  }
}
