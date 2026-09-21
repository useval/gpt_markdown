import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'nested_text_scaling_test.dart' show glyphHeight;

void main() {
  for (final maxLines in [null, 100]) {
    testWidgets('custom blocks inherit scaling once, maxLines=$maxLines', (
      tester,
    ) async {
      final components = [
        MarkdownBlockComponent(
          syntax: const FencedBlockSyntax(type: 'note', opening: ':::note'),
          builder:
              (context, node, config) => Text(node.body, style: config.style),
        ),
      ];
      Future<void> pump(double scale) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GptMarkdown(
                ':::note\nstandalone\n:::\n\n> :::note\n> nested\n> :::',
                blockComponents: components,
                maxLines: maxLines,
                textScaler: TextScaler.linear(scale),
              ),
            ),
          ),
        ),
      );
      await pump(1);
      final standalone = glyphHeight(tester, 'standalone');
      final nested = glyphHeight(tester, 'nested');
      await pump(2);
      expect(glyphHeight(tester, 'standalone') / standalone, closeTo(2, .05));
      expect(glyphHeight(tester, 'nested') / nested, closeTo(2, .05));
      expect(tester.takeException(), isNull);
    });
  }
}
