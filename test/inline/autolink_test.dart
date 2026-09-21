import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

late List<({String url, String title})> taps;

Future<void> pump(
  WidgetTester tester,
  String markdown, {
  bool autolink = true,
  Set<String> schemes = const <String>{},
}) async {
  taps = [];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(
            markdown,
            autolink: autolink,
            autolinkSchemes: schemes,
            onLinkTap: (url, title) => taps.add((url: url, title: title)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every rendered link, in document order.
///
/// A link is a `LinkTextSpan` now, not a `LinkButton` widget — that is what
/// lets its label wrap across lines and be selected with the text around it.
List<({RichText rich, LinkTextSpan span})> _links(WidgetTester tester) {
  final found = <({RichText rich, LinkTextSpan span})>[];
  for (final rich in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    void walk(InlineSpan span) {
      if (span is LinkTextSpan) {
        found.add((rich: rich, span: span));
      }
      span.visitDirectChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(rich.text);
  }
  return found;
}

/// Taps the [index]-th link and returns what the callback received.
Future<({String url, String title})> tapLink(
  WidgetTester tester, [
  int index = 0,
]) async {
  final links = _links(tester);
  expect(links.length, greaterThan(index), reason: 'no link at $index');
  final entry = links[index];
  final label = entry.span.toPlainText(includePlaceholders: false);
  final plain = entry.rich.text.toPlainText();
  final start = plain.indexOf(label);
  expect(start, isNot(-1), reason: 'label "$label" not in "$plain"');

  final finder = find.byWidgetPredicate((w) => identical(w, entry.rich));
  final renderObject = tester.renderObject<RenderParagraph>(finder);
  final boxes = renderObject.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + label.length),
  );
  expect(boxes, isNotEmpty, reason: 'no boxes for "$label"');
  final box = boxes.first;
  await tester.tapAt(
    tester.getTopLeft(finder) +
        Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
  );
  await tester.pumpAndSettle();
  return taps[index];
}

int linkCount(WidgetTester tester) => _links(tester).length;

/// All rendered text, link labels included.
///
/// Before links became spans this excluded them: a link was a placeholder, and
/// `includePlaceholders: false` dropped its whole label. The assertions using
/// it are about what lands *outside* a link, which still holds.
String plainText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    buffer.write(rt.text.toPlainText(includePlaceholders: false));
  }
  return buffer.toString();
}

void main() {
  group('bare URLs', () {
    testWidgets('a plain https URL is linked', (tester) async {
      await pump(tester, 'go to https://example.com now');
      expect(linkCount(tester), 1);
      final tap = await tapLink(tester);
      expect(tap.url, 'https://example.com');
      expect(tap.title, 'https://example.com');
    });

    testWidgets('a trailing period is left outside the link', (tester) async {
      await pump(tester, 'see https://example.com.');
      expect((await tapLink(tester)).url, 'https://example.com');
      expect(plainText(tester), contains('.'));
    });

    testWidgets('trailing punctuation is stripped in sequence', (tester) async {
      await pump(tester, 'really https://example.com?!');
      expect((await tapLink(tester)).url, 'https://example.com');
    });

    testWidgets('an unbalanced closing paren is left outside', (tester) async {
      await pump(tester, 'link (https://example.com) here');
      expect((await tapLink(tester)).url, 'https://example.com');
    });

    testWidgets('balanced parens stay inside the link', (tester) async {
      await pump(tester, 'see https://en.wikipedia.org/wiki/Foo_(bar) here');
      expect(
        (await tapLink(tester)).url,
        'https://en.wikipedia.org/wiki/Foo_(bar)',
      );
    });

    testWidgets('a trailing entity reference is left outside', (tester) async {
      await pump(tester, 'x https://example.com&amp; y');
      expect((await tapLink(tester)).url, 'https://example.com');
    });

    testWidgets('a www host is linked over http', (tester) async {
      await pump(tester, 'visit www.example.com today');
      final tap = await tapLink(tester);
      expect(tap.url, 'http://www.example.com');
      expect(tap.title, 'www.example.com');
    });

    testWidgets('a bare email becomes a mailto link', (tester) async {
      await pump(tester, 'write to ada@example.com please');
      final tap = await tapLink(tester);
      expect(tap.url, 'mailto:ada@example.com');
      expect(tap.title, 'ada@example.com');
    });

    testWidgets('underscores in a path survive', (tester) async {
      // ItalicMd would otherwise eat `_b_` out of the path.
      await pump(tester, 'see https://example.com/a_b_c here');
      expect((await tapLink(tester)).url, 'https://example.com/a_b_c');
    });

    testWidgets('an underscore in the last two segments is not a domain', (
      tester,
    ) async {
      await pump(tester, 'see www.foo_bar.com here');
      expect(linkCount(tester), 0);
      expect(plainText(tester), contains('www.foo_bar.com'));
    });

    testWidgets('a URL inside a word is not linked', (tester) async {
      await pump(tester, 'xhttps://example.com');
      expect(linkCount(tester), 0);
    });
  });

  group('schemes', () {
    testWidgets('an unknown bare scheme is not linked', (tester) async {
      await pump(tester, 'open myapp://thing now');
      expect(linkCount(tester), 0);
      expect(plainText(tester), contains('myapp://thing'));
    });

    testWidgets('an allowlisted bare scheme is linked', (tester) async {
      await pump(tester, 'open myapp://thing now', schemes: {'myapp'});
      expect((await tapLink(tester)).url, 'myapp://thing');
    });

    testWidgets('the allowlist is case-insensitive', (tester) async {
      await pump(tester, 'open MyApp://thing now', schemes: {'myapp'});
      expect(linkCount(tester), 1);
    });

    testWidgets('buzz:// is not linked by default', (tester) async {
      await pump(tester, 'open buzz://message?channel=x now');
      expect(linkCount(tester), 0);
    });
  });

  group('angle autolinks', () {
    testWidgets('<https://…> is linked without the brackets', (tester) async {
      await pump(tester, 'see <https://example.com> here');
      final tap = await tapLink(tester);
      expect(tap.url, 'https://example.com');
      expect(tap.title, 'https://example.com');
      expect(plainText(tester), isNot(contains('<https')));
    });

    testWidgets('<email> becomes a mailto link', (tester) async {
      await pump(tester, 'mail <ada@example.com> now');
      final tap = await tapLink(tester);
      expect(tap.url, 'mailto:ada@example.com');
      expect(tap.title, 'ada@example.com');
    });

    testWidgets('any scheme is accepted inside angle brackets', (tester) async {
      // CommonMark §6.5 — the brackets are an explicit instruction.
      await pump(tester, 'open <buzz://message?channel=x> now');
      expect((await tapLink(tester)).url, 'buzz://message?channel=x');
    });
  });

  group('interaction with other syntax', () {
    testWidgets('emphasis around a URL does not leak into the href', (
      tester,
    ) async {
      // block/buzz#4572: a pre-processor produced `[url](url**)` here.
      await pump(tester, '**https://example.com**');
      expect(linkCount(tester), 1);
      expect((await tapLink(tester)).url, 'https://example.com');
    });

    testWidgets('a URL in inline code stays code', (tester) async {
      await pump(tester, 'run `https://example.com` now');
      expect(linkCount(tester), 0);
      expect(plainText(tester), contains('https://example.com'));
    });

    testWidgets('an explicit markdown link is untouched', (tester) async {
      await pump(tester, 'see [docs](https://example.com) here');
      expect(linkCount(tester), 1);
      final tap = await tapLink(tester);
      expect(tap.url, 'https://example.com');
      expect(tap.title, 'docs');
    });

    testWidgets('a URL in a link label is not a nested link', (tester) async {
      await pump(tester, 'see [https://a.com](https://b.com) here');
      expect(linkCount(tester), 1);
      expect((await tapLink(tester)).url, 'https://b.com');
    });

    testWidgets('URLs work in headings, lists and tables', (tester) async {
      await pump(
        tester,
        '# https://a.com\n\n- https://b.com\n\n| x |\n|---|\n| https://c.com |',
      );
      expect(linkCount(tester), 3);
    });
  });

  group('opting out', () {
    testWidgets('autolink: false renders URLs as plain text', (tester) async {
      await pump(tester, 'go to https://example.com now', autolink: false);
      expect(linkCount(tester), 0);
      expect(plainText(tester), contains('https://example.com'));
    });

    testWidgets('autolink: false still renders explicit links', (tester) async {
      await pump(tester, 'see [docs](https://example.com)', autolink: false);
      expect(linkCount(tester), 1);
    });
  });
}
