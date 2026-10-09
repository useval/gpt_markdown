import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `MarkdownComponent.generate` picks the handler for a match by re-testing an
/// anchored copy of each component's pattern. Anchoring as `^$pattern$` binds
/// `^` to the first alternative and `$` to the last, so a component whose
/// pattern has a top-level `|` used to claim matches it does not cover — and,
/// being earlier in the list, could steal them from the component that does.

/// A component with a top-level alternation, like `AutolinkMd` and `HrLine`.
class _AltMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'@@[a-z]+|[a-z]+@@');

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return TextSpan(text: 'ALT($text)', style: config.style);
  }
}

String plainText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    buffer.write(rt.text.toPlainText(includePlaceholders: false));
  }
  return buffer.toString();
}

Future<void> pump(WidgetTester tester, String markdown) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GptMarkdown(
          markdown,
          inlineComponents: [_AltMd(), ...MarkdownComponent.inlineComponents],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a component only claims matches its whole pattern covers', (
    tester,
  ) async {
    await pump(tester, 'x @@abc y');
    expect(plainText(tester), contains('ALT(@@abc)'));
  });

  testWidgets('the second alternative is anchored too', (tester) async {
    await pump(tester, 'x abc@@ y');
    expect(plainText(tester), contains('ALT(abc@@)'));
  });

  testWidgets('it does not claim a longer match from another component', (
    tester,
  ) async {
    // `**@@abc**` belongs to BoldMd. The alternation component matches inside
    // it, and used to win the dispatch because `^@@[a-z]+|[a-z]+@@$` matched
    // via its unanchored middle.
    await pump(tester, '**@@abc**');
    final text = plainText(tester);
    expect(text, contains('ALT(@@abc)'));
    expect(text, isNot(contains('*')));
  });
}
