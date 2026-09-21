import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'nested_text_scaling_test.dart' show glyphHeight;

void main() {
  const cases = {
    'table': (
      '| heading |\n| --- |\n| cell |\n\n> | quoted |\n> | --- |\n> | nested |',
      ['heading', 'cell', 'quoted', 'nested'],
    ),
    'radio': (
      '(x) selected\n( ) option\n\n> (x) nested',
      ['selected', 'option', 'nested'],
    ),
    'code': (
      '```dart\nfinal value = 1;\n```\n\n> ```\n> nested\n> ```',
      ['dart', 'value', 'nested'],
    ),
  };
  for (final entry in cases.entries) {
    for (final mode in ['modern', 'legacy', 'sliver', 'maxLines']) {
      for (final explicit in [false, true]) {
        testWidgets('${entry.key} scales once: $mode explicit=$explicit', (
          tester,
        ) async {
          Future<void> pump(double scale) => tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(explicit ? 1 : scale),
                ),
                child: Scaffold(
                  body:
                      mode == 'sliver'
                          ? CustomScrollView(
                            slivers: [
                              SliverGptMarkdown(
                                entry.value.$1,
                                config: GptMarkdownConfig(
                                  textScaler:
                                      explicit
                                          ? TextScaler.linear(scale)
                                          : null,
                                ),
                              ),
                            ],
                          )
                          : SingleChildScrollView(
                            child: GptMarkdown(
                              entry.value.$1,
                              incremental: mode != 'legacy',
                              maxLines: mode == 'maxLines' ? 100 : null,
                              textScaler:
                                  explicit ? TextScaler.linear(scale) : null,
                            ),
                          ),
                ),
              ),
            ),
          );
          await pump(1);
          final small = {
            for (final word in entry.value.$2) word: glyphHeight(tester, word),
          };
          await pump(2);
          for (final word in entry.value.$2) {
            expect(
              glyphHeight(tester, word) / small[word]!,
              closeTo(2, .05),
              reason: word,
            );
          }
          await pump(1);
          for (final word in entry.value.$2) {
            expect(
              glyphHeight(tester, word),
              closeTo(small[word]!, .01),
              reason: word,
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
