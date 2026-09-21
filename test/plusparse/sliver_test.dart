import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets(
    'long documents build only viewport segments and scroll correctly',
    (tester) async {
      final built = <String>{};
      final controller = ScrollController();
      final source = List.generate(200, (i) => '`block$i`').join('\n\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: CustomScrollView(
                controller: controller,
                // Retain compatibility with the package's minimum Flutter SDK.
                // ignore: deprecated_member_use
                cacheExtent: 0,
                slivers: [
                  SliverGptMarkdown(
                    source,
                    config: GptMarkdownConfig(
                      inlineCodeBuilder: (_, code, style, _) {
                        built.add(code);
                        return TextSpan(text: code, style: style);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(built.length, lessThan(40));
      expect(built, contains('block0'));
      expect(built, isNot(contains('block199')));
      await tester.scrollUntilVisible(
        find.text('block199'),
        500,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      expect(built, contains('block199'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('legacy sliver preserves a single document', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverGptMarkdown(
              'one\n\ntwo',
              config: GptMarkdownConfig(components: []),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(MdWidget), findsOneWidget);
  });
  testWidgets('legacy slivers preserve inline pattern source matching', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverGptMarkdown(
              '@person',
              config: GptMarkdownConfig(
                components: MarkdownComponent.globalComponents,
                inlinePatterns: [
                  InlinePattern(
                    pattern: RegExp(r'@person'),
                    builder:
                        (_, _, _) => const TextSpan(text: 'matched mention'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('matched mention'), findsOneWidget);
  });
}
