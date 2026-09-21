import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A component in the shape apps actually write: an app-specific token that
/// renders as a chip. Registered ahead of the defaults, as the docs suggest.
class _ChipMd extends InlineMd {
  _ChipMd({this.scopeOverride});

  final Set<MarkdownScope>? scopeOverride;

  @override
  RegExp get exp => RegExp(r'#[0-9a-zA-Z_-]+');

  @override
  Set<MarkdownScope> get scopes => scopeOverride ?? super.scopes;

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Text('CHIP:$text'),
    );
  }
}

Future<void> pump(
  WidgetTester tester,
  String markdown, {
  List<MarkdownComponent>? inlineComponents,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(markdown, inlineComponents: inlineComponents),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// True when any [RichText] on screen contains a [WidgetSpan] whose own
/// subtree contains another [RichText] with a [WidgetSpan] in it — the nested
/// placeholder that fails to paint on iOS.
bool hasNestedPlaceholder(WidgetTester tester) {
  var placeholderCarrying = 0;
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    if (_containsWidgetSpan(rt.text)) {
      placeholderCarrying++;
    }
  }
  return placeholderCarrying > 1;
}

bool _containsWidgetSpan(InlineSpan span) {
  var found = false;
  span.visitChildren((child) {
    if (child is WidgetSpan) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

String allRichText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    buffer.write(rt.text.toPlainText(includePlaceholders: false));
  }
  return buffer.toString();
}

void main() {
  group('components nested inside a link label', () {
    testWidgets('an image is not rendered as a link label', (tester) async {
      await pump(tester, 'See [![alt](https://x.com/i.png)](https://x.com).');
      expect(find.byType(Image), findsNothing);
      expect(allRichText(tester), contains('See'));
    });

    testWidgets('a table is not rendered as a link label', (tester) async {
      await pump(tester, 'See [| a | b |](https://x.com) here.');
      expect(find.byType(Table), findsNothing);
    });

    testWidgets('a link is not rendered inside a link label', (tester) async {
      await pump(tester, 'See [[inner](https://a.com)](https://b.com) here.');
      expect(hasNestedPlaceholder(tester), isFalse);
    });

    testWidgets('a custom component keeps rendering by default', (
      tester,
    ) async {
      // Back-compatible: components that do not declare `scopes` behave
      // exactly as they did before scoping existed.
      await pump(
        tester,
        'See [#2959](https://x.com/i/2959).',
        inlineComponents: [_ChipMd(), ...MarkdownComponent.inlineComponents],
      );
      expect(find.text('CHIP:#2959'), findsOneWidget);
    });

    testWidgets('a custom component can opt out of link labels', (
      tester,
    ) async {
      await pump(
        tester,
        'See [#2959](https://x.com/i/2959).',
        inlineComponents: [
          _ChipMd(scopeOverride: MarkdownComponent.allScopesExceptLinkLabel),
          ...MarkdownComponent.inlineComponents,
        ],
      );
      expect(find.text('CHIP:#2959'), findsNothing);
      expect(allRichText(tester), contains('#2959'));
      expect(hasNestedPlaceholder(tester), isFalse);
    });

    testWidgets('an opted-out component still renders outside link labels', (
      tester,
    ) async {
      await pump(
        tester,
        'See #2959 and [docs](https://x.com).',
        inlineComponents: [
          _ChipMd(scopeOverride: MarkdownComponent.allScopesExceptLinkLabel),
          ...MarkdownComponent.inlineComponents,
        ],
      );
      expect(find.text('CHIP:#2959'), findsOneWidget);
    });
  });

  group('malformed links keep their text', () {
    testWidgets('unbalanced opening bracket', (tester) async {
      await pump(tester, 'a [[b](http://x) c');
      expect(allRichText(tester), contains('b'));
    });

    testWidgets('missing closing parenthesis', (tester) async {
      await pump(tester, 'a [label](http://x c');
      expect(allRichText(tester), contains('label'));
    });

    testWidgets('bracket at end of input', (tester) async {
      await pump(tester, 'trailing [label]');
      expect(allRichText(tester), contains('label'));
    });
  });
}
