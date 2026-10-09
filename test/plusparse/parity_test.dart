import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// The two parsers must agree.
///
/// `incremental: false` runs the regex pipeline; `incremental: true` runs
/// plusparse. Everything a reader can see should be the same either way — the
/// second parser is a performance choice, not a different product.
///
/// These are the 1.2.x features specifically, because plusparse was written
/// against the 1.1.x surface and every one of them was missing from it.
List<String> _paragraphs(WidgetTester tester) => [
  for (final widget in tester.widgetList(
    find.byWidgetPredicate((w) => w is RichText),
  ))
    (widget as RichText).text.toPlainText(includePlaceholders: false),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
  // A deliberately narrow test surface overflows; not what is under test.
  while (tester.takeException() != null) {}
}

/// Builds the same document on both paths and returns the two texts.
Future<({List<String> legacy, List<String> plusparse})> _both(
  WidgetTester tester,
  Widget Function({required bool incremental}) build,
) async {
  await _pump(tester, build(incremental: false));
  final legacy = _paragraphs(tester);
  await _pump(tester, build(incremental: true));
  return (legacy: legacy, plusparse: _paragraphs(tester));
}

void main() {
  setUp(() {
    // Wide enough that nothing rewraps differently between the two.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('parser parity', () {
    testWidgets('autolinks a bare URL', (tester) async {
      final r = await _both(
        tester,
        ({required incremental}) => GptMarkdown(
          'go to https://example.com now',
          incremental: incremental,
        ),
      );
      expect(r.plusparse, r.legacy);
      expect(r.legacy.join(), contains('https://example.com'));
    });

    testWidgets('autolinks a bare email', (tester) async {
      final r = await _both(
        tester,
        ({required incremental}) =>
            GptMarkdown('mail me at a@b.com ok', incremental: incremental),
      );
      expect(r.plusparse, r.legacy);
    });

    testWidgets('autolink can be turned off', (tester) async {
      final r = await _both(
        tester,
        ({required incremental}) => GptMarkdown(
          'go to https://example.com now',
          autolink: false,
          incremental: incremental,
        ),
      );
      expect(r.plusparse, r.legacy);
    });

    testWidgets('an image in a link label stays readable', (tester) async {
      // The #6124 case: a placeholder nested in the link's own placeholder
      // does not paint on iOS, so the image renders as its source text.
      final r = await _both(
        tester,
        ({required incremental}) => GptMarkdown(
          '[![a](https://x/i.png)](https://x)',
          incremental: incremental,
        ),
      );
      expect(r.plusparse, r.legacy);
      expect(r.legacy.join(), contains('![a](https://x/i.png)'));
    });

    testWidgets('a URL containing balanced parentheses stays whole', (
      tester,
    ) async {
      const url = 'https://en.wikipedia.org/wiki/Dart_(programming_language)';
      final r = await _both(
        tester,
        ({required incremental}) =>
            GptMarkdown('[Dart]($url)', incremental: incremental),
      );
      expect(r.plusparse, r.legacy);
      expect(r.legacy.join(), contains('Dart'));
    });

    testWidgets('renders an inline pattern', (tester) async {
      Widget build({required bool incremental}) => GptMarkdown(
        'hi #general there',
        incremental: incremental,
        inlinePatterns: [
          InlinePattern.prefixed(
            prefix: '#',
            knownNames: const ['general'],
            builder: (context, match, style) =>
                const WidgetSpan(child: Text('CHIP')),
          ),
        ],
      );

      await _pump(tester, build(incremental: false));
      expect(find.text('CHIP'), findsOneWidget);
      await _pump(tester, build(incremental: true));
      expect(find.text('CHIP'), findsOneWidget);
    });

    testWidgets('leaves an unknown token alone', (tester) async {
      Widget build({required bool incremental}) => GptMarkdown(
        'issue #2959 here',
        incremental: incremental,
        inlinePatterns: [
          InlinePattern.prefixed(
            prefix: '#',
            knownNames: const ['general'],
            builder: (context, match, style) =>
                const WidgetSpan(child: Text('CHIP')),
          ),
        ],
      );

      await _pump(tester, build(incremental: false));
      expect(find.text('CHIP'), findsNothing);
      await _pump(tester, build(incremental: true));
      expect(find.text('CHIP'), findsNothing);
    });

    testWidgets('a style sheet reaches the block quote bar', (tester) async {
      Widget build({required bool incremental}) => GptMarkdown(
        '> quoted',
        incremental: incremental,
        styleSheet: const GptMarkdownStyleSheet(
          blockQuote: BlockQuoteStyle(barWidth: 9),
        ),
      );

      for (final incremental in [false, true]) {
        await _pump(tester, build(incremental: incremental));
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString().contains('BlockQuote'),
          ),
          findsWidgets,
          reason: 'incremental: $incremental',
        );
      }
    });

    testWidgets('structural builders are called on both paths', (tester) async {
      for (final incremental in [false, true]) {
        var heading = false;
        var checkbox = false;
        var hr = false;
        await _pump(
          tester,
          GptMarkdown(
            '# Title\n\n[ ] task\n\n---',
            incremental: incremental,
            headingBuilder: (context, level, child, style) {
              heading = true;
              return child;
            },
            checkboxBuilder: (context, checked, child, style) {
              checkbox = true;
              return child;
            },
            hrBuilder: (context, style) {
              hr = true;
              return const SizedBox.shrink();
            },
          ),
        );
        expect(heading, isTrue, reason: 'headingBuilder, $incremental');
        expect(checkbox, isTrue, reason: 'checkboxBuilder, $incremental');
        expect(hr, isTrue, reason: 'hrBuilder, $incremental');
      }
    });

    testWidgets('inline code is the chip, not the old background paint', (
      tester,
    ) async {
      for (final incremental in [false, true]) {
        await _pump(
          tester,
          GptMarkdown('run `flutter test`', incremental: incremental),
        );
        // The chip is a tagged TextSpan rather than a placeholder, which is
        // what lets it wrap and stay selectable.
        final spans = tester
            .widgetList(find.byWidgetPredicate((w) => w is RichText))
            .expand((w) {
              final out = <InlineSpan>[];
              (w as RichText).text.visitChildren((s) {
                out.add(s);
                return true;
              });
              return out;
            });
        expect(
          spans.whereType<CodeTextSpan>(),
          isNotEmpty,
          reason: 'incremental: $incremental',
        );
      }
    });

    testWidgets('text scales with the system font size on both paths', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(3000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<double> height({
        required double scale,
        required bool incremental,
      }) async {
        await _pump(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SizedBox(
              width: 2800,
              child: GptMarkdown('# Heading one', incremental: incremental),
            ),
          ),
        );
        return tester.getSize(find.byType(GptMarkdown)).height;
      }

      for (final incremental in [false, true]) {
        final one = await height(scale: 1, incremental: incremental);
        final two = await height(scale: 2, incremental: incremental);
        // Exactly 2x where nothing rewraps. A placeholder that scales its own
        // text as well as having its box scaled comes out far higher.
        expect(
          two / one,
          closeTo(2.0, 0.1),
          reason: 'incremental: $incremental',
        );
      }
    });
  });

  group('app-specific inline syntax', () {
    /// The three tokens chat apps layer on Markdown. None is built in — the
    /// app supplies the pattern and the builder — so what is under test is
    /// that both parsers dispatch them identically, including where they sit
    /// next to other inline syntax.
    List<InlinePattern> patterns() => [
      InlinePattern.prefixed(
        prefix: '#',
        knownNames: const ['general', 'design-review'],
        builder: (context, match, style) =>
            WidgetSpan(child: Text('CH:${match.group(0)}')),
      ),
      InlinePattern.prefixed(
        prefix: '@',
        knownNames: const ['ada', 'grace'],
        builder: (context, match, style) =>
            WidgetSpan(child: Text('MN:${match.group(0)}')),
      ),
      InlinePattern.delimited(
        open: ':',
        knownNames: const ['tada', 'fire'],
        builder: (context, match, style) =>
            WidgetSpan(child: Text('EM:${match.namedGroup('name')}')),
      ),
    ];

    /// Every chip rendered, sorted so the comparison does not depend on
    /// widget-tree traversal order.
    List<String> chips(WidgetTester tester) =>
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where(
              (d) =>
                  d.startsWith('CH:') ||
                  d.startsWith('MN:') ||
                  d.startsWith('EM:'),
            )
            .toList()
          ..sort();

    const cases = <String, String>{
      'a channel': 'see #general now',
      'a mention': 'hi @ada there',
      'a shortcode': 'ship it :tada: yes',
      'two shortcodes in a row': ':fire::fire:',
      'beside bold': '**bold** @ada and #general',
      'inside bold': '**@ada**',
      'after inline code': '`code` :tada:',
      'in a list': '- @ada\n- #general',
      'in a heading': '# hi @ada',
      'in a table cell': '| a | b |\n|---|---|\n| @ada | :tada: |',
      'unknown tokens stay text': 'issue #2959 and @nobody and :shrug:',
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final rendered = <List<String>>[];
        for (final incremental in [false, true]) {
          await _pump(
            tester,
            GptMarkdown(
              entry.value,
              incremental: incremental,
              inlinePatterns: patterns(),
            ),
          );
          rendered.add(chips(tester));
        }
        expect(rendered[1], rendered[0]);
      });
    }

    testWidgets('unknown tokens render nothing at all', (tester) async {
      await _pump(
        tester,
        GptMarkdown(
          'issue #2959 and @nobody and :shrug:',
          inlinePatterns: patterns(),
        ),
      );
      expect(chips(tester), isEmpty);
    });
  });
}
