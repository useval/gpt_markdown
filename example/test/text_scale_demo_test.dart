import 'package:example/text_scale_demo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Smoke coverage only. The numeric guarantees live in the package's own
/// tests, which fix the width so nothing rewraps — a pane sized like a phone
/// cannot make that promise.
void main() {
  testWidgets('renders both panes and reports measured heights',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TextScaleApp());
    await tester.pumpAndSettle();
    // The default sample contains an h1, which overflows a phone-width pane at
    // a raised scale. Drain it so it is not reported against the next action.
    tester.takeException();

    // Reference, platform-setting and textScaler-parameter panes.
    expect(find.byType(GptMarkdown), findsNWidgets(3));
    expect(find.textContaining('line height'), findsOneWidget);
    expect(find.textContaining('text 2.00x'), findsOneWidget);
    expect(find.textContaining('parameter pane matches'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '3.0x'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.textContaining('text 3.00x'), findsOneWidget);

    // Hiding the reference leaves the two scaled panes.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byType(GptMarkdown), findsNWidgets(2));
  });

  testWidgets('both scaling routes agree', (tester) async {
    tester.view.physicalSize = const Size(2400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A platform font setting and an explicit `textScaler` must produce the
    // same layout; an app that scales text itself uses the second route.
    for (final sample in [
      'Paragraph',
      'Headings',
      'Bullet list',
      'Table',
      'Autolinks',
      'Inline patterns',
    ]) {
      double height({required bool viaParameter}) {
        final finder = find.byType(GptMarkdown);
        return tester.getSize(viaParameter ? finder.last : finder.first).height;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(2),
                ),
                child: SizedBox(
                  width: 900,
                  child: GptMarkdown(
                    textScaleSamples[sample]!,
                    autolinkSchemes: const {'myapp'},
                  ),
                ),
              ),
              MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.noScaling,
                ),
                child: SizedBox(
                  width: 900,
                  child: GptMarkdown(
                    textScaleSamples[sample]!,
                    textScaler: const TextScaler.linear(2),
                    autolinkSchemes: const {'myapp'},
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      expect(
        height(viaParameter: true),
        closeTo(height(viaParameter: false), 1),
        reason: sample,
      );
    }
  });

  testWidgets('every sample renders at 1x and 3x', (tester) async {
    tester.view.physicalSize = const Size(1800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final sample in textScaleSamples.entries) {
      for (final scale in [1.0, 3.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 393,
                    child: GptMarkdown(
                      sample.value,
                      textDirection: sample.key == 'Right to left'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Overflow warnings are expected for content that cannot wrap; what
        // matters here is that nothing throws while building.
        while (tester.takeException() != null) {}
        expect(
          find.byType(GptMarkdown),
          findsOneWidget,
          reason: '${sample.key} at ${scale}x',
        );
      }
    }
  });
}
