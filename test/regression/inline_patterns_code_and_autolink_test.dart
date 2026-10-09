/// Three bugs found through an app that uses inline patterns with autolinks:
///
/// 1. A bare URL straight after `_` was not linked. GFM allows an autolink
///    after `_` as after `*`, `~` and `(`.
/// 2. An inline pattern inside a code span was masked like one in prose, and
///    code is never expanded back, so `` `:wave:` `` showed the reader the
///    placeholder's raw payload (`1:OndhdmU6`).
/// 3. With `autolink: false`, a pattern inside bold (`**@alice**`) stayed raw
///    text: the fallback that claims it sat behind the autolink check.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../utils/test_helpers.dart';

final _patterns = [
  InlinePattern.prefixed(
    prefix: '@',
    knownNames: const ['alice', 'bob'],
    builder: (context, match, style) => const TextSpan(text: 'MENTION'),
  ),
  InlinePattern.delimited(
    open: ':',
    knownNames: const ['wave', 'b'],
    builder: (context, match, style) => const TextSpan(text: 'EMOJI'),
  ),
];

Future<String> _render(
  WidgetTester tester,
  String markdown, {
  bool autolink = true,
  bool sliver = false,
}) async {
  final Widget body;
  if (sliver) {
    body = CustomScrollView(
      slivers: [
        SliverGptMarkdown(
          markdown,
          config: GptMarkdownConfig(
            autolink: autolink,
            inlinePatterns: _patterns,
          ),
        ),
      ],
    );
  } else {
    body = SingleChildScrollView(
      child: GptMarkdown(
        markdown,
        autolink: autolink,
        inlinePatterns: _patterns,
      ),
    );
  }
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pumpAndSettle();
  return getSerializedOutput(tester);
}

void main() {
  group('inline patterns never reach into code', () {
    testWidgets('a single-backtick code span keeps its text', (tester) async {
      final output = await _render(tester, '`:wave:` and :wave:');
      expect(output, contains('TEXT(":wave:")[highlight]'));
      expect('EMOJI'.allMatches(output).length, 1);
      expect(output, isNot(contains('OndhdmU6')));
    });

    testWidgets('a double-backtick code span keeps its text', (tester) async {
      final output = await _render(tester, '`` @alice :wave: `` @bob');
      expect(output, contains('TEXT("@alice :wave:")[highlight]'));
      expect('MENTION'.allMatches(output).length, 1);
      expect(output, isNot(contains('EMOJI')));
    });

    testWidgets('a code span across lines of one paragraph', (tester) async {
      final output = await _render(tester, 'run `a\n:wave:` now');
      expect(output, isNot(contains('EMOJI')));
    });

    testWidgets('a backtick does not pair across a blank line', (tester) async {
      final output = await _render(tester, 'a ` b\n\n:wave: and ` c');
      expect(output, contains('EMOJI'));
    });

    testWidgets('an escaped backtick opens no code span', (tester) async {
      final output = await _render(tester, r'\`:wave:\`');
      expect(output, contains('EMOJI'));
    });

    testWidgets('a long fence holding a short one is code throughout', (
      tester,
    ) async {
      final output = await _render(
        tester,
        '````md\n```\n:wave:\n```\n:wave: @alice\n````\n\nafter :wave:',
      );
      expect('EMOJI'.allMatches(output).length, 1);
      expect(output, isNot(contains('MENTION')));
    });

    testWidgets('a tilde fence is code', (tester) async {
      final output = await _render(tester, '~~~\n:wave:\n~~~\n\n:wave:');
      expect('EMOJI'.allMatches(output).length, 1);
    });

    testWidgets('an inline formula is left alone', (tester) async {
      final output = await _render(tester, r'\(a:b:c\) and :b:');
      expect('EMOJI'.allMatches(output).length, 1);
    });

    testWidgets(r'a $…$ formula is left alone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GptMarkdown(
                r'$a:b:c$ and :b:',
                useDollarSignsForLatex: true,
                inlinePatterns: _patterns,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final output = getSerializedOutput(tester);
      expect('EMOJI'.allMatches(output).length, 1);
      expect('LATEX'.allMatches(output).length, 1);
    });

    testWidgets('a one-line block formula is left alone', (tester) async {
      final output = await _render(tester, '\\[ a:b:c \\]\n\n:b:');
      expect('EMOJI'.allMatches(output).length, 1);
      expect('LATEX'.allMatches(output).length, 1);
    });

    testWidgets('the sliver view skips code spans too', (tester) async {
      final output = await _render(tester, '`:wave:` and :wave:', sliver: true);
      expect('EMOJI'.allMatches(output).length, 1);
      expect(output, isNot(contains('OndhdmU6')));
    });
  });

  group('patterns apply with autolink off', () {
    testWidgets('inside bold', (tester) async {
      final output = await _render(tester, '**@alice** @bob', autolink: false);
      expect('MENTION'.allMatches(output).length, 2);
      expect(output, isNot(contains('@alice')));
    });

    testWidgets('and still link nothing', (tester) async {
      final output = await _render(
        tester,
        '**@alice** https://x.dev',
        autolink: false,
      );
      expect(output, contains('MENTION'));
      expect(output, isNot(contains('LINK')));
    });
  });

  group('autolinks after an underscore', () {
    testWidgets('an unclosed _ before a URL', (tester) async {
      await pumpMarkdown(tester, 'see _https://x.dev');
      expect(
        getSerializedOutput(tester),
        contains('LINK("https://x.dev", url="https://x.dev")'),
      );
    });

    testWidgets('an underscore inside a word before a URL', (tester) async {
      await pumpMarkdown(tester, 'foo_https://x.dev');
      expect(getSerializedOutput(tester), contains('url="https://x.dev"'));
    });

    testWidgets('a URL in underscore emphasis', (tester) async {
      await pumpMarkdown(tester, '_https://x.dev_');
      expect(getSerializedOutput(tester), contains('url="https://x.dev"'));
    });

    testWidgets('an email with an underscore links whole', (tester) async {
      await pumpMarkdown(tester, 'mail user_name@example.com');
      expect(
        getSerializedOutput(tester),
        contains('url="mailto:user_name@example.com"'),
      );
    });

    testWidgets('plain identifiers stay text', (tester) async {
      await pumpMarkdown(tester, 'snake_case_name');
      expect(getSerializedOutput(tester), isNot(contains('LINK')));
    });
  });
}
