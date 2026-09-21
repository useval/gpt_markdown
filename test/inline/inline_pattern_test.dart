import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Renders [markdown] with [patterns] applied.
Future<void> pumpWithPatterns(
  WidgetTester tester,
  String markdown,
  List<InlinePattern> patterns,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(markdown, inlinePatterns: patterns),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A pattern whose chip is trivially findable in the widget tree.
InlinePattern chipPattern(RegExp pattern, {Set<MarkdownScope>? scopes}) {
  return InlinePattern(
    pattern: pattern,
    scopes: scopes ?? MarkdownComponent.allScopesExceptLinkLabel,
    builder:
        (context, match, style) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Text('CHIP:${match.group(0)}'),
        ),
  );
}

/// Concatenates the text of every [RichText] on screen.
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
  group('InlinePattern', () {
    testWidgets('renders in ordinary content', (tester) async {
      await pumpWithPatterns(tester, 'Go to #general now', [
        chipPattern(RegExp(r'#[a-z]+')),
      ]);
      expect(find.text('CHIP:#general'), findsOneWidget);
    });

    // The precedence guarantee holds on both pipelines. The regex pipeline
    // gets it by dispatching patterns and components through one combined
    // match; the incremental pipeline cannot, because by the time it has a
    // tree `**bold**` is already emphasis — so a match is lifted out before
    // parsing and put back at render.
    for (final incremental in [false, true]) {
      final pipeline = incremental ? 'incremental' : 'regex';
      testWidgets('$pipeline: a pattern beats the built-in reading', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GptMarkdown(
                'a **bold** b',
                incremental: incremental,
                inlinePatterns: [chipPattern(RegExp(r'\*\*bold\*\*'))],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}
        expect(find.text('CHIP:**bold**'), findsOneWidget);
      });

      testWidgets('$pipeline: a pattern does not reach inside a fence', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GptMarkdown(
                '```\n#general\n```',
                incremental: incremental,
                inlinePatterns: [chipPattern(RegExp(r'#general'))],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}
        expect(find.text('CHIP:#general'), findsNothing);
      });
    }

    testWidgets('wins over the built-in components', (tester) async {
      // `**bold**` would normally be claimed by BoldMd.
      await pumpWithPatterns(tester, 'a **bold** b', [
        chipPattern(RegExp(r'\*\*bold\*\*')),
      ]);
      expect(find.text('CHIP:**bold**'), findsOneWidget);
    });

    testWidgets('does not render inside a link label by default', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'See [#2959](https://x.com/i/2959).', [
        chipPattern(RegExp(r'#[0-9a-z]+')),
      ]);
      expect(find.text('CHIP:#2959'), findsNothing);
      expect(allRichText(tester), contains('#2959'));
    });

    testWidgets('renders inside a link label when opted in', (tester) async {
      await pumpWithPatterns(tester, 'See [#2959](https://x.com/i/2959).', [
        chipPattern(RegExp(r'#[0-9a-z]+'), scopes: MarkdownComponent.allScopes),
      ]);
      expect(find.text('CHIP:#2959'), findsOneWidget);
    });

    testWidgets('renders inside a heading', (tester) async {
      await pumpWithPatterns(tester, '# Welcome to #general', [
        chipPattern(RegExp(r'#general')),
      ]);
      expect(find.text('CHIP:#general'), findsOneWidget);
    });

    testWidgets('renders inside a table cell', (tester) async {
      await pumpWithPatterns(
        tester,
        '| Channel | Note |\n|---|---|\n| #general | main |',
        [chipPattern(RegExp(r'#general'))],
      );
      expect(find.text('CHIP:#general'), findsOneWidget);
    });

    testWidgets('a TextSpan builder stays inside the paragraph', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'ping @ada please', [
        InlinePattern(
          pattern: RegExp(r'@[a-z]+'),
          builder:
              (context, match, style) => TextSpan(
                text: match.group(0),
                style: style.copyWith(fontWeight: FontWeight.bold),
              ),
        ),
      ]);
      // One paragraph, no placeholder — text and mention in the same RichText.
      final rt = tester.widget<RichText>(
        find.byWidgetPredicate((w) => w is RichText).first,
      );
      expect(rt.text.toPlainText(), 'ping @ada please');
    });
  });

  group('InlinePattern.prefixed', () {
    testWidgets('matches known names', (tester) async {
      await pumpWithPatterns(tester, 'see #general', [
        InlinePattern.prefixed(
          prefix: '#',
          knownNames: const ['general', 'random'],
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.text('CHIP:#general'), findsOneWidget);
    });

    testWidgets('matches known names case-insensitively', (tester) async {
      await pumpWithPatterns(tester, 'see #General', [
        InlinePattern.prefixed(
          prefix: '#',
          knownNames: const ['general'],
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.text('CHIP:#General'), findsOneWidget);
    });

    testWidgets('leaves unknown tokens alone without a generic fallback', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'fixes #2959 today', [
        InlinePattern.prefixed(
          prefix: '#',
          knownNames: const ['general'],
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.text('CHIP:#2959'), findsNothing);
      expect(allRichText(tester), contains('#2959'));
    });

    testWidgets('claims unknown tokens when a generic fallback is given', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'fixes #2959 today', [
        InlinePattern.prefixed(
          prefix: '#',
          knownNames: const ['general'],
          genericTokenPattern: r'[A-Za-z0-9_][A-Za-z0-9_-]*',
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.text('CHIP:#2959'), findsOneWidget);
    });

    testWidgets('does not claim an @ inside an email address', (tester) async {
      await pumpWithPatterns(tester, 'mail ada@example.com now', [
        InlinePattern.prefixed(
          prefix: '@',
          genericTokenPattern: r'[A-Za-z0-9_]+',
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.textContaining('CHIP:'), findsNothing);
    });

    testWidgets('prefers the longest known name', (tester) async {
      await pumpWithPatterns(tester, 'see #design-review here', [
        InlinePattern.prefixed(
          prefix: '#',
          knownNames: const ['design', 'design-review'],
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.text('CHIP:#design-review'), findsOneWidget);
    });

    testWidgets('never matches when there is nothing to match', (tester) async {
      await pumpWithPatterns(tester, 'plain #text stays plain', [
        InlinePattern.prefixed(
          prefix: '#',
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('CHIP:${match.group(0)}')),
        ),
      ]);
      expect(find.textContaining('CHIP:'), findsNothing);
      expect(allRichText(tester), contains('#text'));
    });
  });

  group('InlinePattern.delimited', () {
    /// A chip built from the `name` group, so the test proves the group
    /// contract as well as the match.
    InlinePattern namedChip({
      required String open,
      String? close,
      Iterable<String> knownNames = const [],
      String? genericTokenPattern,
    }) {
      return InlinePattern.delimited(
        open: open,
        close: close,
        knownNames: knownNames,
        genericTokenPattern: genericTokenPattern,
        builder: (context, match, style) {
          final name = match.namedGroup('name');
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Text('CHIP:${name ?? '?'}'),
          );
        },
      );
    }

    testWidgets('consumes both delimiters', (tester) async {
      await pumpWithPatterns(tester, 'ship it :tada: now', [
        namedChip(open: ':', knownNames: const ['tada']),
      ]);
      expect(find.text('CHIP:tada'), findsOneWidget);
      // The closing colon is consumed, not left behind as text.
      // The chip's own label is a RichText too, so look for the trailing
      // colon specifically: `CHIP:tada` has none, an unconsumed `:tada:` does.
      expect(allRichText(tester), isNot(contains('tada:')));
      expect(allRichText(tester), contains('ship it'));
    });

    testWidgets('exposes the name as group 1 as well', (tester) async {
      await pumpWithPatterns(tester, 'a :fire: b', [
        InlinePattern.delimited(
          open: ':',
          knownNames: const ['fire'],
          builder:
              (context, match, style) =>
                  WidgetSpan(child: Text('G1:${match.group(1)}')),
        ),
      ]);
      expect(find.text('G1:fire'), findsOneWidget);
    });

    testWidgets('close defaults to open', (tester) async {
      await pumpWithPatterns(tester, 'x |redacted| y', [
        namedChip(open: '|', knownNames: const ['redacted']),
      ]);
      expect(find.text('CHIP:redacted'), findsOneWidget);
    });

    testWidgets('supports a distinct closing delimiter', (tester) async {
      await pumpWithPatterns(tester, 'a {{tada}} b', [
        namedChip(open: '{{', close: '}}', knownNames: const ['tada']),
      ]);
      expect(find.text('CHIP:tada'), findsOneWidget);
    });

    testWidgets('supports a multi-character delimiter', (tester) async {
      await pumpWithPatterns(tester, 'a ::spoiler:: b', [
        namedChip(open: '::', knownNames: const ['spoiler']),
      ]);
      expect(find.text('CHIP:spoiler'), findsOneWidget);
    });

    testWidgets('leaves unknown names alone without a generic fallback', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'a :nope: b', [
        namedChip(open: ':', knownNames: const ['tada']),
      ]);
      expect(find.textContaining('CHIP:'), findsNothing);
      expect(allRichText(tester), contains(':nope:'));
    });

    testWidgets('claims unknown names when a generic fallback is given', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'a :nope: b', [
        namedChip(
          open: ':',
          knownNames: const ['tada'],
          genericTokenPattern: r'[a-z0-9_+-]+',
        ),
      ]);
      expect(find.text('CHIP:nope'), findsOneWidget);
    });

    testWidgets('does not claim the colons in a clock time', (tester) async {
      await pumpWithPatterns(tester, 'at 10:30:45 today', [
        namedChip(open: ':', genericTokenPattern: r'[a-z0-9_+-]+'),
      ]);
      expect(find.textContaining('CHIP:'), findsNothing);
      expect(allRichText(tester), contains('10:30:45'));
    });

    testWidgets('does not claim the colon in a URL port', (tester) async {
      await pumpWithPatterns(tester, 'see http://host:8080/x here', [
        namedChip(open: ':', genericTokenPattern: r'[a-z0-9_+-]+'),
      ]);
      expect(find.textContaining('CHIP:'), findsNothing);
    });

    testWidgets('does not claim a token glued to a following word', (
      tester,
    ) async {
      await pumpWithPatterns(tester, 'a :tada:xyz b', [
        namedChip(open: ':', knownNames: const ['tada']),
      ]);
      expect(find.textContaining('CHIP:'), findsNothing);
    });

    testWidgets('matches two tokens in a row', (tester) async {
      await pumpWithPatterns(tester, ':fire::fire:', [
        namedChip(open: ':', knownNames: const ['fire']),
      ]);
      expect(find.text('CHIP:fire'), findsNWidgets(2));
    });

    testWidgets('matches known names case-insensitively', (tester) async {
      await pumpWithPatterns(tester, 'a :TADA: b', [
        namedChip(open: ':', knownNames: const ['tada']),
      ]);
      expect(find.text('CHIP:TADA'), findsOneWidget);
    });

    testWidgets('prefers the longest known name', (tester) async {
      await pumpWithPatterns(tester, 'a :party-tada: b', [
        namedChip(open: ':', knownNames: const ['tada', 'party-tada']),
      ]);
      expect(find.text('CHIP:party-tada'), findsOneWidget);
    });

    testWidgets('never matches when there is nothing to match', (tester) async {
      await pumpWithPatterns(tester, 'a :tada: b', [namedChip(open: ':')]);
      expect(find.textContaining('CHIP:'), findsNothing);
      expect(allRichText(tester), contains(':tada:'));
    });
  });
}
