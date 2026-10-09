import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Issue #114. `MarkdownComponent.generate` joins every component's pattern
/// into one combined regex and used to compile it without `unicode: true`, so
/// a consumer pattern using `\p{L}` meant a literal `p{L}` and matched nothing.
/// The built-in patterns cannot move to unicode mode wholesale: it rejects the
/// `\~` and `\!` escapes they use.

class _HashtagMd extends InlineMd {
  @override
  RegExp get exp =>
      RegExp(r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)', unicode: true);

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return TextSpan(text: 'TAG($text)', style: config.style);
  }
}

/// A non-unicode consumer pattern that overlaps the hashtag one, to pin the
/// list-order tie-break between the two flag modes.
class _ShoutMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'#[A-Z]+!');

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return TextSpan(text: 'SHOUT($text)', style: config.style);
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

Future<void> pump(
  WidgetTester tester,
  String markdown,
  List<MarkdownComponent> inlineComponents,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GptMarkdown(markdown, inlineComponents: inlineComponents),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a unicode component matches non-ASCII text', (tester) async {
    await pump(tester, '#你好，世界  |  #hello_world', [
      ...MarkdownComponent.inlineComponents,
      _HashtagMd(),
    ]);
    final text = plainText(tester);
    expect(text, contains('TAG(#你好)'));
    expect(text, contains('TAG(#hello_world)'));
  });

  testWidgets('built-in components still render beside it', (tester) async {
    await pump(tester, '**bold** ~~gone~~ #标签 `code`', [
      ...MarkdownComponent.inlineComponents,
      _HashtagMd(),
    ]);
    final text = plainText(tester);
    expect(text, contains('TAG(#标签)'));
    expect(text, contains('bold'));
    expect(text, contains('gone'));
    expect(text, isNot(contains('*')));
    expect(text, isNot(contains('~')));
  });

  testWidgets('its lookbehind still sees the text before the match', (
    tester,
  ) async {
    await pump(tester, 'a#no #yes', [
      ...MarkdownComponent.inlineComponents,
      _HashtagMd(),
    ]);
    final text = plainText(tester);
    expect(text, contains('TAG(#yes)'));
    expect(text, isNot(contains('TAG(#no)')));
  });

  testWidgets('list order decides between unicode and non-unicode', (
    tester,
  ) async {
    await pump(tester, 'x #HEY! y', [_ShoutMd(), _HashtagMd()]);
    expect(plainText(tester), contains('SHOUT(#HEY!)'));

    await pump(tester, 'x #HEY! y', [_HashtagMd(), _ShoutMd()]);
    expect(plainText(tester), contains('TAG(#HEY)'));
  });
}
