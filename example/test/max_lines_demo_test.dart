import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:example/max_lines_demo.dart';

void main() {
  testWidgets('the demo reports both parsers clamping alike', (tester) async {
    await tester.pumpWidget(const MaxLinesApp());
    await tester.pumpAndSettle();

    // The default sample is the multi-block one — the case that was broken.
    expect(find.text('Multi-paragraph reply'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsNWidgets(2));

    // The verdict banner is the point of the page: it turns red and says so
    // when the two parsers disagree about the height of the same clamp.
    expect(
      find.textContaining('Both parsers clamp to the same height'),
      findsOneWidget,
      reason: 'the two parsers rendered the same clamp at different heights',
    );
  });

  testWidgets('a tighter clamp gives a shorter preview', (tester) async {
    await tester.pumpWidget(const MaxLinesApp());
    await tester.pumpAndSettle();

    double previewHeight() =>
        tester.getSize(find.byType(GptMarkdown).first).height;

    final atTwo = previewHeight();

    // The segmented button renders its labels as plain text.
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    final atFive = previewHeight();

    expect(
      atFive,
      greaterThan(atTwo),
      reason: 'raising maxLines from 2 to 5 must show more of the reply',
    );
  });
}
