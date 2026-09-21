/// Comparable on both sides of the rendering refactor: uses only APIs that
/// predate it. Debug host timings are diagnostic, not device frame budgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('nested quote span construction', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    var calls = 0;
    final config = GptMarkdownConfig(
      inlineCodeBuilder: (_, code, style, _) {
        calls++;
        return TextSpan(text: code, style: style);
      },
    );
    final source = '${'> ' * 10}`one`';
    for (var i = 0; i < 5; i++) {
      PlusparseRenderer.render(context, source, config);
    }
    calls = 0;
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      PlusparseRenderer.render(context, source, config);
    }
    watch.stop();
    debugPrint(
      'ARCH quote_depth_10_us=${watch.elapsedMicroseconds / 20} '
      'inline_builds_per_render=${calls / 20}',
    );
  });

  testWidgets('reveal backlog without new source', (tester) async {
    var calls = 0;
    InlineSpan code(
      BuildContext context,
      String source,
      TextStyle style,
      InlineCodeStyle codeStyle,
    ) {
      calls++;
      return TextSpan(text: source, style: style);
    }

    Widget view(String source) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(
            source,
            animation: GptMarkdownAnimation.fade,
            isStreaming: true,
            charactersPerSecond: 20,
            inlineCodeBuilder: code,
          ),
        ),
      ),
    );
    await tester.pumpWidget(view('start'));
    final backlog = List.generate(
      40,
      (i) => 'Paragraph $i `code$i` **bold** and *italic*.',
    ).join('\n\n');
    await tester.pumpWidget(view('start\n\n${'slow words ' * 40}\n\n$backlog'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    calls = 0;
    final watch = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    watch.stop();
    debugPrint(
      'ARCH backlog_tick_us=${watch.elapsedMicroseconds / 40} '
      'inline_builds_during_40_ticks=$calls',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
