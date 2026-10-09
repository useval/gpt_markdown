/// The new CommonMark syntax, rendered through the real widget: what the
/// parser tests cannot see — `$` rewriting before the parse, the source tag
/// chip's tap, footnote rendering, and definitions reaching segments that the
/// incremental and sliver views parse one at a time.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../utils/test_helpers.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Every piece of text on screen, rich text and plain widgets alike.
String _visibleText(WidgetTester tester) {
  final out = StringBuffer();
  for (final widget in tester.widgetList(find.byType(RichText))) {
    out.write((widget as RichText).text.toPlainText());
    out.write('\n');
  }
  return out.toString();
}

void main() {
  group(r'$ maths', () {
    Future<String> render(WidgetTester tester, String markdown) async {
      await tester.pumpWidget(
        _app(GptMarkdown(markdown, useDollarSignsForLatex: true)),
      );
      await tester.pumpAndSettle();
      return getSerializedOutput(tester);
    }

    testWidgets('dollars in a fenced code block stay as written', (
      tester,
    ) async {
      final output = await render(
        tester,
        'Run:\n\n```bash\necho \$HOME \$PATH\nprice=\$\$5\$\$\n```',
      );
      expect(output, contains(r'echo $HOME $PATH'));
      expect(output, contains(r'price=$$5$$'));
      expect(output, isNot(contains('LATEX')));
    });

    testWidgets('dollars in a code span stay as written', (tester) async {
      final output = await render(tester, r'Use `$x$` and `$$y$$` here.');
      expect(output, isNot(contains('LATEX')));
      expect(output, contains(r'$x$'));
    });

    testWidgets('prices are prose', (tester) async {
      final output = await render(tester, r'It costs $5 and $10 today.');
      expect(output, isNot(contains('LATEX')));
      expect(output, contains(r'It costs $5 and $10 today.'));
    });

    testWidgets('a stray backtick does not hide later maths', (tester) async {
      final output = await render(
        tester,
        'Press the ` key.\n\nThen \$x^2\$ holds.\n\nRun `ls`.',
      );
      expect('LATEX'.allMatches(output).length, 1);
    });

    testWidgets(r'a $$ does not pair with one inside a fence', (tester) async {
      final output = await render(tester, 'A \$\$ b\n\n```\necho \$\$\n```');
      expect(output, isNot(contains('LATEX')));
      expect(output, contains(r'echo $$'));
    });

    testWidgets('a price before a formula stays a price', (tester) async {
      final output = await render(tester, r'It costs $5 and $x^2$ more.');
      expect('LATEX'.allMatches(output).length, 1);
      expect(output, contains(r'It costs $5 and '));
    });

    testWidgets(r'\( \) and $ $ formulas mix in one paragraph', (tester) async {
      final output = await render(
        tester,
        r'Inline \(x\) and dollars $a^2 + b^2$.',
      );
      expect('LATEX'.allMatches(output).length, 2);
    });

    testWidgets(r'prices stay text in a reply that also uses \( \)', (
      tester,
    ) async {
      final output = await render(
        tester,
        r'With \(x\), it costs $5 and $10, and $y$ is maths.',
      );
      expect('LATEX'.allMatches(output).length, 2);
      expect(output, contains(r'it costs $5 and $10, and '));
    });

    testWidgets('maths is still maths', (tester) async {
      final output = await render(tester, r'Area $x^2$ and $$y$$.');
      expect('LATEX'.allMatches(output).length, 2);
    });

    testWidgets(r'an escaped \$ shows a dollar', (tester) async {
      final output = await render(tester, r'Pay \$5 now.');
      expect(output, contains(r'Pay $5 now.'));
      expect(output, isNot(contains(r'\$')));
    });
  });

  group('rendering', () {
    testWidgets('underscore emphasis and escapes render', (tester) async {
      await pumpMarkdown(tester, r'_it_ __bold__ \*lit\* snake_case');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("it")[italic]'));
      expect(output, contains('TEXT("bold")[bold]'));
      expect(output, contains('*lit*'));
      expect(output, contains('snake_case'));
    });

    testWidgets('a setext heading goes through headingBuilder', (tester) async {
      final levels = <int>[];
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            'Title\n=====\n\nSub\n---',
            headingBuilder: (context, level, content, style) {
              levels.add(level);
              return content;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(levels, [1, 2]);
    });

    testWidgets('entities decode and comments disappear', (tester) async {
      await pumpMarkdown(
        tester,
        'a &amp; b <!-- secret -->\n\n<!--\nhidden\n-->',
      );
      final text = _visibleText(tester);
      expect(text, contains('a & b'));
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('hidden')));
      expect(text, isNot(contains('<!--')));
    });

    testWidgets('a ~~~ fence renders as code', (tester) async {
      await pumpMarkdown(tester, '~~~python\nx = 1\n~~~');
      expect(
        getSerializedOutput(tester),
        contains('CODE_BLOCK(lang="python", "x = 1")'),
      );
    });

    testWidgets('a link title is not part of the URL', (tester) async {
      await pumpMarkdown(tester, '[Docs](/docs "The docs")');
      expect(
        getSerializedOutput(tester),
        contains('LINK("Docs", url="/docs")'),
      );
    });

    testWidgets('a reference link resolves', (tester) async {
      await pumpMarkdown(
        tester,
        'Read [the docs][d].\n\n[d]: https://d.dev "D"',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('LINK("the docs", url="https://d.dev")'));
      expect(output, isNot(contains('[d]:')));
    });

    testWidgets('footnotes render as a numbered list', (tester) async {
      await pumpMarkdown(
        tester,
        'Claim[^a] and claim[^b].\n\n[^a]: First source.\n[^b]: Second source.',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('OL_ITEM(1,'));
      expect(output, contains('First source.'));
      expect(output, contains('OL_ITEM(2,'));
      expect(output, contains('Second source.'));
      expect(output, isNot(contains('[^a]')));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('source tags with a defined URL', () {
    const markdown = 'Fact [1].\n\n[1]: https://example.com/source';

    testWidgets('stay chips and open the URL through onLinkTap', (
      tester,
    ) async {
      final taps = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            markdown,
            onLinkTap: (url, title) => taps.add((url, title)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_visibleText(tester), isNot(contains('example.com')));
      await tester.tap(find.text('1'));
      expect(taps, [('https://example.com/source', '1')]);
    });

    testWidgets('onSourceTagTap still wins when set', (tester) async {
      final tags = <String>[];
      final links = <String>[];
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            markdown,
            onSourceTagTap: tags.add,
            onLinkTap: (url, title) => links.add(url),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      expect(tags, ['1']);
      expect(links, isEmpty);
    });

    testWidgets('a builder sees the URL', (tester) async {
      String? seen;
      await tester.pumpWidget(
        _app(
          GptMarkdown(
            markdown,
            inlineSourceTagBuilder: (details) {
              seen = details.url;
              return details.defaultSpan();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen, 'https://example.com/source');
    });
  });

  group('definitions across segments', () {
    testWidgets('a definition that arrives later links an earlier segment', (
      tester,
    ) async {
      const head = 'See [docs].\n\nMore text.';
      await tester.pumpWidget(_app(GptMarkdown(head)));
      await tester.pumpAndSettle();
      expect(getSerializedOutput(tester), isNot(contains('LINK')));

      await tester.pumpWidget(
        _app(GptMarkdown('$head\n\n[docs]: https://d.dev')),
      );
      await tester.pumpAndSettle();
      expect(
        getSerializedOutput(tester),
        contains('LINK("docs", url="https://d.dev")'),
      );
    });

    testWidgets('a definition whose URL changes updates the link', (
      tester,
    ) async {
      const head = 'See [docs].\n\nMore.\n\n[docs]: https://a.dev';
      await tester.pumpWidget(_app(GptMarkdown(head)));
      await tester.pumpAndSettle();
      expect(getSerializedOutput(tester), contains('url="https://a.dev"'));

      await tester.pumpWidget(_app(GptMarkdown('${head}x')));
      await tester.pumpAndSettle();
      expect(getSerializedOutput(tester), contains('url="https://a.devx"'));
    });

    testWidgets('a footnote reference resolves across segments', (
      tester,
    ) async {
      await pumpMarkdown(tester, 'Claim[^1].\n\nMiddle.\n\n[^1]: Source.');
      expect(_visibleText(tester), isNot(contains('[^1]')));
      expect(getSerializedOutput(tester), contains('OL_ITEM(1,'));
    });

    testWidgets('the sliver view resolves across segments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverGptMarkdown(
                  'See [docs] and[^n].\n\nMiddle.\n\n[docs]: https://d.dev\n\n[^n]: Note.',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final output = getSerializedOutput(tester);
      expect(output, contains('LINK("docs", url="https://d.dev")'));
      expect(output, isNot(contains('[^n]')));
      expect(output, isNot(contains('[docs]:')));
    });
  });

  group('hidden lines take no space', () {
    Future<double> height(WidgetTester tester, String markdown) async {
      await tester.pumpWidget(
        _app(Center(child: GptMarkdown(markdown, key: const Key('md')))),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(const Key('md'))).height;
    }

    testWidgets('a block of reference definitions leaves no gap', (
      tester,
    ) async {
      final plain = await height(tester, 'A [x] and [1].\n\nB');
      final withDefinitions = await height(
        tester,
        'A [x] and [1].\n\n[x]: https://x.dev\n\n\n[1]: https://one.dev\n\nB',
      );
      expect(withDefinitions, plain);
    });

    testWidgets('a comment on its own leaves no gap', (tester) async {
      final plain = await height(tester, 'A\n\nB');
      final withComment = await height(tester, 'A\n\n<!-- note -->\n\nB');
      expect(withComment, plain);
    });

    testWidgets('the sliver view drops them too', (tester) async {
      Future<double> sliverHeight(String markdown) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverGptMarkdown(markdown),
                  const SliverToBoxAdapter(
                    child: SizedBox(key: Key('end'), height: 1),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.byKey(const Key('end'))).dy;
      }

      final plain = await sliverHeight('A [x].\n\nB');
      final hidden = await sliverHeight(
        'A [x].\n\n[x]: https://x.dev\n\n<!-- c -->\n\nB',
      );
      expect(hidden, plain);
    });
  });
}
