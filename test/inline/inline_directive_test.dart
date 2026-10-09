/// Host-defined inline regions the parser must not look inside.
///
/// The point of a directive, as against an [InlinePattern], is that its payload
/// is not Markdown and must arrive at the host verbatim. These tests are mostly
/// payloads chosen to be hostile: every one of them is something the Markdown
/// parser would otherwise consume.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Private Use Area delimiters, the shape a server substitutes on the way out
/// so a model never types them by accident.
const _open = '\u{E200}widget\u{E202}';
const _close = '\u{E201}';

/// Renders [source] and returns the payload the builder received, or null when
/// it was never called.
Future<String?> _payloadFrom(
  WidgetTester tester,
  String source, {
  required bool incremental,
}) async {
  String? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GptMarkdown(
          source,
          incremental: incremental,
          inlineDirectives: [
            InlineDirective(
              open: _open,
              close: _close,
              builder: (context, payload, style) {
                captured = payload;
                return const WidgetSpan(child: SizedBox(width: 24, height: 12));
              },
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
  return captured;
}

void main() {
  group('InlineDirective', () {
    // Every payload here contains something the Markdown parser would claim.
    // `InlinePattern` cannot carry these: it matches over the text runs a parse
    // produced, by which point the parse has already eaten them.
    const payloads = <String, String>{
      'plain json': '{"bar_chart":{"values":[1,2,3]}}',
      'bold markers': '{"label":"**bold**"}',
      'underscores': '{"label":"a_b_c"}',
      'backticks': '{"label":"`code`"}',
      'link syntax': '{"label":"[link](https://x.com)"}',
      'strikethrough': '{"label":"~~struck~~"}',
      'table pipes': '{"label":"a|b|c"}',
      'a newline': '{"a":1,\n"b":2}',
      'nested braces': '{"outer":{"inner":{"deep":1}}}',
      'braces in a string': '{"id":"a}b","frame":"wide{x}"}',
      'unicode and emoji': '{"label":"héllo 🎉 ünïcode"}',
      'html-ish': '{"label":"<u>under</u>"}',
      'a heading marker': '{"label":"# not a heading"}',
      'empty': '',
    };

    for (final incremental in [true, false]) {
      final pipeline = incremental ? 'plusparse' : 'regex pipeline';
      for (final entry in payloads.entries) {
        testWidgets('$pipeline delivers ${entry.key} verbatim', (tester) async {
          expect(
            await _payloadFrom(
              tester,
              'before $_open${entry.value}$_close after **bold** here',
              incremental: incremental,
            ),
            entry.value,
          );
        });
      }
    }

    testWidgets('an unterminated directive stays literal', (tester) async {
      // Half a payload during streaming must not render as a half-built
      // widget; it is text until its closer arrives.
      expect(
        await _payloadFrom(tester, 'before $_open{"a":1', incremental: true),
        isNull,
      );
    });

    testWidgets('the closer arriving completes it', (tester) async {
      expect(
        await _payloadFrom(
          tester,
          'before $_open{"a":1}$_close',
          incremental: true,
        ),
        '{"a":1}',
      );
    });

    testWidgets('several in one document each get their own payload', (
      tester,
    ) async {
      final seen = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'one $_open{"n":1}$_close two $_open{"n":2}$_close three',
              incremental: true,
              inlineDirectives: [
                InlineDirective(
                  open: _open,
                  close: _close,
                  builder: (context, payload, style) {
                    seen.add(payload);
                    return const WidgetSpan(child: SizedBox());
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(seen, ['{"n":1}', '{"n":2}']);
    });

    testWidgets('two directive kinds coexist', (tester) async {
      final seen = <String>[];
      InlineDirective kind(String name) => InlineDirective(
        open: '\u{E200}$name\u{E202}',
        close: _close,
        builder: (context, payload, style) {
          seen.add('$name:$payload');
          return const WidgetSpan(child: SizedBox());
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'a \u{E200}chart\u{E202}{"c":1}$_close b '
              '\u{E200}card\u{E202}{"d":2}$_close',
              incremental: true,
              inlineDirectives: [kind('chart'), kind('card')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(seen, ['chart:{"c":1}', 'card:{"d":2}']);
    });

    testWidgets('surrounding Markdown still renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '# Heading\n\nbefore $_open{"a":1}$_close after **bold**',
              incremental: true,
              inlineDirectives: [
                InlineDirective(
                  open: _open,
                  close: _close,
                  builder: (context, payload, style) =>
                      const WidgetSpan(child: SizedBox()),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(find.textContaining('Heading', findRichText: true), findsWidgets);
      expect(find.textContaining('bold', findRichText: true), findsWidgets);
    });

    testWidgets('no directives configured leaves the text alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown('before $_open{"a":1}$_close after'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      // Nothing claimed it, so the delimiters are just characters.
      expect(find.textContaining('before', findRichText: true), findsWidgets);
    });
  });
}
