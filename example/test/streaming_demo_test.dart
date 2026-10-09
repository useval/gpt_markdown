import 'package:example/streaming_demo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('streams the reply and settles', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const StreamingApp());
    await tester.pumpAndSettle();

    // Nothing delivered until it is started.
    expect(find.textContaining('delivered 0 of'), findsOneWidget);

    await tester.tap(find.text('Stream'));
    await tester.pump();
    expect(find.textContaining('streaming'), findsOneWidget);

    // Let the simulated model run to the end: it emits 120 characters a
    // second by default.
    await tester.pump(
      Duration(seconds: (streamingReply.length / 120).ceil() + 2),
    );
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
    expect(find.textContaining('idle'), findsOneWidget);

    // Every block entrance renders without throwing too. The second chip row
    // is the block axis, so its options are found from the end.
    for (final option in GptMarkdownBlockAnimation.values) {
      await tester.tap(find.widgetWithText(ChoiceChip, option.name).last);
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(find.byType(GptMarkdown), findsOneWidget, reason: option.name);
    }

    // Every animation option renders without throwing.
    //
    // `.first` because the toolbar carries two chip rows — characters and
    // blocks — and both name an option `none`.
    for (final option in GptMarkdownAnimation.values) {
      await tester.tap(find.widgetWithText(ChoiceChip, option.name).first);
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      expect(find.byType(GptMarkdown), findsOneWidget, reason: option.name);
    }
  });

  testWidgets('show all skips to the finished reply', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const StreamingApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    expect(
      find.textContaining('delivered ${streamingReply.length} of'),
      findsOneWidget,
    );
  });
}
