/// Code blocks nested in other blocks — in a list item, in a block quote, and
/// a fence inside a longer fence — render as code, whole, while they stream
/// and after.
///
/// Two bugs are pinned here:
///
/// * A fence in a list item after a blank line (`1. Run`, blank, indented
///   fence — the shape of most step-by-step answers) was cut away from its
///   item. The view splits a reply at blank lines before parsing, so the fence
///   was parsed alone: outside the list, every line keeping the item's indent.
/// * A fence inside a block quote was invisible to the `$` rewrite and to
///   inline-pattern masking until its closing line arrived, so a streaming
///   `> echo $A/$B` showed `\(A/\)B`, and a pattern inside it showed its raw
///   placeholder.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../utils/test_helpers.dart';

final _patterns = [
  InlinePattern.delimited(
    open: ':',
    knownNames: const ['wave'],
    builder: (context, match, style) => const TextSpan(text: 'EMOJI'),
  ),
];

Widget _view(
  String markdown, {
  GptMarkdownAnimation animation = GptMarkdownAnimation.none,
  bool streaming = false,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: GptMarkdown(
        markdown,
        useDollarSignsForLatex: true,
        inlinePatterns: _patterns,
        animation: animation,
        isStreaming: streaming,
      ),
    ),
  ),
);

Future<String> _render(WidgetTester tester, String markdown) async {
  await tester.pumpWidget(_view(markdown));
  await tester.pumpAndSettle();
  return getSerializedOutput(tester).replaceAll('\n', ' ');
}

void main() {
  group('a fenced block in a list item', () {
    testWidgets('stays in its item, without the item indent', (tester) async {
      final output = await _render(
        tester,
        '1. Install:\n\n   ```bash\n   npm install\n   ```\n2. Run it.',
      );
      expect(
        output,
        contains(
          'OL_ITEM(1, TEXT("Install:") CODE_BLOCK(lang="bash", "npm install"))',
        ),
      );
      expect(output, contains('OL_ITEM(2, TEXT("Run it."))'));
    });

    testWidgets('keeps a blank line inside the code', (tester) async {
      final output = await _render(
        tester,
        '- Step\n\n  ```py\n  a = 1\n\n  b = 2\n  ```',
      );
      expect(output, contains(r'CODE_BLOCK(lang="py", "a = 1\n\nb = 2")'));
    });

    testWidgets('holds a fence inside a longer fence', (tester) async {
      final output = await _render(
        tester,
        '- Show:\n\n  ````md\n  ```js\n  x\n  ```\n  ````',
      );
      expect(output, contains(r'CODE_BLOCK(lang="md", "```js\nx\n```")'));
    });

    testWidgets('a second paragraph stays in its item too', (tester) async {
      final output = await _render(tester, '1. First\n\n   More.\n2. Second');
      expect(output, contains('OL_ITEM(1, TEXT("First") TEXT("More."))'));
    });
  });

  group('a fenced block in a quote', () {
    testWidgets('renders as code', (tester) async {
      final output = await _render(tester, '> ```bash\n> echo \$A/\$B\n> ```');
      expect(
        output,
        contains(r'BLOCKQUOTE(CODE_BLOCK(lang="bash", "echo $A/$B"))'),
      );
    });

    testWidgets('closes when the quote ends', (tester) async {
      final output = await _render(
        tester,
        '> ```\n> \$a/\$b :wave:\n\nAfter \$x\$ and :wave:',
      );
      expect(output, contains(r'$a/$b :wave:'));
      expect('LATEX'.allMatches(output).length, 1);
      expect('EMOJI'.allMatches(output).length, 1);
    });
  });

  group('streaming keeps code verbatim in every frame', () {
    const replies = {
      'quote':
          'Intro.\n\n> ```bash\n> echo \$A/\$B :wave: \\(x\n'
          '> **not bold** `x\n> ```\n\nafter',
      'list item':
          'Intro.\n\n1. Run\n\n   ```bash\n   echo \$A/\$B :wave: '
          '\\(x\n   **not bold** `x\n   ```\n2. Next',
      'top level':
          'Intro.\n\n```bash\necho \$A/\$B :wave: \\(x\n'
          '**not bold** `x\n```\n\nafter',
      'long fence':
          'Intro.\n\n````md\n```js\necho \$A/\$B :wave:\n```\n'
          '````\n\nafter',
    };
    for (final animation in [
      GptMarkdownAnimation.none,
      GptMarkdownAnimation.fade,
    ]) {
      for (final reply in replies.entries) {
        testWidgets('${reply.key}, ${animation.name}', (tester) async {
          final text = reply.value;
          final broken = <String>[];
          for (var i = 1; i <= text.length; i++) {
            await tester.pumpWidget(
              _view(
                text.substring(0, i),
                animation: animation,
                streaming: i < text.length,
              ),
            );
            await tester.pump(const Duration(milliseconds: 40));
            final output = getSerializedOutput(tester);
            final code = output.indexOf('CODE_BLOCK');
            if (code == -1) {
              continue;
            }
            final block = output.substring(code);
            if (block.contains(r'\)') ||
                block.contains('EMOJI') ||
                RegExp(r'[0-9]:[A-Za-z0-9+/=]{6,}').hasMatch(block)) {
              broken.add('after $i characters: $block');
            }
          }
          await tester.pumpAndSettle();
          expect(broken, isEmpty);
          expect(getSerializedOutput(tester), isNot(contains('LATEX')));
        });
      }
    }
  });

  group('splitting at blank lines', () {
    test('keeps a list item and its code together', () {
      expect(splitStreamSegments('1. Run\n\n   ```\n   x\n   ```\n\nAfter.'), [
        '1. Run\n\n   ```\n   x\n   ```',
        'After.',
      ]);
    });

    test('still splits a paragraph from an indented line', () {
      expect(splitStreamSegments('Para.\n\n  indented'), [
        'Para.',
        '  indented',
      ]);
    });

    test('the settled split never cuts inside a list item', () {
      const source = 'Intro.\n\n1. Run\n\n   ```\n   x\n   ```\n\nTail.';
      expect(settledSplitOffset(source), 'Intro.\n\n'.length);
    });
  });
}
