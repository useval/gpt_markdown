/// `inlineLinkBuilder` — the span-returning replacement for `linkBuilder`.
///
/// These are the tests that catch the trap the whole API exists to avoid: a
/// `GestureRecognizer` on a span that has `children` and no `text` never
/// fires, so a naive span-returning link builder compiles, reads correctly,
/// renders correctly, and is silently dead. `onLinkTap` keeps compiling and
/// simply stops being called.
///
/// So every case here taps *through the widget tree* and asserts the callback
/// ran. Asserting that a span carries a recognizer would pass on a dead link.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `BidiRichText extends RichText`, and `find.byType` matches the exact type
/// only — it misses the subclass the tap layer actually renders.
Finder findRich() => find.byWidgetPredicate((w) => w is RichText);

Future<void> pumpMarkdown(
  WidgetTester tester,
  String data, {
  InlineLinkBuilder? inlineLinkBuilder,
  void Function(String url, String title)? onLinkTap,
  bool incremental = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: GptMarkdown(
            data,
            incremental: incremental,
            inlineLinkBuilder: inlineLinkBuilder,
            onLinkTap: onLinkTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The centre of the [index]th text box of the rendered paragraph.
Offset boxCentreOf(WidgetTester tester, String needle) {
  final rich = tester.widget<RichText>(findRich().first);
  final plain = rich.text.toPlainText();
  final start = plain.indexOf(needle);
  expect(start, isNot(-1), reason: 'no "$needle" in "$plain"');
  final renderObject = tester.renderObject<RenderParagraph>(findRich().first);
  final boxes = renderObject.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + needle.length),
  );
  expect(boxes, isNotEmpty, reason: 'no boxes for "$needle"');
  final box = boxes.first;
  final local = Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2);
  return tester.getTopLeft(findRich().first) + local;
}

void main() {
  group('defaultSpan is tappable', () {
    for (final incremental in <bool>[true, false]) {
      final pipeline = incremental ? 'plusparse' : 'regex';

      testWidgets('tapping a nested bold run fires onLinkTap ($pipeline)', (
        tester,
      ) async {
        // The bold run is a *child* of the link span. This is exactly the case
        // a container-level recognizer misses.
        final tapped = <String>[];
        await pumpMarkdown(
          tester,
          'go [**bold** link](https://example.com/a) now',
          incremental: incremental,
          inlineLinkBuilder: (link) => link.defaultSpan(),
          onLinkTap: (url, title) => tapped.add(url),
        );

        await tester.tapAt(boxCentreOf(tester, 'bold'));
        await tester.pump();

        expect(tapped, <String>['https://example.com/a']);
      });

      testWidgets('tapping plain text outside the link does not fire '
          '($pipeline)', (tester) async {
        final tapped = <String>[];
        await pumpMarkdown(
          tester,
          'go [link](https://example.com/a) now',
          incremental: incremental,
          inlineLinkBuilder: (link) => link.defaultSpan(),
          onLinkTap: (url, title) => tapped.add(url),
        );

        await tester.tapAt(boxCentreOf(tester, 'now'));
        await tester.pump();

        expect(tapped, isEmpty);
      });
    }
  });

  testWidgets('defaultSpan() reproduces the default rendering exactly', (
    tester,
  ) async {
    // The docs promise this, and MIGRATION tells people to reach for it as the
    // no-op migration of a linkBuilder. If it drifts from the default path the
    // advice silently restyles their links.
    String describe(WidgetTester t) {
      final buffer = StringBuffer();
      void walk(InlineSpan span) {
        if (span is LinkTextSpan) {
          buffer.write(
            'LINK[url=${span.url} style=${span.style} '
            'hover=${span.hoverStyle} linkStyle=${span.linkStyle}]',
          );
        } else if (span is TextSpan && span.text != null) {
          buffer.write('T[${span.text}|${span.style}]');
        }
        span.visitDirectChildren((child) {
          walk(child);
          return true;
        });
      }

      for (final rich in t.widgetList<RichText>(findRich())) {
        walk(rich.text);
      }
      return buffer.toString();
    }

    await pumpMarkdown(tester, 'see [**the** docs](https://example.com/docs)');
    final byDefault = describe(tester);

    await pumpMarkdown(
      tester,
      'see [**the** docs](https://example.com/docs)',
      inlineLinkBuilder: (link) => link.defaultSpan(),
    );
    final viaBuilder = describe(tester);

    expect(viaBuilder, byDefault);
    expect(byDefault, contains('LINK[url=https://example.com/docs'));
  });

  testWidgets('a restyled defaultSpan is still tappable', (tester) async {
    final tapped = <String>[];
    await pumpMarkdown(
      tester,
      'see [the docs](https://example.com/docs)',
      inlineLinkBuilder:
          (link) => link.defaultSpan(
            style: link.style.copyWith(color: const Color(0xFF00FF00)),
          ),
      onLinkTap: (url, title) => tapped.add(url),
    );

    await tester.tapAt(boxCentreOf(tester, 'the docs'));
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);
  });

  testWidgets('a hand-built TappableTextSpan is tappable', (tester) async {
    final tapped = <String>[];
    await pumpMarkdown(
      tester,
      'see [the docs](https://example.com/docs)',
      inlineLinkBuilder:
          (link) => TappableTextSpan(
            text: link.label.toUpperCase(),
            onTap: link.onTap,
            style: link.style,
          ),
      onLinkTap: (url, title) => tapped.add(url),
    );

    await tester.tapAt(boxCentreOf(tester, 'THE DOCS'));
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);
  });

  testWidgets('the link label reports itself as a link to semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpMarkdown(
      tester,
      'see [the docs](https://example.com/docs)',
      inlineLinkBuilder: (link) => link.defaultSpan(),
      onLinkTap: (url, title) {},
    );

    // Inline span semantics are nodes inside the paragraph, not widgets, so
    // `find.bySemanticsLabel` cannot see them — walk the tree instead.
    SemanticsData? labelNode;
    void walk(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.label == 'the docs') {
        labelNode = data;
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(findRich().first));

    expect(labelNode, isNotNull, reason: 'no semantics node for the label');
    // This is the half of the design that leaf arming buys. Range resolution
    // alone reports isLink=false and no tap action.
    expect(labelNode!.flagsCollection.isLink, isTrue);
    expect(labelNode!.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('hovering recolours the label and restores it on exit', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      'see [the docs](https://example.com/docs)',
      inlineLinkBuilder: (link) => link.defaultSpan(),
      onLinkTap: (url, title) {},
    );

    Color? labelColour() {
      Color? found;
      void visit(InlineSpan span) {
        if (found != null) return;
        if (span is TextSpan && span.text == 'the docs') {
          found = span.style?.color;
          return;
        }
        span.visitDirectChildren((child) {
          visit(child);
          return found == null;
        });
      }

      visit(tester.widget<RichText>(findRich().first).text);
      return found;
    }

    final before = labelColour();
    expect(before, isNotNull);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(boxCentreOf(tester, 'the docs'));
    await tester.pumpAndSettle();

    expect(labelColour(), isNot(before), reason: 'hover colour not applied');

    await mouse.moveTo(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(labelColour(), before, reason: 'hover colour not restored');
  });

  testWidgets('tapping still works inside a SelectionArea', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: SizedBox(
              width: 600,
              child: GptMarkdown(
                'see [the docs](https://example.com/docs)',
                inlineLinkBuilder: (link) => link.defaultSpan(),
                onLinkTap: (url, title) => tapped.add(url),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(boxCentreOf(tester, 'the docs'));
    await tester.pump();

    expect(tapped, <String>['https://example.com/docs']);
  });

  testWidgets('the label stays in the paragraph text, so it is selectable', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      'see [the docs](https://example.com/docs) now',
      inlineLinkBuilder: (link) => link.defaultSpan(),
    );

    // A WidgetSpan link is one U+FFFC placeholder here; a span link is real
    // text, which is what makes it selectable and wrappable.
    final plain = tester.widget<RichText>(findRich().first).text.toPlainText();
    expect(plain, contains('see the docs now'));
  });

  testWidgets('a builder returning an untappable span asserts in debug', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      'see [the docs](https://example.com/docs)',
      // A plain TextSpan carries no tap at all — the exact silent failure the
      // assert exists to turn into a loud one.
      inlineLinkBuilder: (link) => TextSpan(text: link.label),
      onLinkTap: (url, title) {},
    );

    final error = tester.takeException();
    expect(error, isAssertionError);
    expect('$error', contains('defaultSpan'));
  });
}
