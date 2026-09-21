import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

class CountingSyntax extends MarkdownBlockSyntax {
  int calls = 0;
  @override
  String get type => 'warning';
  @override
  String get prefix => ':::warning';
  @override
  MarkdownBlockMatch? parse(List<String> lines, int startLine) {
    calls++;
    return const FencedBlockSyntax(
      type: 'warning',
      opening: ':::warning',
    ).parse(lines, startLine);
  }
}

class InvalidSyntax extends CountingSyntax {
  @override
  MarkdownBlockMatch? parse(List<String> lines, int startLine) =>
      MarkdownBlockMatch(
        node: const MdCustomBlock(type: 'warning', body: ''),
        endLine: startLine,
      );
}

void main() {
  const syntax = FencedBlockSyntax(type: 'warning', opening: ':::warning');
  final registry = MarkdownBlockRegistry([syntax]);
  test('custom blocks preserve blank lines and incomplete bodies', () {
    for (final closed in [false, true]) {
      final doc = Plusparse.parse(
        ':::warning\nfirst\n\nsecond${closed ? '\n:::' : ''}',
        blockRegistry: registry,
      );
      final node = doc.children.single as MdCustomBlock;
      expect(node.body, 'first\n\nsecond');
      expect(node.closed, closed);
      expect(
        splitStreamSegments(
          ':::warning\nfirst\n\nsecond${closed ? '\n:::' : ''}',
          blockRegistry: registry,
        ),
        hasLength(1),
      );
    }
  });
  test('custom blocks interrupt prose and work inside quotes', () {
    final doc = Plusparse.parse(
      'before\n:::warning\nbody\n:::\nafter',
      blockRegistry: registry,
    );
    expect(doc.children.map((n) => n.runtimeType), [
      MdParagraph,
      MdCustomBlock,
      MdParagraph,
    ]);
    final quote =
        Plusparse.parse(
              '> :::warning\n> body\n> :::',
              blockRegistry: registry,
            ).children.single
            as MdBlockQuote;
    expect(quote.children.single, isA<MdCustomBlock>());
  });
  test('code fences are opaque and unknown prefixes remain prose', () {
    final counting = CountingSyntax();
    final reg = MarkdownBlockRegistry([counting]);
    final doc = Plusparse.parse(
      '```\n:::warning\n```\n\nplain text',
      blockRegistry: reg,
    );
    expect(doc.children.first, isA<MdCodeBlock>());
    expect(counting.calls, 0);
    expect(
      Plusparse.parse(':::unknown', blockRegistry: reg).children.single,
      isA<MdParagraph>(),
    );
  });
  test('invalid progress and duplicate registrations fail clearly', () {
    expect(
      () => Plusparse.parse(
        ':::warning',
        blockRegistry: MarkdownBlockRegistry([InvalidSyntax()]),
      ),
      throwsStateError,
    );
    expect(() => MarkdownBlockRegistry([syntax, syntax]), throwsArgumentError);
  });
  testWidgets(
    'custom blocks use modern rendering and reuse AST on theme change',
    (tester) async {
      final counting = CountingSyntax();
      var builds = 0;
      final components = [
        MarkdownBlockComponent(
          syntax: counting,
          builder: (context, node, config) {
            builds++;
            return Text(
              'warning: ${node.body}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            );
          },
        ),
      ];
      Widget view(Brightness brightness) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: GptMarkdown(':::warning\nbody\n:::', blockComponents: components),
      );
      await tester.pumpWidget(view(Brightness.light));
      expect(find.text('warning: body'), findsOneWidget);
      expect(find.byType(MdWidget), findsNothing);
      final parsed = counting.calls;
      await tester.pumpWidget(view(Brightness.dark));
      await tester.pumpAndSettle();
      expect(counting.calls, parsed, reason: 'theme changes must not reparse');
      expect(builds, greaterThan(1));
    },
  );
  testWidgets('legacy components retain precedence over block extensions', (
    tester,
  ) async {
    final counting = CountingSyntax();
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdown(
          ':::warning\nbody\n:::',
          components: const [],
          blockComponents: [
            MarkdownBlockComponent(
              syntax: counting,
              builder: (_, _, _) => const Text('custom renderer'),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(MdWidget), findsOneWidget);
    expect(find.text('custom renderer'), findsNothing);
    expect(counting.calls, 0);
  });
  testWidgets('component replacement invalidates parsed payloads', (
    tester,
  ) async {
    Widget view(String label) => MaterialApp(
      home: GptMarkdown(
        ':::warning\nbody\n:::',
        blockComponents: [
          MarkdownBlockComponent(
            syntax: syntax,
            builder: (_, node, _) => Text('$label ${node.body}'),
          ),
        ],
      ),
    );
    await tester.pumpWidget(view('old'));
    await tester.pumpWidget(view('new'));
    expect(find.text('new body'), findsOneWidget);
    expect(find.text('old body'), findsNothing);
  });
  for (final quoted in [false, true]) {
    testWidgets('opaque custom bodies preserve inline syntax: quoted=$quoted', (
      tester,
    ) async {
      String? body;
      const raw = r'@person {{payload}} **bold** $x$';
      final block = ':::warning\n$raw\n:::';
      final source =
          quoted
              ? block.split('\n').map((line) => '> $line').join('\n')
              : block;
      await tester.pumpWidget(
        MaterialApp(
          home: GptMarkdown(
            source,
            useDollarSignsForLatex: true,
            blockComponents: [
              MarkdownBlockComponent(
                syntax: syntax,
                builder: (_, node, _) {
                  body = node.body;
                  return Text(node.body);
                },
              ),
            ],
            inlinePatterns: [
              InlinePattern(
                pattern: RegExp('@person'),
                builder: (_, _, _) => const TextSpan(text: 'mention'),
              ),
            ],
            inlineDirectives: [
              InlineDirective(
                open: '{{',
                close: '}}',
                builder: (_, _, _) => const TextSpan(text: 'directive'),
              ),
            ],
          ),
        ),
      );
      expect(body, raw);
      expect(find.text(raw), findsOneWidget);
    });
  }
}
