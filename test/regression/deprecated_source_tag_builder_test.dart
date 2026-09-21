// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `sourceTagBuilder` is kept for one major so 1.2.x code still compiles and
/// still behaves the same — including the empty `TextStyle` it has always been
/// handed. Existing builders were written against that, so handing them the
/// resolved style now would silently restyle their chips.
///
/// `inlineSourceTagBuilder` is the one that gets the resolved style. That
/// asymmetry is deliberate and is pinned here.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    SourceTagBuilder? sourceTagBuilder,
    InlineSourceTagBuilder? inlineSourceTagBuilder,
    void Function(String id)? onSourceTagTap,
    TextStyle? style,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              'a claim [1] here',
              sourceTagBuilder: sourceTagBuilder,
              inlineSourceTagBuilder: inlineSourceTagBuilder,
              onSourceTagTap: onSourceTagTap,
              style: style,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the legacy builder still renders its widget', (tester) async {
    await pump(
      tester,
      sourceTagBuilder:
          (context, content, textStyle) =>
              Text('L$content', key: const Key('legacy')),
    );

    expect(find.byKey(const Key('legacy')), findsOneWidget);
    expect(find.text('L1'), findsOneWidget);
  });

  testWidgets('the legacy builder is still handed the empty TextStyle', (
    tester,
  ) async {
    TextStyle? handed;
    await pump(
      tester,
      sourceTagBuilder: (context, content, textStyle) {
        handed = textStyle;
        return const Text('legacy');
      },
    );

    expect(handed, const TextStyle());
  });

  testWidgets('the legacy builder is still wrapped so a tap reaches it', (
    tester,
  ) async {
    final tapped = <String>[];
    await pump(
      tester,
      sourceTagBuilder:
          (context, content, textStyle) =>
              Text('L$content', key: const Key('legacy')),
      onSourceTagTap: tapped.add,
    );

    await tester.tap(find.byKey(const Key('legacy')));
    await tester.pump();

    expect(tapped, <String>['1']);
  });

  testWidgets('inlineSourceTagBuilder wins when both are given', (
    tester,
  ) async {
    await pump(
      tester,
      sourceTagBuilder:
          (context, content, textStyle) =>
              Text('L$content', key: const Key('legacy')),
      inlineSourceTagBuilder: (tag) => tag.defaultSpan(),
    );

    expect(find.byKey(const Key('legacy')), findsNothing);
  });

  testWidgets('inlineSourceTagBuilder receives the resolved style and id', (
    tester,
  ) async {
    late SourceTagBuildDetails seen;
    const surrounding = TextStyle(fontSize: 31);
    await pump(
      tester,
      style: surrounding,
      inlineSourceTagBuilder: (tag) {
        seen = tag;
        return tag.defaultSpan();
      },
    );

    expect(seen.id, '1');
    // The legacy hook is handed `const TextStyle()` no matter what; this one
    // is handed the style actually in force.
    expect(seen.style.fontSize, 31);
    expect(seen.sourceTagStyle.size, isNotNull);
  });
}
