import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// The native autolink scanner must find exactly what the regex found.
///
/// plusparse used to hand every plain text run to
/// `MarkdownComponent.generate` with `AutolinkMd` as the only component, which
/// ran a combined `RegExp` over the whole run to prove there was no link in it.
/// `autolinkSpans` replaces the *candidate detection* half of that with a
/// character scan; the resolution half ([AutolinkMd] `_parseAngle` /
/// `_parseBare`) is the same code on both paths.
///
/// So this file is a differential test, not a behaviour test: for every input
/// it builds the spans both ways and asserts they say the same thing. It does
/// not encode what a link *should* be — `test/inline/autolink_test.dart` does
/// that — which is the point. If the regex is wrong, the scanner has to be
/// wrong in the same way.
///
/// Spans are compared structurally, never by `toString`. The two paths are
/// allowed to disagree about how the *plain* text is split across `TextSpan`s
/// (the old path wraps each link in a `TextSpan` with the trailing
/// punctuation as a sibling; the new one flattens and merges), because that is
/// invisible to a reader, to selection and to tap ranges. Everything else —
/// the concatenated text, the number of links, each link's `url`, each link's
/// label, and therefore where the trailing punctuation ended up — must match.

/// What a span tree says, with the tree shape thrown away.
typedef _Summary = ({String text, List<({String url, String label})> links});

_Summary _summarize(List<InlineSpan> spans) {
  final buffer = StringBuffer();
  final links = <({String url, String label})>[];

  void walk(InlineSpan span) {
    if (span is LinkTextSpan) {
      final label = span.toPlainText(includePlaceholders: false);
      links.add((url: span.url, label: label));
      buffer.write(label);
      return;
    }
    if (span is TextSpan) {
      final text = span.text;
      if (text != null) {
        buffer.write(text);
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child);
      }
      return;
    }
    buffer.write(span.toPlainText(includePlaceholders: false));
  }

  for (final span in spans) {
    walk(span);
  }
  return (text: buffer.toString(), links: links);
}

/// The path plusparse used before the scanner existed, reproduced verbatim
/// from `PlusparseRenderer._plainTextSpans`.
List<InlineSpan> _regexPath(
  BuildContext context,
  String text,
  GptMarkdownConfig config,
) {
  if (!config.autolink) {
    return [TextSpan(text: text, style: config.style)];
  }
  return MarkdownComponent.generate(
    context,
    text,
    config.copyWith(inlineComponents: [AutolinkMd()]),
    false,
  );
}

void _expectSame(
  BuildContext context,
  String input,
  GptMarkdownConfig config,
  String label,
) {
  final old = _summarize(_regexPath(context, input, config));
  final now = _summarize(autolinkSpans(context, input, config));

  expect(
    now.text,
    old.text,
    reason: 'plain text differs for ${_show(input)} [$label]',
  );
  expect(
    now.links.length,
    old.links.length,
    reason:
        'link count differs for ${_show(input)} [$label]: '
        'regex ${old.links.map((l) => l.label).toList()} '
        'vs scanner ${now.links.map((l) => l.label).toList()}',
  );
  for (var i = 0; i < old.links.length; i++) {
    expect(
      now.links[i].url,
      old.links[i].url,
      reason: 'url $i differs for ${_show(input)} [$label]',
    );
    expect(
      now.links[i].label,
      old.links[i].label,
      reason: 'label $i differs for ${_show(input)} [$label]',
    );
  }
  // Outside the angle forms — which deliberately drop their `<`/`>` — the
  // text a reader sees must survive both paths untouched, links included.
  // Without this the two paths could agree on having eaten the same
  // characters and the test would still be green.
  if (!input.contains('<')) {
    expect(
      now.text,
      input,
      reason: 'the scanner dropped text for ${_show(input)} [$label]',
    );
  }
}

String _show(String input) =>
    '"${input.replaceAll('\n', r'\n').replaceAll('\r', r'\r')}"';

/// Every input both paths are run over.
final List<String> _corpus = [
  // ── the six alternatives of AutolinkMd._pattern, one at a time ──
  // 1. <scheme:...>
  '<https://example.com>',
  '<http://example.com/a/b?c=d#e>',
  '<mailto:a@b.com>',
  '<myapp:settings>',
  '<myapp://settings/deep>',
  '<ab:c>',
  // A one-character scheme is below the `{1,31}` minimum.
  '<a:b>',
  // A 36-character scheme is above the `{1,31}` maximum.
  '<abcdefghijklmnopqrstuvwxyz0123456789:x>',
  '<HTTPS://EXAMPLE.COM>',
  // 2. <email@host>
  '<a@b.com>',
  '<first.last+tag@mail.example.co.uk>',
  "<o'brien!#\$%&*+/=?^_`{|}~-@example.com>",
  '<a@b>',
  '<a@>',
  '<@b.com>',
  '<a@b.com.>',
  '<a@-b.com>',
  '<a@b-.com>',
  '<a@b..com>',
  // A space ends `[^<>\x00-\x20]*` without a `>`, so form 1 fails and the
  // brackets are just text.
  '<ab:c d>',
  '< https://x.com >',
  '<ab:c\td>',
  '<>',
  '<a>',
  '<a@b@c.com>',
  // A 63-character label is the longest form 2 accepts. At 64 it falls back to
  // form 6, which has no length rule — so the brackets stay as text and the
  // link is the bare address inside them.
  '<a@${'b' * 63}.com>',
  '<a@${'b' * 64}.com>',
  // `_` is in neither scheme class, so nothing here is a link at all.
  '<a_b:x>',
  '<a_b://x.com>',
  'a_b://x.com',
  'x_y:z',
  '<_a:b>',
  // 3. scheme://rest
  'https://example.com',
  'http://example.com/path?q=1&r=2#frag',
  'HTTP://EXAMPLE.COM/A',
  'ftp://example.com/file.txt',
  'myapp://settings/deep',
  'foo://bar',
  'x+y.z-w://example.com',
  'https://',
  'http://x',
  'https://example.com/a_b_c',
  'https://example.com/a<b',
  // 4. mailto:/xmpp:
  'mailto:a@b.com',
  'xmpp:user@host.com',
  'MailTo:A@B.com',
  'XMPP:a@b.com',
  'mailto:',
  'mailto: a@b.com',
  'mailto:notanaddress',
  // 5. www.host/rest
  'www.example.com',
  'www.example.com/a/b?c=d',
  'WWW.EXAMPLE.COM',
  'Www.Example.Com/Path',
  'www.',
  'www.x',
  'www.ex_ample.com',
  'www.a_b.example.com',
  // 6. bare email
  'a@b.com',
  'first.last+tag@mail.example.co.uk',
  'a@b.c',
  'user@ex_ample.com',
  'user@a_b.example.com',
  'user@sub.domain.example.com',
  'user@b',
  'a@b.',
  '@b.com',
  'user@@example.com',
  // Form 5 is listed before form 6, and the two disagree about where the
  // match ends: `www.` runs to the whitespace, the email stops after the
  // last label.
  'www.x@y.com/path',
  'www.x@y.com!',
  'mailto://x.com',
  'a+www.x.com',
  'a+b@c.com',
  '+a@b.com',

  // ── trailing punctuation, singly and in runs ──
  'see https://x.com.',
  'see https://x.com?',
  'see https://x.com!',
  'see https://x.com,',
  'see https://x.com:',
  'see https://x.com*',
  'see https://x.com_',
  'see https://x.com~',
  'see https://x.com?!.,:*_~',
  'see https://x.com... and more',
  'a@b.com.',
  'www.x.com!!!',
  '<https://x.com>.',

  // ── parentheses, balanced, unbalanced and nested ──
  'https://en.wikipedia.org/wiki/Dart_(programming_language)',
  '(see https://x.com)',
  '(see https://x.com/a(b))',
  'https://x.com/a(b(c))d',
  'https://x.com/a)b',
  'https://x.com/a))',
  '(https://x.com/a(b)',
  '((https://x.com))',

  // ── trailing entity references ──
  'https://x.com/?a=1&amp;b=2',
  'https://x.com/&amp;',
  'https://x.com/&amp;&lt;',
  'https://x.com/&notanentity;',
  'https://x.com/a;',

  // ── left-boundary negatives ──
  'nothttps://x.com',
  '/path/https://x.com',
  'a@https://x.com',
  'foo.https://x.com',
  'x+https://x.com',
  '-https://x.com',
  '_https://x.com',
  'word-www.example.com',
  'word.www.example.com',
  'name@www.example.com',
  'abc/www.example.com',
  'see-www.x.com',
  '1.2.3.4mailto:a@b.com',
  'aaa@b.com',
  'x/a@b.com',

  // ── several links, adjacency, position in the run ──
  'https://x.com',
  'https://x.com at the start',
  'at the end https://x.com',
  'a https://x.com b www.y.com c a@b.com d',
  'https://x.com www.y.com',
  'https://x.com,https://y.com',
  '<a@b.com><c@d.com>',
  '<https://x.com><https://y.com>',
  'https://x.com<https://y.com',
  'mail a@b.com or c@d.com',

  // ── nothing to find ──
  '',
  ' ',
  '   ',
  '\n',
  '\t \n ',
  'plain prose with no links at all',
  'a colon: here, an at @ sign, and an angle < bracket',
  'meet at 10:30 for the 3.5 release',
  'ratio 1:2:3 and a;b;c',
  'call me @ home',
  'C:\\Users\\sohag\\file.txt',
  '**bold** _italic_ `code`',

  // ── unicode on either side ──
  '日本語https://x.com日本語',
  '→ https://x.com ←',
  'café www.example.com fin',
  '🙂https://x.com🙂',
  'приветwww.x.com',
  'a\u00a0https://x.com\u00a0b',
  'a\u2003https://x.com\u2003b',

  // ── longer, realistic prose: the shape the scanner is meant to be fast on ──
  'The renderer walks the AST once and emits spans as it goes, which is why '
      'the incremental path can reuse the work it did on the previous frame: '
      'nothing in the tree depends on where the paragraph ends, so appending '
      'to the last block never invalidates the ones before it. That is the '
      'whole trick, and it only holds while parsing stays linear in the size '
      'of the text; anything that scans the run more than a constant number '
      'of times shows up immediately in a cold frame.',
  'Ping me at first.last@example.co.uk or open https://github.com/example/'
      'repo/issues/12 (the one about www.example.com timing out), and if that '
      'fails, mailto:support@example.com still works. Thanks!',
];

/// Inputs that are unambiguous Markdown, so the two *pipelines* can be
/// compared end to end without the comparison tripping over unrelated
/// differences in how they read `*`, `_`, `<` or a leading `-`.
bool _isInertMarkdown(String input) {
  if (input.trim().isEmpty) {
    return false;
  }
  for (final char in const [
    '*',
    '_',
    '`',
    '[',
    ']',
    '<',
    '>',
    r'\',
    '|',
    '#',
  ]) {
    if (input.contains(char)) {
      return false;
    }
  }
  final first = input.trimLeft();
  return !first.startsWith('-') && !first.startsWith('+');
}

List<String> _paragraphs(WidgetTester tester) => [
  for (final widget in tester.widgetList(
    find.byWidgetPredicate((w) => w is RichText),
  ))
    (widget as RichText).text.toPlainText(includePlaceholders: false),
];

List<({String url, String label})> _renderedLinks(WidgetTester tester) {
  final links = <({String url, String label})>[];
  for (final widget in tester.widgetList(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    void walk(InlineSpan span) {
      if (span is LinkTextSpan) {
        links.add((
          url: span.url,
          label: span.toPlainText(includePlaceholders: false),
        ));
      }
      span.visitDirectChildren((child) {
        walk(child);
        return true;
      });
    }

    walk((widget as RichText).text);
  }
  return links;
}

void main() {
  group('autolink candidate scanner parity', () {
    late BuildContext context;

    Future<void> grabContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('default config', (tester) async {
      await grabContext(tester);
      const config = GptMarkdownConfig();
      for (final input in _corpus) {
        _expectSame(context, input, config, 'default');
      }
    });

    testWidgets('extra autolink schemes', (tester) async {
      await grabContext(tester);
      const config = GptMarkdownConfig(
        autolinkSchemes: {'myapp', 'FTP', 'x+y.z-w'},
      );
      for (final input in _corpus) {
        _expectSame(context, input, config, 'schemes');
      }
    });

    testWidgets('autolink off', (tester) async {
      await grabContext(tester);
      const config = GptMarkdownConfig(autolink: false);
      for (final input in _corpus) {
        _expectSame(context, input, config, 'autolink off');
      }
    });

    testWidgets('inside a link label the scanner must stand down', (
      tester,
    ) async {
      await grabContext(tester);
      const config = GptMarkdownConfig(scope: MarkdownScope.linkLabel);
      for (final input in _corpus) {
        _expectSame(context, input, config, 'linkLabel scope');
        // Stronger than parity: nothing at all may be linked in a label.
        expect(
          _summarize(autolinkSpans(context, input, config)).links,
          isEmpty,
        );
      }
    });

    testWidgets('a table cell and a heading still autolink', (tester) async {
      await grabContext(tester);
      for (final scope in const [
        MarkdownScope.tableCell,
        MarkdownScope.heading,
      ]) {
        final config = GptMarkdownConfig(scope: scope);
        for (final input in _corpus) {
          _expectSame(context, input, config, 'scope $scope');
        }
      }
    });

    testWidgets('the scope the scanner hard-codes is the one AutolinkMd '
        'declares', (tester) async {
      await grabContext(tester);
      expect(AutolinkMd().scopes, MarkdownComponent.allScopesExceptLinkLabel);
    });

    testWidgets('a styled run keeps its style on both paths', (tester) async {
      await grabContext(tester);
      const config = GptMarkdownConfig(
        style: TextStyle(fontSize: 21, color: Color(0xFF123456)),
      );
      for (final input in _corpus) {
        _expectSame(context, input, config, 'styled');
      }
      final spans = autolinkSpans(context, 'see https://x.com. ok', config);
      final plain = spans.whereType<TextSpan>().where(
        (s) => s is! LinkTextSpan,
      );
      expect(plain, isNotEmpty);
      for (final span in plain) {
        expect(span.style, config.style);
      }
    });
  });

  group('autolink candidate scanner parity, fuzzed', () {
    // A fixed corpus only proves the cases someone thought of. The scanner
    // reproduces a six-way alternation with a lookbehind and greedy tails by
    // hand, and the cases that go wrong there are the ones where two forms
    // overlap and the regex backtracks out of the longer one. So: random
    // strings over an alphabet of nothing but the characters that matter,
    // which makes near-misses dense rather than astronomically unlikely.
    //
    // The seed is fixed, so a failure here is reproducible and is a real
    // difference, not a flake.
    const alphabet =
        r'abwWzZ019.:/@<>-_+~()!?,;&*| '
        '\t';

    testWidgets('random strings over the link alphabet', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      const config = GptMarkdownConfig(autolinkSchemes: {'myapp'});
      final random = Random(20260913);
      for (var round = 0; round < 4000; round++) {
        final length = 1 + random.nextInt(24);
        final buffer = StringBuffer();
        for (var i = 0; i < length; i++) {
          buffer.write(alphabet[random.nextInt(alphabet.length)]);
        }
        _expectSame(context, buffer.toString(), config, 'fuzz $round');
      }
    });

    testWidgets('random strings built out of link-shaped fragments', (
      tester,
    ) async {
      // The alphabet above rarely produces a whole valid link. This one
      // assembles fragments that almost always do, so resolution — trailing
      // punctuation, paren balancing, the domain rule — is exercised as hard
      // as detection.
      const fragments = [
        'https://',
        'http://',
        'mailto:',
        'xmpp:',
        'myapp://',
        'ftp://',
        'www.',
        'WWW.',
        'example',
        'a',
        'sub_domain',
        'a_b:',
        'a_b',
        '.com',
        '.co.uk',
        '.',
        '@',
        '<',
        '>',
        '/path',
        '?q=1',
        '&amp;',
        '#frag',
        '(x)',
        ')',
        '_',
        '-',
        '+',
        '!',
        '...',
        ' ',
        'see ',
        ' ',
        '日本',
      ];

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      const config = GptMarkdownConfig(autolinkSchemes: {'myapp'});
      final random = Random(1337);
      for (var round = 0; round < 4000; round++) {
        final parts = 1 + random.nextInt(6);
        final buffer = StringBuffer();
        for (var i = 0; i < parts; i++) {
          buffer.write(fragments[random.nextInt(fragments.length)]);
        }
        _expectSame(context, buffer.toString(), config, 'fragment fuzz $round');
      }
    });
  });

  group('autolink parity through the whole widget', () {
    testWidgets('both pipelines render the corpus identically', (tester) async {
      final inputs = _corpus.where(_isInertMarkdown).toList();
      expect(inputs, isNotEmpty);

      for (final input in inputs) {
        Widget build({required bool incremental}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2000,
              child: GptMarkdown(
                input,
                incremental: incremental,
                autolinkSchemes: const {'myapp'},
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(incremental: false));
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}
        final legacyText = _paragraphs(tester);
        final legacyLinks = _renderedLinks(tester);

        await tester.pumpWidget(build(incremental: true));
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}

        expect(
          _paragraphs(tester),
          legacyText,
          reason: 'rendered text differs for ${_show(input)}',
        );
        expect(
          _renderedLinks(tester).map((l) => '${l.url} :: ${l.label}').toList(),
          legacyLinks.map((l) => '${l.url} :: ${l.label}').toList(),
          reason: 'rendered links differ for ${_show(input)}',
        );
      }
    });

    testWidgets('a document with inline patterns still autolinks, and still '
        'claims a pattern the mask could not reach', (tester) async {
      // The scanner is not used when `inlinePatterns` are present: the
      // combined regex is what ranks a pattern against an autolink, and it is
      // also the only thing that can claim a pattern match the *mask* never
      // saw. Masking works on the source, and a run is not always a substring
      // of it — `RegExp(r'^b$')` matches the `b` that `a**b**c` parses to and
      // never matches `a**b**c` itself.
      //
      // Both halves are asserted here so that routing this path through the
      // scanner "for consistency" fails loudly instead of quietly dropping
      // one of them.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2000,
              child: GptMarkdown(
                'a**b**c and https://example.com',
                incremental: true,
                inlinePatterns: [
                  InlinePattern(
                    pattern: RegExp(r'^b$'),
                    builder:
                        (context, match, style) =>
                            const TextSpan(text: 'CLAIMED'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_paragraphs(tester).join(), contains('CLAIMED'));
      expect(_renderedLinks(tester).map((l) => l.url), ['https://example.com']);
    });
  });
}
