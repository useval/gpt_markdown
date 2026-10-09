import 'package:example/inline_patterns_demo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo page renders every pattern', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const InlinePatternsApp());
    await tester.pumpAndSettle();

    // Known channel and person become chips.
    expect(find.text('design-review'), findsWidgets);
    expect(find.text('ada'), findsWidgets);
    // Emoji shortcode is replaced. It is a TextSpan inside the paragraph
    // rather than its own widget, so the finder has to look at rich text.
    expect(find.textContaining('🎉', findRichText: true), findsWidgets);
    // Unknown tokens are left as text — no chip named '2959' or 'nobody'.
    expect(find.text('2959'), findsNothing);
    expect(find.text('nobody'), findsNothing);
  });
}
