/// A reply that is still arriving is one live block of text; a reply that has
/// arrived is a document.
///
/// While chunks are landing, every block already on screen otherwise
/// re-publishes its semantics on every frame. For anyone listening that is an
/// announcement storm, and because an attached assistive service keeps the
/// semantics pipeline alive it was also about half the per-chunk cost of a
/// long reply.
///
/// The two halves of the guard matter equally:
///
///  - while text is arriving, the whole reply reads as one label, so nothing
///    is hidden even from a host that never turns `isStreaming` off;
///  - once it goes quiet, the structure comes back — a link is a link again.
///
/// The gate is observed growth, never the `isStreaming` flag: that flag
/// defaults to `true`, so keying off it would silently flatten the semantics
/// of every document that never sets it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _reply =
    'See [the docs](https://example.com) for more.\n\n'
    'A second paragraph with **bold** text in it.';

Future<void> _pump(
  WidgetTester tester,
  String text, {
  bool accessibleNavigation = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(accessibleNavigation: accessibleNavigation),
        child: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(text, onLinkTap: (_, _) {}),
          ),
        ),
      ),
    ),
  );
}

/// Whether any node below [finder] reports itself as a link.
bool _hasLinkNode(WidgetTester tester, Finder finder) {
  var found = false;
  void walk(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isLink) {
      found = true;
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(finder));
  return found;
}

void main() {
  testWidgets('a settled reply exposes its structure', (tester) async {
    await _pump(tester, _reply);
    await tester.pumpAndSettle();

    expect(
      _hasLinkNode(tester, find.byType(GptMarkdown)),
      isTrue,
      reason: 'a reply that is not arriving should be navigable as a document',
    );
  });

  testWidgets('a reply mid-arrival reads as one block, then recovers', (
    tester,
  ) async {
    await _pump(tester, _reply.substring(0, 20));
    await tester.pump();
    // An append: the streaming signature the gate actually watches for.
    await _pump(tester, _reply);
    await tester.pump();

    expect(
      _hasLinkNode(tester, find.byType(GptMarkdown)),
      isFalse,
      reason:
          'while chunks are landing the reply is one live label, not a tree '
          'of nodes republishing themselves every frame',
    );

    // Explicit time, not `pumpAndSettle`: going quiet is a timer, and a
    // pending timer schedules no frame, so settling alone never reaches it.
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      _hasLinkNode(tester, find.byType(GptMarkdown)),
      isTrue,
      reason: 'the structure must come back once the text goes quiet',
    );
  });

  testWidgets('nothing is hidden while the reply is arriving', (tester) async {
    await _pump(tester, _reply.substring(0, 20), accessibleNavigation: true);
    await tester.pump();
    await _pump(tester, _reply, accessibleNavigation: true);
    await tester.pump();

    final labels = <String>[];
    void walk(SemanticsNode node) {
      labels.add(node.getSemanticsData().label);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(GptMarkdown)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      labels.any((l) => l.contains('the docs') && l.contains('second')),
      isTrue,
      reason:
          'the whole reply so far must still be readable as the container '
          'label — a host that leaves isStreaming on forever must not lose it',
    );
  });
}
