import 'package:example/math_demo.dart';
import 'package:example/streaming_reply.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math;

/// Formulas whose renderer gave up and drew the raw TeX instead.
Finder _fallbacks() =>
    find.descendant(of: find.byType(Math), matching: find.byType(Text));

void main() {
  // A showcase formula that silently falls back to raw TeX looks like a bug
  // in the package, so every one must actually render.
  for (final sample in mathSamples) {
    testWidgets('"${sample.title}" renders every formula', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: GptMarkdown(sample.markdown))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsWidgets);
      expect(_fallbacks(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the streaming reply renders every formula', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GptMarkdown(streamingReply)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsWidgets);
    expect(_fallbacks(), findsNothing);
  });

  testWidgets('the page renders and shows source', (tester) async {
    tester.view.physicalSize = const Size(1000, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MathApp());
    // The streaming card never settles, so pump a fixed time.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Streams as it arrives'), findsOneWidget);
    expect(find.text(mathSamples.last.title), findsOneWidget);
    expect(_fallbacks(), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(SelectableText), findsNWidgets(mathSamples.length));

    // Tapping a formula reports it.
    await tester.tap(find.byType(Math).last);
    await tester.pump();
    expect(find.textContaining('Tapped'), findsOneWidget);

    // Unmount so the streaming card's timer stops.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the streamed reply draws its formulas while they arrive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MathApp());
    // Step through the stream: at every point, every formula on screen is
    // drawn, and none of the TeX it is made of shows as text.
    var sawPartial = false;
    for (var step = 0; step < 40; step++) {
      await tester.pump(const Duration(milliseconds: 120));
      // The streamed derivation on screen before its last line has arrived.
      // `\frac{b}{a}x` appears in no other formula on the page.
      sawPartial |= tester.widgetList<Math>(find.byType(Math)).any(
            (m) => m.tex.contains(r'\frac{b}{a}x') && !m.tex.contains(r'\sqrt'),
          );
      expect(_fallbacks(), findsNothing, reason: 'step $step');
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        final text = rich.text.toPlainText();
        expect(text, isNot(contains(r'\frac')), reason: 'step $step');
        expect(text, isNot(contains(r'\begin')), reason: 'step $step');
      }
    }
    expect(sawPartial, isTrue, reason: 'the formula appeared only whole');
    await tester.pumpWidget(const SizedBox());
  });
}
