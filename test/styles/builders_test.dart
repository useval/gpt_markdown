import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';
import 'package:gpt_markdown/custom_widgets/custom_rb_cb.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Every component takes a builder for structure, and each one receives the
/// resolved style so a builder never has to guess a default.
Future<void> pump(WidgetTester tester, String markdown, Widget widget) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('headingBuilder replaces the heading', (tester) async {
    int? seenLevel;
    HeadingStyle? seenStyle;
    await pump(
      tester,
      '# Title',
      GptMarkdown(
        '# Title',
        styleSheet: const GptMarkdownStyleSheet(
          heading: HeadingStyle(dividerThickness: 4),
        ),
        headingBuilder: (context, level, content, style) {
          seenLevel = level;
          seenStyle = style;
          return Row(
            children: [
              const Text('H!'),
              Flexible(child: content),
            ],
          );
        },
      ),
    );

    expect(find.text('H!'), findsOneWidget);
    expect(seenLevel, 1);
    expect(seenStyle?.dividerThickness, 4);
    // The builder owns the whole heading, rule included.
    expect(find.byType(CustomDivider), findsNothing);
  });

  testWidgets('headingBuilder reports the level', (tester) async {
    final levels = <int>[];
    await pump(
      tester,
      '',
      GptMarkdown(
        '# One\n\n### Three\n\n###### Six',
        headingBuilder: (context, level, content, style) {
          levels.add(level);
          return content;
        },
      ),
    );
    expect(levels, [1, 3, 6]);
  });

  testWidgets('checkboxBuilder replaces the row', (tester) async {
    bool? seenChecked;
    CheckboxStyle? seenStyle;
    await pump(
      tester,
      '',
      GptMarkdown(
        '- [x] done',
        styleSheet: const GptMarkdownStyleSheet(
          checkbox: CheckboxStyle(size: 32),
        ),
        checkboxBuilder: (context, checked, content, style) {
          seenChecked = checked;
          seenStyle = style;
          return Row(
            children: [
              const Text('CB'),
              Flexible(child: content),
            ],
          );
        },
      ),
    );

    expect(find.text('CB'), findsOneWidget);
    expect(seenChecked, isTrue);
    expect(seenStyle?.size, 32);
    expect(find.byType(CustomCb), findsNothing);
  });

  testWidgets('radioOptionBuilder replaces the row', (tester) async {
    bool? seenSelected;
    await pump(
      tester,
      '',
      GptMarkdown(
        '(x) chosen',
        radioOptionBuilder: (context, selected, content, style) {
          seenSelected = selected;
          return Row(
            children: [
              const Text('RB'),
              Flexible(child: content),
            ],
          );
        },
      ),
    );

    expect(find.text('RB'), findsOneWidget);
    expect(seenSelected, isTrue);
    expect(find.byType(CustomRb), findsNothing);
  });

  testWidgets('hrBuilder replaces the rule', (tester) async {
    HrStyle? seenStyle;
    await pump(
      tester,
      '',
      GptMarkdown(
        'above\n\n---\n\nbelow',
        styleSheet: const GptMarkdownStyleSheet(hr: HrStyle(thickness: 6)),
        hrBuilder: (context, style) {
          seenStyle = style;
          return const Text('RULE');
        },
      ),
    );

    expect(find.text('RULE'), findsOneWidget);
    expect(seenStyle?.thickness, 6);
    expect(find.byType(CustomDivider), findsNothing);
  });

  testWidgets('blockQuoteBuilder replaces the quote', (tester) async {
    await pump(
      tester,
      '',
      GptMarkdown(
        '> quoted',
        blockQuoteBuilder: (context, content, style) => Row(
          children: [
            const Text('BQ'),
            Flexible(child: content),
          ],
        ),
      ),
    );

    expect(find.text('BQ'), findsOneWidget);
    expect(find.byType(BlockQuoteWidget), findsNothing);
  });

  testWidgets('without a builder the defaults are used', (tester) async {
    await pump(
      tester,
      '',
      const GptMarkdown('# Title\n\n- [x] done\n\n---\n\n> quoted'),
    );

    expect(find.byType(CustomCb), findsOneWidget);
    expect(find.byType(BlockQuoteWidget), findsOneWidget);
    // One for the rule, one under the h1.
    expect(find.byType(CustomDivider), findsNWidgets(2));
  });
}
