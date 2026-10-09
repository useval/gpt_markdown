// ignore_for_file: deprecated_member_use_from_same_package

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `highlightBuilder` is kept for one major so 1.1.x code still compiles.
/// It is only consulted when `inlineCodeBuilder` is not given, and its result
/// is aligned on the text baseline rather than the old hardcoded
/// `PlaceholderAlignment.middle`.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    HighlightBuilder? highlightBuilder,
    InlineCodeBuilder? inlineCodeBuilder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GptMarkdown(
            'run `code` now',
            highlightBuilder: highlightBuilder,
            inlineCodeBuilder: inlineCodeBuilder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<InlineSpan> allSpans(WidgetTester tester) {
    final spans = <InlineSpan>[];
    void visit(InlineSpan span) {
      spans.add(span);
      if (span is TextSpan) {
        span.children?.forEach(visit);
      }
    }

    for (final rt in tester.widgetList<RichText>(
      find.byWidgetPredicate((w) => w is RichText),
    )) {
      visit(rt.text);
    }
    return spans;
  }

  testWidgets('still renders', (tester) async {
    await pump(
      tester,
      highlightBuilder: (context, text, style) => Text('OLD:$text'),
    );
    expect(find.text('OLD:code'), findsOneWidget);
  });

  testWidgets('is aligned on the baseline, not the line box', (tester) async {
    await pump(
      tester,
      highlightBuilder: (context, text, style) => Text('OLD:$text'),
    );
    final span = allSpans(tester).whereType<WidgetSpan>().single;
    expect(span.alignment, PlaceholderAlignment.baseline);
    expect(span.baseline, TextBaseline.alphabetic);
  });

  testWidgets('inlineCodeBuilder wins when both are given', (tester) async {
    await pump(
      tester,
      highlightBuilder: (context, text, style) => Text('OLD:$text'),
      inlineCodeBuilder: (context, code, style, codeStyle) =>
          TextSpan(text: 'NEW:$code', style: style),
    );
    expect(find.text('OLD:code'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('NEW:code'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the default chip is used when neither is given', (tester) async {
    await pump(tester);
    expect(allSpans(tester).whereType<CodeTextSpan>(), hasLength(1));
    expect(allSpans(tester).whereType<WidgetSpan>(), isEmpty);
  });
}
